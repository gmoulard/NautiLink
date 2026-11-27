package main

import (
	"context"
	"errors"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"
)

// Démarrage d'une navigation depuis l'Application web (TODO-6.8, RG-WEB-06,
// D-163) : bateau parmi ceux du compte (RG-CPT-05), destination, fréquence
// (RG-NAV-05), personnes à bord (RG-NAV-27), chef de bord (RG-NAV-35),
// personnes alertées avec la seule case « E-mail » (RG-NAV-25 : aucun SMS
// depuis le Web, RG-WEB-01), quota (RG-NAV-07, RG-ECO-04), avertissement
// sans ami coché (RG-SOS-14). Position du début par la géolocalisation du
// navigateur Internet si la personne l'accepte (RG-WEB-05), heures dans son
// fuseau (RG-WEB-07) : champs remplis par static/conduite.js. La navigation
// n'est rattachée à aucun téléphone ; le téléphone associé du bateau la
// reprend (RG-NAV-33) et lui est rattaché à son premier envoi.

type personneAlertee struct {
	ID, Nom     string
	Sos, Cochee bool
	SansEmail   bool // ni e-mail ni compte : aucun e-mail possible
}

type donneesDemarrage struct {
	Bateaux        []bateauJSON
	BateauID       string
	Destination    string
	Frequences     []optionFrequence
	PersonnesABord int
	ChefDeBord     string
	Personnes      []personneAlertee
	SansAmiAlerte  bool
	QuotaEpuise    string // RG-ECO-04 : explication et heure de disponibilité
}

type optionFrequence struct {
	Minutes int
	Libelle string
	Choisie bool
}

func init() {
	messages["demarree"] = "Navigation démarrée. Gardez cette page ouverte pour envoyer les positions automatiques."
	messages["position"] = "Position envoyée."
}

// decalageWeb : décalage horaire du navigateur Internet, en minutes, lu par
// static/conduite.js (RG-WEB-07) ; absent ou invalide : nul (UTC).
func decalageWeb(v string) *int {
	m, err := strconv.Atoi(strings.TrimSpace(v))
	if err != nil || m < -14*60 || m > 14*60 {
		return nil
	}
	return &m
}

// positionWeb : position de la géolocalisation du navigateur Internet
// (RG-WEB-05), remplie par static/conduite.js ; absente : nulle.
func positionWeb(r *http.Request, h time.Time) *positionJSON {
	lat, err1 := strconv.ParseFloat(r.FormValue("latitude"), 64)
	lon, err2 := strconv.ParseFloat(r.FormValue("longitude"), 64)
	if err1 != nil || err2 != nil {
		return nil
	}
	p := &positionJSON{Latitude: lat, Longitude: lon, HeureAcquisition: h}
	if prec, err := strconv.ParseFloat(r.FormValue("precision"), 64); err == nil && prec >= 0 {
		p.PrecisionMetres = &prec
	}
	return p
}

// demarrageWeb : contenu du démarrage d'après le formulaire.
func demarrageWeb(r *http.Request, nomNavigateur string, h time.Time) demarrageJSON {
	d := demarrageJSON{web: true, BateauID: r.FormValue("bateauId"), Debut: evenementJSON{ID: nouvelUUID(), Type: "debut",
		Origine: "web", HeureAcquisition: h, Position: positionWeb(r, h)}}
	d.FrequenceMinutes, _ = strconv.Atoi(r.FormValue("frequence"))
	d.PersonnesABord, _ = strconv.Atoi(r.FormValue("personnesABord"))
	if dest := strings.TrimSpace(r.FormValue("destination")); dest != "" {
		d.Destination = &destinationJSON{Texte: dest}
	}
	if chef := strings.TrimSpace(r.FormValue("chefDeBord")); chef != nomNavigateur {
		d.ChefDeBord = &chef
	}
	alertees := []string{}
	for _, id := range r.Form["email"] {
		if estUUID(id) && !slices.Contains(alertees, id) {
			alertees = append(alertees, id)
		}
	}
	d.PersonnesAlertees = &alertees
	return d
}

