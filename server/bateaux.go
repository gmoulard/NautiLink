package main

import (
	"bytes"
	"context"
	"errors"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Appareils, bateaux, fiche bateau, téléphone associé (TODO-4.2) : RG-CPT-04,
// RG-CPT-05, RG-BAT-01, RG-BAT-02, RG-BAT-03, RG-IOS-01.

const taillePhotoBateauMax = 5 << 20 // 5 Mo

type appareilJSON struct {
	ID                 string  `json:"id"`
	Plateforme         string  `json:"plateforme"`
	Nom                string  `json:"nom"`
	JetonPush          *string `json:"jetonPush"`
	VersionApplication string  `json:"versionApplication"`
}

type bateauJSON struct {
	ID                      string   `json:"id"`
	ProprietaireID          string   `json:"proprietaireId"`
	Nom                     string   `json:"nom"`
	Type                    string   `json:"type"`
	LongueurMetres          *float64 `json:"longueurMetres,omitempty"`
	Immatriculation         string   `json:"immatriculation"`
	PortAttache             string   `json:"portAttache"`
	Moteur                  string   `json:"moteur"`
	Autonomie               string   `json:"autonomie"`
	CapaciteCarburantLitres *float64 `json:"capaciteCarburantLitres,omitempty"`
	VitesseNoeuds           *float64 `json:"vitesseNoeuds,omitempty"`
	TirantEauMetres         *float64 `json:"tirantEauMetres,omitempty"`
	AppareilAssocieID       *string  `json:"appareilAssocieId"`
	AUnePhoto               bool     `json:"aUnePhoto"`
}

const colonnesBateau = `id, proprietaire_id, nom, type, longueur_metres, immatriculation, port_attache, moteur,
	autonomie, capacite_carburant_litres, vitesse_noeuds, tirant_eau_metres, appareil_associe_id, photo IS NOT NULL`

func lireBateau(l pgx.Row) (bateauJSON, error) {
	var b bateauJSON
	err := l.Scan(&b.ID, &b.ProprietaireID, &b.Nom, &b.Type, &b.LongueurMetres, &b.Immatriculation, &b.PortAttache,
		&b.Moteur, &b.Autonomie, &b.CapaciteCarburantLitres, &b.VitesseNoeuds, &b.TirantEauMetres,
		&b.AppareilAssocieID, &b.AUnePhoto)
	return b, err
}

// estUUID : identifiant au format UUID, sans quoi PostgreSQL refuserait la
// requête ; un identifiant mal formé est traité comme introuvable.
func estUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		switch {
		case i == 8 || i == 13 || i == 18 || i == 23:
			if c != '-' {
				return false
			}
		case !strings.ContainsRune("0123456789abcdefABCDEF", c):
			return false
		}
	}
	return true
}

// ------------------------------------------------------------------ appareils

// enregistrerAppareil : téléphone de l'utilisateur, identifiant tiré par
// l'application. Un téléphone enregistré par un autre compte est refusé tant
// que le cas n'est pas décidé (Q-50).
func (a *app) enregistrerAppareil(ctx context.Context, s *session, id string, c champs) (appareilJSON, error) {
	var ap appareilJSON
	if !estUUID(id) {
		return ap, errInvalide("Identifiant d'appareil invalide.")
	}
	if err := c.lire("plateforme", &ap.Plateforme); err != nil || (ap.Plateforme != "android" && ap.Plateforme != "ios") {
		return ap, errInvalide("Plateforme invalide : android ou ios.")
	}
	for nom, v := range map[string]any{"nom": &ap.Nom, "jetonPush": &ap.JetonPush, "versionApplication": &ap.VersionApplication} {
		if c.a(nom) {
			if err := c.lire(nom, v); err != nil {
				return ap, err
			}
		}
	}
	if len(ap.Nom) > 100 || len(ap.VersionApplication) > 50 || (ap.JetonPush != nil && len(*ap.JetonPush) > 4096) {
		return ap, errInvalide("Champ trop long.")
	}
	var proprietaire string
	err := a.b.pool.QueryRow(ctx, `INSERT INTO appareils (id, utilisateur_id, plateforme, nom, jeton_push, version_application)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (id) DO UPDATE SET plateforme = EXCLUDED.plateforme, nom = EXCLUDED.nom,
			jeton_push = EXCLUDED.jeton_push, version_application = EXCLUDED.version_application, mis_a_jour_le = now()
			WHERE appareils.utilisateur_id = EXCLUDED.utilisateur_id
		RETURNING utilisateur_id`, id, s.utilisateur, ap.Plateforme, ap.Nom, ap.JetonPush, ap.VersionApplication).Scan(&proprietaire)
	if errors.Is(err, pgx.ErrNoRows) {
		return ap, errInterdit("interdit", "Ce téléphone est enregistré par un autre compte.")
	}
	if err != nil {
		return ap, err
	}
	ap.ID = id
	// La session de ce téléphone le connaît : elle n'expire pas pendant une
	// navigation en cours (RG-CPT-08).
	if !s.parCookie {
		_, err = a.b.pool.Exec(ctx, "UPDATE sessions SET appareil_id = $2 WHERE id = $1", s.id, id)
	}
	return ap, err
}

