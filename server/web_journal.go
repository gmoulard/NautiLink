package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/hex"
	"io"
	"net/http"
	"strings"
	"time"
)

// Compléter et corriger le journal, renommer (TODO-6.3), depuis la page
// d'une navigation, pour son navigateur seulement (RG-PAR-07) et hors
// corbeille (RG-NAV-30) : nom à tout moment (RG-NAV-17) ; destination,
// bateau (parmi les siens) et heures une fois terminée (RG-NAV-22) ; texte
// des notes, photos, notes vocales et ajouts modifié ou supprimés, quelle
// que soit leur origine (RG-JRN-06), jamais début, fin, positions ni SOS
// (RG-JRN-07) ; ajouts complémentaires (texte, photo ou note vocale) à une
// navigation terminée (RG-JRN-05), 20 photos au plus (RG-JRN-08), note
// vocale d'une minute au plus (RG-JRN-04). Heure d'un ajout : choisie entre
// le début et la fin, préremplie avec la fin, en attendant Q-98.

const formatSaisie = "2006-01-02T15:04" // champ « datetime-local »

// zoneDe : fuseau du téléphone au début de la navigation (RG-PRM-07), UTC
// sans décalage connu.
func zoneDe(decalage *int) *time.Location {
	if decalage == nil {
		return time.UTC
	}
	return time.FixedZone("", *decalage*60)
}

// libelleZone : fuseau des heures saisies, dit à côté des champs.
func libelleZone(decalage *int) string {
	if decalage == nil {
		return "heure UTC"
	}
	d, signe := *decalage, "+"
	if d < 0 {
		d, signe = -d, "-"
	}
	return "heure locale du téléphone (UTC" + signe + deuxChiffres(d/60) + ":" + deuxChiffres(d%60) + ")"
}

func valeurSaisie(t time.Time, decalage *int) string {
	return t.In(zoneDe(decalage)).Format(formatSaisie)
}

func heureSaisie(v string, decalage *int) (time.Time, error) {
	t, err := time.ParseInLocation(formatSaisie, strings.TrimSpace(v), zoneDe(decalage))
	if err != nil {
		return t, errInvalide("Heure illisible : jour et heure attendus.")
	}
	return t, nil
}

// dureeM4A : durée d'un fichier AAC (.m4a), lue dans la boîte « mvhd » de
// la boîte « moov » ; ok faux si elle est illisible.
func dureeM4A(b []byte) (secondes float64, ok bool) {
	boite := func(b []byte, nom string) []byte {
		for len(b) >= 8 {
			taille := int(binary.BigEndian.Uint32(b))
			entete := 8
			if taille == 1 && len(b) >= 16 {
				taille, entete = int(binary.BigEndian.Uint64(b[8:])), 16
			} else if taille == 0 {
				taille = len(b)
			}
			if taille < entete || taille > len(b) {
				return nil
			}
			if string(b[4:8]) == nom {
				return b[entete:taille]
			}
			b = b[taille:]
		}
		return nil
	}
	m := boite(boite(b, "moov"), "mvhd")
	switch {
	case len(m) >= 20 && m[0] == 0:
		echelle, duree := binary.BigEndian.Uint32(m[12:]), binary.BigEndian.Uint32(m[16:])
		if echelle > 0 {
			return float64(duree) / float64(echelle), true
		}
	case len(m) >= 32 && m[0] == 1:
		echelle, duree := binary.BigEndian.Uint32(m[20:]), binary.BigEndian.Uint64(m[24:])
		if echelle > 0 {
			return float64(duree) / float64(echelle), true
		}
	}
	return 0, false
}

