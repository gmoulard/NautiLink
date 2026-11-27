package main

import (
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Réglages du serveur posés dans l'espace administrateur (RG-ADM-08, D-174) :
// code d'accès à Météo-France, qui l'emporte sur la variable
// NAUTILINK_METEOFRANCE. Le code n'est jamais réaffiché, ni écrit dans le
// journal des actions.

const cleMeteoFrance = "meteofrance"

// chargerCodeMeteo : relit le code posé dans l'espace administrateur (un
// passage de la tâche de relevé, une fois par minute) ; vide : la variable.
func (a *app) chargerCodeMeteo(ctx context.Context) error {
	var v string
	err := a.b.pool.QueryRow(ctx, "SELECT valeur FROM reglages WHERE cle = $1", cleMeteoFrance).Scan(&v)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	a.meteo.poserReglage(v)
	return nil
}

// normaliserCodeMeteo : accepte la chaîne donnée par le portail (base64 de
// « identifiant:secret », avec ou sans « Basic » devant) ou
// « identifiant:secret » en clair, encodé ici.
func normaliserCodeMeteo(v string) (string, error) {
	v = strings.TrimSpace(v)
	if len(v) > 6 && strings.EqualFold(v[:6], "basic ") {
		v = strings.TrimSpace(v[6:])
	}
	invalide := errInvalide("Ce code n'a pas la forme attendue : collez la chaîne donnée par le portail de Météo-France pour l'en-tête « Authorization: Basic », ou « identifiant:secret ».")
	switch {
	case v == "":
		return "", errInvalide("Collez le code d'accès à Météo-France.")
	case len(v) > 1000 || strings.ContainsAny(v, " \t\r\n"):
		return "", invalide
	case strings.Contains(v, ":"):
		if i := strings.Index(v, ":"); i == 0 || i == len(v)-1 {
			return "", invalide
		}
		return base64.StdEncoding.EncodeToString([]byte(v)), nil
	}
	d, err := base64.StdEncoding.DecodeString(v)
	if i := strings.Index(string(d), ":"); err != nil || i <= 0 || i == len(d)-1 {
		return "", invalide
	}
	return v, nil
}

// verifierCodeMeteo : demande un jeton à Météo-France avec ce code.
func (a *app) verifierCodeMeteo(ctx context.Context, code string) error {
	ctx, fin := context.WithTimeout(ctx, 20*time.Second)
	defer fin()
	_, _, err := a.meteo.demanderJeton(ctx, code)
	return err
}

type donneesAdminReglages struct {
	Ecran    bool // code posé sur cet écran
	Le       time.Time
	Par      string
	Variable bool // NAUTILINK_METEOFRANCE posée
}

func (d donneesAdminReglages) Actif() bool { return d.Ecran || d.Variable }

func (a *app) reglagesMeteo(ctx context.Context) (donneesAdminReglages, error) {
	r := donneesAdminReglages{Variable: a.cfg.MeteoFrance != ""}
	err := a.b.pool.QueryRow(ctx, "SELECT modifie_le, modifie_par FROM reglages WHERE cle = $1", cleMeteoFrance).Scan(&r.Le, &r.Par)
	if err == nil {
		r.Ecran = true
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return r, err
	}
	return r, nil
}

func (a *app) routesReglagesAdmin(mux *http.ServeMux, ca string,
	tracer func(*http.Request, *sessionAdmin, string, string, string, any) error,
	vers func(http.ResponseWriter, *http.Request, string, string) error) {
	page := func(w http.ResponseWriter, r *http.Request, d *donneesAdmin) error {
		reg, err := a.reglagesMeteo(r.Context())
		if err != nil {
			return err
		}
		d.Titre, d.D = "Réglages", reg
		a.rendreAdmin(w, "admin-reglages.html", d)
		return nil
	}
	refus := func(w http.ResponseWriter, r *http.Request, d *donneesAdmin, err error) error {
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnprocessableEntity)
		return page(w, r, d)
	}
	mux.HandleFunc("GET "+ca+"/reglages", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if err := tracer(r, s, "consultation", "reglages", "", nil); err != nil {
			return err
		}
		return page(w, r, d)
	}))
	mux.HandleFunc("POST "+ca+"/reglages/meteofrance", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		code, err := normaliserCodeMeteo(r.FormValue("code"))
		if err != nil {
			return refus(w, r, d, err)
		}
		ok := "meteo-accepte"
		if err := a.verifierCodeMeteo(r.Context(), code); errors.Is(err, errCodeRefuse) {
			return refus(w, r, d, errInvalide("Météo-France refuse ce code : vérifiez-le sur le portail de Météo-France. Le code en service est inchangé."))
		} else if err != nil {
			ok = "meteo-non-verifie"
		}
		if _, err := a.b.pool.Exec(r.Context(), `INSERT INTO reglages (cle, valeur, modifie_par) VALUES ($1, $2, $3)
			ON CONFLICT (cle) DO UPDATE SET valeur = excluded.valeur, modifie_le = now(), modifie_par = excluded.modifie_par`,
			cleMeteoFrance, code, s.email); err != nil {
			return err
		}
		a.meteo.poserReglage(code)
		if err := tracer(r, s, "modification", "reglages", cleMeteoFrance, map[string]string{"verification": ok}); err != nil {
			return err
		}
		return vers(w, r, "/reglages", ok)
	}))
	mux.HandleFunc("POST "+ca+"/reglages/meteofrance/suppression", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if _, err := a.b.pool.Exec(r.Context(), "DELETE FROM reglages WHERE cle = $1", cleMeteoFrance); err != nil {
			return err
		}
		a.meteo.poserReglage("")
		if err := tracer(r, s, "suppression", "reglages", cleMeteoFrance, nil); err != nil {
			return err
		}
		return vers(w, r, "/reglages", "meteo-retire")
	}))
	mux.HandleFunc("POST "+ca+"/reglages/meteofrance/verification", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if err := a.chargerCodeMeteo(r.Context()); err != nil {
			return err
		}
		code := a.meteo.identifiant()
		var err error
		if code == "" {
			err = errInvalide("Aucun code en service : la météo n'est pas relevée.")
		} else if e := a.verifierCodeMeteo(r.Context(), code); errors.Is(e, errCodeRefuse) {
			err = errInvalide("Météo-France refuse le code en service : posez-en un nouveau.")
		} else if e != nil {
			err = errInvalide("Météo-France n'a pas répondu : réessayez plus tard.")
		}
		if e := tracer(r, s, "verification", "reglages", cleMeteoFrance, map[string]bool{"accepte": err == nil}); e != nil {
			return e
		}
		if err != nil {
			return refus(w, r, d, err)
		}
		return vers(w, r, "/reglages", "meteo-verifie")
	}))
}
