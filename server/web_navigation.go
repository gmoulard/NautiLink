package main

import (
	"context"
	"net/http"
	"strconv"
)

// Page d'une navigation (TODO-6.2, cahier des charges 6.2) : informations
// générales et fiche du bateau (RG-NAV-16, RG-NAV-27, RG-PAR-08), carte
// (RG-NAV-29, RG-NAV-31), journal de bord chronologique avec photos et notes
// vocales (RG-JRN-02, RG-JRN-03, RG-JRN-09, RG-JRN-10), alertes SOS
// (RG-SOS-13), suiveurs et contacts SOS (RG-PAR-08) ; pour le navigateur :
// retrait d'un suiveur de cette navigation (RG-PAR-06) et « Supprimer »
// (RG-NAV-20). Lecture seule pour un suiveur (RG-PAR-07). Pendant une
// navigation en cours, static/navigation.js relit toutes les 30 secondes la
// partie « en direct » de la page avec le curseur « depuis » du journal
// (08-architecture.md §4).

// libellesEvenement : types d'événements du journal (RG-JRN-02).
var libellesEvenement = map[string]string{
	"debut": "Début de navigation", "position_automatique": "Position automatique",
	"position_manuelle": "Position manuelle", "note": "Note écrite", "photo": "Photo", "note_vocale": "Note vocale",
	"sos": "Alerte SOS", "fin": "Fin de navigation", "ajout": "Ajout complémentaire",
}

// ligneJournal : un événement du journal de bord.
type ligneJournal struct {
	E                  evenementJSON
	Libelle, Heure     string
	Lieu               string
	Photo, Vocal       bool
	Modifiable, Masque bool
}

type ligneAlerte struct {
	A              alerteSosJSON
	Heure, Lieu    string
	HorsNavigation bool
}

type donneesNavigation struct {
	N                  navigationJSON
	L                  ligneNav
	Navigateur         bool // la page est vue par son navigateur
	EnCours, Corbeille bool
	Destination        string
	Frequence          string
	Carte              *carte
	Journal            []ligneJournal
	Alertes            []ligneAlerte
	Curseur            int64
	Suppression        string           // date de suppression définitive, dans la corbeille
	Modifier           *modificationNav // formulaires du navigateur (TODO-6.3), hors corbeille
}

// journalPresente : lignes du journal ; modifiables : notes, photos, notes
// vocales et ajouts, par le navigateur, hors corbeille (RG-JRN-06, RG-JRN-07,
// RG-NAV-30).
func journalPresente(evts []evenementJSON, decalage *int, modifiable bool) []ligneJournal {
	l := []ligneJournal{}
	for _, e := range evts {
		j := ligneJournal{E: e, Libelle: libellesEvenement[e.Type], Heure: heureWeb(e.HeureAcquisition, decalage), Masque: e.Masque}
		if e.Position != nil {
			j.Lieu = lieuTexte(&lieuJSON{Nom: e.Lieu, Position: e.Position})
		}
		if e.Fichier != nil {
			j.Photo, j.Vocal = e.Fichier.TypeMedia == "image/jpeg", e.Fichier.TypeMedia == "audio/mp4"
		}
		switch e.Type {
		case "note", "photo", "note_vocale", "ajout":
			j.Modifiable = modifiable
		}
		l = append(l, j)
	}
	return l
}

// carteDe : tracé des positions non masquées (RG-NAV-22) ; départ, arrivée
// ou dernière position ; notes, photos et notes vocales situées ; alertes
// SOS, même hors des heures affichées (RG-NAV-31).
func carteDe(evts []evenementJSON, enCours bool, decalage *int, largeur, hauteur float64, avecDalles bool) *carte {
	var trace, points, marques []pointCarte
	var heures []string
	for _, e := range evts {
		if e.Position == nil {
			continue
		}
		h := heureWeb(e.HeureAcquisition, decalage)
		p := pointCarte{Latitude: e.Position.Latitude, Longitude: e.Position.Longitude, Titre: libellesEvenement[e.Type] + " · " + h}
		switch {
		case e.Type == "sos":
			p.Sorte = "sos"
			marques = append(marques, p)
			continue
		case e.Masque:
			continue
		case e.Type == "note" || e.Type == "photo" || e.Type == "note_vocale" || e.Type == "ajout":
			p.Sorte = "evenement"
			marques = append(marques, p)
		}
		trace = append(trace, pointCarte{Latitude: p.Latitude, Longitude: p.Longitude})
		points = append(points, pointCarte{Latitude: p.Latitude, Longitude: p.Longitude, Sorte: "position", Titre: p.Titre})
		heures = append(heures, h)
	}
	if len(trace) > 0 {
		dep, der := trace[0], trace[len(trace)-1]
		dep.Sorte, dep.Titre = "depart", "Départ · "+heures[0]
		der.Sorte, der.Titre = "arrivee", "Arrivée · "+heures[len(heures)-1]
		if enCours {
			der.Sorte, der.Titre = "derniere", "Dernière position · "+heures[len(heures)-1]
		}
		points = append(points, dep, der)
	}
	// Les marques des événements et des SOS passent au-dessus du tracé.
	return cadrer(trace, append(points, marques...), largeur, hauteur, avecDalles)
}