// fichierAjout : photo JPEG ou note vocale AAC d'un ajout, reconnue à son
// contenu ; vide : ajout sans fichier.
func fichierAjout(donnees []byte) (*fichierJSON, error) {
	if len(donnees) == 0 {
		return nil, nil
	}
	if len(donnees) > tailleFichierMax {
		return nil, errInvalide("Fichier trop gros (5 Mo au plus).")
	}
	taille := len(donnees)
	if bytes.HasPrefix(donnees, []byte{0xFF, 0xD8, 0xFF}) {
		return &fichierJSON{TypeMedia: "image/jpeg", TailleOctets: &taille}, nil
	}
	if len(donnees) >= 12 && string(donnees[4:8]) == "ftyp" {
		s, ok := dureeM4A(donnees)
		if !ok {
			return nil, errInvalide("Note vocale illisible : fichier AAC (.m4a) attendu.")
		}
		if s > dureeVocaleMax+0.5 {
			return nil, errInvalide("Une note vocale dure 1 minute au plus.")
		}
		d := int(s + 0.5)
		return &fichierJSON{TypeMedia: "audio/mp4", TailleOctets: &taille, DureeSecondes: &d}, nil
	}
	return nil, errInvalide("Choisissez une photo JPEG ou une note vocale AAC (.m4a).")
}

// modificationNav : formulaires du navigateur sur la page de la navigation.
type modificationNav struct {
	Terminee           bool
	Nom, Destination   string
	BateauID           string
	Bateaux            []bateauJSON
	Debut, Fin, Zone   string
	HeureAjout         string
	AjoutMin, AjoutMax string
	PhotosRestantes    int
}

func (a *app) modificationDe(ctx context.Context, utilisateur string, n navLigne) (*modificationNav, error) {
	m := &modificationNav{Terminee: !n.enCours(), Nom: n.nom, BateauID: n.bateau, Zone: libelleZone(n.decalage),
		Debut: valeurSaisie(n.debut, n.decalage)}
	if n.destination != nil {
		m.Destination = n.destination.Texte
	}
	if !m.Terminee {
		return m, nil
	}
	var err error
	if m.Bateaux, err = a.bateaux(ctx, utilisateur); err != nil {
		return nil, err
	}
	m.Fin = valeurSaisie(*n.fin, n.decalage)
	m.HeureAjout, m.AjoutMin, m.AjoutMax = m.Fin, m.Debut, m.Fin
	var photos int
	if err := a.b.pool.QueryRow(ctx, `SELECT count(*) FROM evenements WHERE navigation_id = $1 AND fichier_type = 'image/jpeg'
		AND supprime_le IS NULL`, n.id).Scan(&photos); err != nil {
		return nil, err
	}
	m.PhotosRestantes = max(0, photosMax-photos)
	return m, nil
}

// champsModifies : seulement ce que le navigateur a changé (RG-COM-04) ; une
// heure laissée telle quelle garde ses secondes.
func champsModifies(r *http.Request, n navLigne) (champs, error) {
	c := champs{}
	if nom := strings.TrimSpace(r.FormValue("nom")); r.Form.Has("nom") && nom != n.nom {
		c["nom"] = enJSON(nom)
	}
	if n.enCours() {
		return c, nil
	}
	avant := ""
	if n.destination != nil {
		avant = n.destination.Texte
	}
	if dest := strings.TrimSpace(r.FormValue("destination")); r.Form.Has("destination") && dest != avant {
		if dest == "" {
			c["destination"] = enJSON(nil)
		} else {
			c["destination"] = enJSON(destinationJSON{Texte: dest})
		}
	}
	if b := r.FormValue("bateauId"); b != "" && b != n.bateau {
		c["bateauId"] = enJSON(b)
	}
	for nom, h := range map[string]time.Time{"debut": n.debut, "fin": *n.fin} {
		v := r.FormValue(nom)
		if v == "" || v == valeurSaisie(h, n.decalage) {
			continue
		}
		t, err := heureSaisie(v, n.decalage)
		if err != nil {
			return nil, err
		}
		c[nom] = enJSON(t)
	}
	return c, nil
}

func init() {
	messages["ajoute"] = "Ajout enregistré dans le journal."
	messages["supprime"] = "Élément supprimé du journal."
}