func (a *app) appareils(ctx context.Context, utilisateur string) ([]appareilJSON, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT id, plateforme, nom, jeton_push, version_application FROM appareils
		WHERE utilisateur_id = $1 ORDER BY mis_a_jour_le DESC`, utilisateur)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(lignes, func(l pgx.CollectableRow) (appareilJSON, error) {
		var ap appareilJSON
		err := l.Scan(&ap.ID, &ap.Plateforme, &ap.Nom, &ap.JetonPush, &ap.VersionApplication)
		return ap, err
	})
}

// ------------------------------------------------------------------ bateaux

func (a *app) bateaux(ctx context.Context, utilisateur string) ([]bateauJSON, error) {
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesBateau+" FROM bateaux WHERE proprietaire_id = $1 ORDER BY cree_le", utilisateur)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(lignes, func(l pgx.CollectableRow) (bateauJSON, error) { return lireBateau(l) })
}

// bateauVisible : fiche visible du propriétaire et des suiveurs du
// propriétaire (RG-PAR-08) ; sinon introuvable.
func (a *app) bateauVisible(ctx context.Context, utilisateur, id string) (bateauJSON, error) {
	if !estUUID(id) {
		return bateauJSON{}, errIntrouvable()
	}
	b, err := lireBateau(a.b.pool.QueryRow(ctx, "SELECT "+colonnesBateau+" FROM bateaux WHERE id = $1", id))
	if err != nil {
		return b, err
	}
	if b.ProprietaireID != utilisateur && !a.suitLeNavigateur(ctx, utilisateur, b.ProprietaireID) {
		return b, errIntrouvable()
	}
	return b, nil
}

// suitLeNavigateur : vrai si suiveur a un accès de périmètre navigateur
// donné par navigateur (RG-PAR-02). Les accès arrivent avec TODO-4.3.
func (a *app) suitLeNavigateur(ctx context.Context, suiveur, navigateur string) bool {
	return false
}

// bateauDuProprietaire : fiche modifiable par son seul propriétaire (RG-CPT-04).
func (a *app) bateauDuProprietaire(ctx context.Context, utilisateur, id string) (bateauJSON, error) {
	b, err := a.bateauVisible(ctx, utilisateur, id)
	if err == nil && b.ProprietaireID != utilisateur {
		err = errInterdit("pas_proprietaire", "Seul le propriétaire du bateau peut le modifier.")
	}
	return b, err
}

// peutDemarrer : seul le propriétaire d'un bateau démarre une navigation avec
// ce bateau (RG-CPT-05) ; servira au démarrage des navigations (TODO-4.5).
func (a *app) peutDemarrer(ctx context.Context, utilisateur, bateau string) (bool, error) {
	if !estUUID(bateau) {
		return false, nil
	}
	var ok bool
	err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM bateaux WHERE id = $1 AND proprietaire_id = $2)",
		bateau, utilisateur).Scan(&ok)
	return ok, err
}

// appliquerFiche : champs de la fiche (RG-BAT-01) présents dans c ; à la
// création, nom et type sont obligatoires.
func appliquerFiche(b *bateauJSON, c champs, creation bool) error {
	textes := map[string]*string{"nom": &b.Nom, "type": &b.Type, "immatriculation": &b.Immatriculation,
		"portAttache": &b.PortAttache, "moteur": &b.Moteur, "autonomie": &b.Autonomie}
	for nom, v := range textes {
		if c.a(nom) {
			var t *string
			if err := c.lire(nom, &t); err != nil {
				return err
			}
			*v = ""
			if t != nil {
				*v = strings.TrimSpace(*t)
			}
			if len([]rune(*v)) > 200 || strings.ContainsAny(*v, "\r\n") {
				return errInvalide("Champ « " + nom + " » trop long.")
			}
		}
	}
	nombres := map[string]**float64{"longueurMetres": &b.LongueurMetres, "capaciteCarburantLitres": &b.CapaciteCarburantLitres,
		"vitesseNoeuds": &b.VitesseNoeuds, "tirantEauMetres": &b.TirantEauMetres}
	for nom, v := range nombres {
		if c.a(nom) {
			var n *float64
			if err := c.lire(nom, &n); err != nil {
				return err
			}
			if n != nil && (*n < 0 || *n > 100000 || math.IsNaN(*n)) {
				return errInvalide("Champ « " + nom + " » invalide.")
			}
			*v = n
		}
	}
	if b.Nom == "" && (creation || c.a("nom")) {
		return errInvalide("Indiquez le nom du bateau.")
	}
	if b.Type != "voilier" && b.Type != "moteur" {
		return errInvalide("Type de bateau invalide : voilier ou moteur.")
	}
	return nil
}

func (a *app) enregistrerFiche(ctx context.Context, b bateauJSON, creation bool) (bateauJSON, error) {
	var requete string
	if creation {
		requete = `INSERT INTO bateaux (proprietaire_id, nom, type, longueur_metres, immatriculation, port_attache, moteur,
			autonomie, capacite_carburant_litres, vitesse_noeuds, tirant_eau_metres)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING ` + colonnesBateau
	} else {
		requete = `UPDATE bateaux SET nom = $2, type = $3, longueur_metres = $4, immatriculation = $5, port_attache = $6,
			moteur = $7, autonomie = $8, capacite_carburant_litres = $9, vitesse_noeuds = $10, tirant_eau_metres = $11,
			modifie_le = now() WHERE id = $12 AND proprietaire_id = $1 RETURNING ` + colonnesBateau
	}
	args := []any{b.ProprietaireID, b.Nom, b.Type, b.LongueurMetres, b.Immatriculation, b.PortAttache, b.Moteur,
		b.Autonomie, b.CapaciteCarburantLitres, b.VitesseNoeuds, b.TirantEauMetres}
	if !creation {
		args = append(args, b.ID)
	}
	return lireBateau(a.b.pool.QueryRow(ctx, requete, args...))
}

func (a *app) creerBateau(ctx context.Context, utilisateur string, c champs) (bateauJSON, error) {
	b := bateauJSON{ProprietaireID: utilisateur}
	if err := appliquerFiche(&b, c, true); err != nil {
		return b, err
	}
	return a.enregistrerFiche(ctx, b, true)
}

// modifierBateau : seuls les champs présents changent (RG-COM-04).
func (a *app) modifierBateau(ctx context.Context, utilisateur, id string, c champs) (bateauJSON, error) {
	b, err := a.bateauDuProprietaire(ctx, utilisateur, id)
	if err != nil {
		return b, err
	}
	if err := appliquerFiche(&b, c, false); err != nil {
		return b, err
	}
	return a.enregistrerFiche(ctx, b, false)
}

func (a *app) enregistrerPhotoBateau(ctx context.Context, utilisateur, id string, photo io.Reader) error {
	if _, err := a.bateauDuProprietaire(ctx, utilisateur, id); err != nil {
		return err
	}
	donnees, err := io.ReadAll(io.LimitReader(photo, taillePhotoBateauMax+1))
	if err != nil {
		return errInvalide("Photo illisible.")
	}
	if len(donnees) > taillePhotoBateauMax {
		return &erreurAPI{http.StatusRequestEntityTooLarge, "invalide", "Photo trop grosse (5 Mo au plus).", 0}
	}
	if !bytes.HasPrefix(donnees, []byte{0xFF, 0xD8, 0xFF}) {
		return errInvalide("La photo doit être au format JPEG.")
	}
	_, err = a.b.pool.Exec(ctx, "UPDATE bateaux SET photo = $2, modifie_le = now() WHERE id = $1", id, donnees)
	return err
}

// associerTelephone : un bateau a au plus un téléphone associé ; associer un
// autre téléphone remplace l'association précédente ; le téléphone doit être
// enregistré par le propriétaire (RG-BAT-02).
func (a *app) associerTelephone(ctx context.Context, utilisateur, id, appareil string) (bateauJSON, error) {
	if _, err := a.bateauDuProprietaire(ctx, utilisateur, id); err != nil {
		return bateauJSON{}, err
	}
	var ok bool
	if estUUID(appareil) {
		if err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM appareils WHERE id = $1 AND utilisateur_id = $2)",
			appareil, utilisateur).Scan(&ok); err != nil {
			return bateauJSON{}, err
		}
	}
	if !ok {
		return bateauJSON{}, errInterdit("interdit", "Ce téléphone n'est pas enregistré sur votre compte.")
	}
	return lireBateau(a.b.pool.QueryRow(ctx, `UPDATE bateaux SET appareil_associe_id = $2, modifie_le = now()
		WHERE id = $1 RETURNING `+colonnesBateau, id, appareil))
}

// ------------------------------------------------------------------ routes de l'API

func (a *app) routesBateaux(mux *http.ServeMux, v string) {
	mux.HandleFunc("PUT "+v+"/appareils/{appareilId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		ap, err := a.enregistrerAppareil(r.Context(), s, r.PathValue("appareilId"), c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, ap)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/bateaux", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		l, err := a.bateaux(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, l)
		return nil
	}))
	mux.HandleFunc("POST "+v+"/bateaux", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		b, err := a.creerBateau(r.Context(), s.utilisateur, c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusCreated, b)
		return nil
	}))
	mux.HandleFunc("GET "+v+"/bateaux/{bateauId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		b, err := a.bateauVisible(r.Context(), s.utilisateur, r.PathValue("bateauId"))
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, b)
		return nil
	}))
	mux.HandleFunc("PATCH "+v+"/bateaux/{bateauId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		b, err := a.modifierBateau(r.Context(), s.utilisateur, r.PathValue("bateauId"), c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, b)
		return nil
	}))
	mux.HandleFunc("PUT "+v+"/bateaux/{bateauId}/photo", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if !strings.HasPrefix(r.Header.Get("Content-Type"), "image/jpeg") {
			return &erreurAPI{http.StatusUnsupportedMediaType, "invalide", "La photo doit être au format JPEG.", 0}
		}
		if err := a.enregistrerPhotoBateau(r.Context(), s.utilisateur, r.PathValue("bateauId"), r.Body); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
	mux.HandleFunc("GET "+v+"/bateaux/{bateauId}/photo", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if _, err := a.bateauVisible(r.Context(), s.utilisateur, r.PathValue("bateauId")); err != nil {
			return err
		}
		var photo []byte
		var modifie time.Time
		if err := a.b.pool.QueryRow(r.Context(), "SELECT photo, modifie_le FROM bateaux WHERE id = $1 AND photo IS NOT NULL",
			r.PathValue("bateauId")).Scan(&photo, &modifie); err != nil {
			return err
		}
		w.Header().Set("Content-Type", "image/jpeg")
		w.Header().Set("Cache-Control", "private, no-cache")
		w.Header().Set("Content-Length", strconv.Itoa(len(photo)))
		w.Header().Set("Last-Modified", modifie.UTC().Format(http.TimeFormat))
		_, _ = w.Write(photo)
		return nil
	}))
	mux.HandleFunc("PUT "+v+"/bateaux/{bateauId}/telephone", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c struct{ AppareilID string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		b, err := a.associerTelephone(r.Context(), s.utilisateur, r.PathValue("bateauId"), c.AppareilID)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, b)
		return nil
	}))
}