// donneesDeLaNavigation : tout ce qu'affichent la page et le PDF.
func (a *app) donneesDeLaNavigation(ctx context.Context, utilisateur, id string) (donneesNavigation, error) {
	var d donneesNavigation
	n, role, err := a.navigationVue(ctx, utilisateur, id)
	if err != nil {
		return d, err
	}
	if d.N, err = a.detailler(ctx, n, role); err != nil {
		return d, err
	}
	d.Navigateur, d.EnCours, d.Corbeille = role == "navigateur", d.N.Etat == "en_cours", d.N.Etat == "corbeille"
	if d.Corbeille {
		d.Suppression = dateFrancaise(*d.N.SupprimeeDefinitivementLe)
	}
	if d.L, err = a.ligneDe(ctx, d.N); err != nil {
		return d, err
	}
	if n.destination != nil {
		d.Destination = n.destination.Texte
		if d.Destination == "" && n.destination.Position != nil {
			d.Destination = coordonnees(*n.destination.Position)
		}
	}
	d.Frequence = libelleFrequence(n.frequence)
	evts, _, curseur, err := a.journalDeBord(ctx, n, 0)
	if err != nil {
		return d, err
	}
	d.Curseur = curseur
	d.Journal = journalPresente(evts, n.decalage, d.Navigateur && !d.Corbeille)
	d.Carte = carteDe(evts, d.EnCours, n.decalage, 800, 500, true)
	alertes, err := a.alertes(ctx, utilisateur, "", n.id)
	if err != nil {
		return d, err
	}
	for i := len(alertes) - 1; i >= 0; i-- { // ordre chronologique
		al := alertes[i]
		la := ligneAlerte{A: al, Heure: heureWeb(al.HeureDeclenchement, n.decalage), HorsNavigation: n.masque(al.HeureDeclenchement)}
		if al.Position != nil {
			la.Lieu = coordonnees(*al.Position)
		}
		d.Alertes = append(d.Alertes, la)
	}
	if d.Navigateur && !d.Corbeille {
		if d.Modifier, err = a.modificationDe(ctx, utilisateur, n); err != nil {
			return d, err
		}
	}
	return d, nil
}

func init() {
	messages["retire"] = "Ce suiveur n'a plus accès à cette navigation."
}

// origineSeulement : les serveurs de dalles d'OpenStreetMap demandent
// l'origine de la page (règles d'usage), jamais son chemin, qui contient
// l'identifiant de la navigation.
func origineSeulement(w http.ResponseWriter) {
	w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
}

func (a *app) routesWebNavigations(mux *http.ServeMux, c string) {
	mux.HandleFunc("GET "+c+"/navigations/{id}", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		n, err := a.donneesDeLaNavigation(r.Context(), s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		d.Titre, d.D = n.N.Nom, n
		origineSeulement(w)
		a.rendre(w, "navigation.html", d)
		return nil
	}))
	// Partie « en direct » de la page, relue par static/navigation.js : 204
	// tant que rien n'a changé depuis le curseur et la version reçus.
	mux.HandleFunc("GET "+c+"/navigations/{id}/direct", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		n, _, err := a.navigationVue(r.Context(), s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		q := r.URL.Query()
		depuis, _ := strconv.ParseInt(q.Get("depuis"), 10, 64)
		evts, supprimes, curseur, err := a.journalDeBord(r.Context(), n, depuis)
		if err != nil {
			return err
		}
		if n.enCours() && len(evts) == 0 && len(supprimes) == 0 && q.Get("version") == strconv.Itoa(n.version) {
			w.Header().Set("X-Etat", "en_cours")
			w.Header().Set("X-Curseur", strconv.FormatInt(curseur, 10))
			w.Header().Set("Cache-Control", "no-store")
			w.WriteHeader(http.StatusNoContent)
			return nil
		}
		nav, err := a.donneesDeLaNavigation(r.Context(), s.utilisateur, n.id)
		if err != nil {
			return err
		}
		d.D = nav
		w.Header().Set("X-Etat", nav.N.Etat)
		w.Header().Set("X-Curseur", strconv.FormatInt(nav.Curseur, 10))
		w.Header().Set("X-Version", strconv.Itoa(nav.N.Version))
		origineSeulement(w)
		a.rendre(w, "navigation-direct", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/navigations/{id}/suiveurs/{suiveur}/retrait", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.retirerDeLaNavigation(r.Context(), s.utilisateur, r.PathValue("id"), r.PathValue("suiveur")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/navigations/"+r.PathValue("id")+"?ok=retire", http.StatusSeeOther)
		return nil
	}))
}