func (a *app) routesWebJournal(mux *http.ServeMux, c string) {
	// echec : erreur de saisie réaffichée sur la page, autre erreur remontée.
	echec := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, err error) error {
		// Le code de l'erreur est gardé : 403 pour un élément non modifiable
		// (RG-JRN-07), 422 pour une saisie refusée, 409 pour un conflit.
		statut := enErreurAPI(err).statut
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		nav, err := a.donneesDeLaNavigation(r.Context(), s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		d.Titre, d.D = nav.N.Nom, nav
		origineSeulement(w)
		w.WriteHeader(statut)
		a.rendre(w, "navigation.html", d)
		return nil
	}
	page := func(id, ok string) string { return c + "/navigations/" + id + "?ok=" + ok }

	mux.HandleFunc("POST "+c+"/navigations/{id}/modification", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		id := r.PathValue("id")
		n, err := a.navigationModifiable(r.Context(), s.utilisateur, id)
		if err != nil {
			return err
		}
		if err := r.ParseForm(); err != nil {
			return errInvalide("Formulaire illisible.")
		}
		ch, err := champsModifies(r, n)
		if err == nil && len(ch) > 0 {
			_, err = a.modifierNavigation(r.Context(), s.utilisateur, id, ch)
		}
		if err != nil {
			return echec(w, r, s, d, err)
		}
		http.Redirect(w, r, page(id, "enregistre"), http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/navigations/{id}/evenements/{evenement}", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		texte := r.FormValue("texte")
		if _, err := a.modifierTexteEvenement(r.Context(), s.utilisateur, r.PathValue("id"), r.PathValue("evenement"), &texte); err != nil {
			return echec(w, r, s, d, err)
		}
		http.Redirect(w, r, page(r.PathValue("id"), "enregistre")+"#evenement-"+r.PathValue("evenement"), http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/navigations/{id}/evenements/{evenement}/suppression", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.supprimerEvenement(r.Context(), s.utilisateur, r.PathValue("id"), r.PathValue("evenement")); err != nil {
			return echec(w, r, s, d, err)
		}
		http.Redirect(w, r, page(r.PathValue("id"), "supprime"), http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/navigations/{id}/ajouts", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		id := r.PathValue("id")
		n, err := a.navigationModifiable(r.Context(), s.utilisateur, id)
		if err != nil {
			return err
		}
		if n.enCours() {
			return echec(w, r, s, d, errInvalide("Les ajouts se font une fois la navigation terminée."))
		}
		var donnees []byte
		if f, _, err := r.FormFile("fichier"); err == nil {
			donnees, err = io.ReadAll(io.LimitReader(f, tailleFichierMax+1))
			f.Close()
			if err != nil {
				return errInvalide("Fichier illisible.")
			}
		}
		e := evenementJSON{ID: nouvelUUID(), Type: "ajout", Origine: "web", Texte: texteOuNul(ptr(r.FormValue("texte")))}
		if e.Fichier, err = fichierAjout(donnees); err != nil {
			return echec(w, r, s, d, err)
		}
		if e.Texte == nil && e.Fichier == nil {
			return echec(w, r, s, d, errInvalide("Écrivez un texte ou choisissez une photo ou une note vocale."))
		}
		if e.HeureAcquisition, err = heureSaisie(r.FormValue("heure"), n.decalage); err != nil {
			return echec(w, r, s, d, err)
		}
		switch r.FormValue("heure") { // minute du début ou de la fin : leur heure exacte
		case valeurSaisie(n.debut, n.decalage):
			e.HeureAcquisition = n.debut
		case valeurSaisie(*n.fin, n.decalage):
			e.HeureAcquisition = *n.fin
		}
		if n.masque(e.HeureAcquisition) {
			return echec(w, r, s, d, errInvalide("Choisissez une heure entre le début et la fin de la navigation."))
		}
		if _, _, err := a.envoyerEvenement(r.Context(), s.utilisateur, id, e); err != nil {
			return echec(w, r, s, d, err)
		}
		if e.Fichier != nil {
			if err := a.deposerFichier(r.Context(), s.utilisateur, e.ID, e.Fichier.TypeMedia, donnees); err != nil {
				return err
			}
		}
		http.Redirect(w, r, page(id, "ajoute")+"#evenement-"+e.ID, http.StatusSeeOther)
		return nil
	}))
}

func ptr(s string) *string { return &s }

// nouvelUUID : identifiant aléatoire (version 4) d'un événement créé par le
// serveur, comme ceux que tire le téléphone (08-architecture.md §5).
func nouvelUUID() string {
	b := octetsAleatoires(16)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b)
	return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32]
}