// donneesDuDemarrage : écran de démarrage prérempli (RG-NAV-05, RG-NAV-27,
// RG-NAV-35) ; après une erreur, les valeurs saisies.
func (a *app) donneesDuDemarrage(ctx context.Context, utilisateur, nom string, saisie *demarrageJSON) (donneesDemarrage, error) {
	var d donneesDemarrage
	var err error
	if d.Bateaux, err = a.bateaux(ctx, utilisateur); err != nil {
		return d, err
	}
	p, err := a.parametres(ctx, utilisateur)
	if err != nil {
		return d, err
	}
	frequence := 60
	if p.FrequenceParDefaut != nil {
		frequence = *p.FrequenceParDefaut
	}
	d.PersonnesABord, d.ChefDeBord = 1, nom
	if err := a.b.pool.QueryRow(ctx, `SELECT coalesce((SELECT personnes_a_bord FROM navigations WHERE navigateur_id = $1
		ORDER BY debut_enregistre DESC LIMIT 1), 1)`, utilisateur).Scan(&d.PersonnesABord); err != nil {
		return d, err
	}
	var cochees []string
	if saisie != nil {
		d.BateauID, frequence, d.PersonnesABord = saisie.BateauID, saisie.FrequenceMinutes, saisie.PersonnesABord
		if saisie.Destination != nil {
			d.Destination = saisie.Destination.Texte
		}
		if saisie.ChefDeBord != nil {
			d.ChefDeBord = *saisie.ChefDeBord
		}
		cochees = *saisie.PersonnesAlertees
	}
	for _, m := range frequences {
		d.Frequences = append(d.Frequences, optionFrequence{Minutes: m, Libelle: libelleFrequence(m), Choisie: m == frequence})
	}
	contacts, _, _, err := a.contacts(ctx, utilisateur, 0)
	if err != nil {
		return d, err
	}
	// Tous les amis sont alertés, SOS compris (RG-NAV-25, D-176).
	d.SansAmiAlerte = true
	for _, c := range contacts {
		pa := personneAlertee{ID: c.ID, Nom: c.Nom, Sos: true, Cochee: saisie == nil || slices.Contains(cochees, c.ID),
			SansEmail: c.Email == nil && c.UtilisateurID == nil}
		if pa.Sos && pa.Cochee {
			d.SansAmiAlerte = false
		}
		d.Personnes = append(d.Personnes, pa)
	}
	if err := a.verifierQuotaAuDemarrage(ctx, utilisateur); err != nil {
		var q *erreurQuota
		if !errors.As(err, &q) {
			return d, err
		}
		d.QuotaEpuise = texteQuotaEpuise(q)
	}
	return d, nil
}

// texteQuotaEpuise : RG-ECO-04 : explication et heure à laquelle des minutes
// redeviennent disponibles (en UTC : le fuseau du navigateur Internet n'est
// pas encore connu à l'affichage).
func texteQuotaEpuise(q *erreurQuota) string {
	return q.message + " Des minutes redeviennent disponibles le " + heureWeb(q.disponibleLe, nil) + "."
}

func (a *app) routesWebDemarrage(mux *http.ServeMux, c string) {
	page := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, saisie *demarrageJSON) error {
		dd, err := a.donneesDuDemarrage(r.Context(), s.utilisateur, d.Nom, saisie)
		if err != nil {
			return err
		}
		d.Titre, d.D = "Démarrer navigation", dd
		a.rendre(w, "demarrer.html", d)
		return nil
	}
	mux.HandleFunc("GET "+c+"/demarrer", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		return page(w, r, s, d, nil)
	}))
	mux.HandleFunc("POST "+c+"/demarrer", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := r.ParseForm(); err != nil {
			return errInvalide("Formulaire illisible.")
		}
		saisie := demarrageWeb(r, d.Nom, a.heureWebMaintenant(decalageWeb(r.FormValue("decalage"))))
		id := nouvelUUID()
		_, _, err := a.demarrer(r.Context(), s.utilisateur, id, saisie)
		if err == nil {
			http.Redirect(w, r, c+"/navigations/"+id+"?ok=demarree", http.StatusSeeOther)
			return nil
		}
		statut := http.StatusUnprocessableEntity
		if e := (*erreurAPI)(nil); errors.As(err, &e) {
			statut = e.statut
		}
		var q *erreurQuota
		if errors.As(err, &q) {
			d.Erreur = texteQuotaEpuise(q)
		} else if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(statut)
		return page(w, r, s, d, &saisie)
	}))
}
