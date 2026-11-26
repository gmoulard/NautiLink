package main

import (
	"context"
	"net/http"
	"strconv"
	"strings"
)

// Export PDF d'une navigation (TODO-6.4, RG-NAV-19) : par son navigateur et
// par ses suiveurs (RG-PAR-08), depuis la page de la navigation. Le PDF
// reprend les informations (RG-NAV-16, RG-NAV-27), la fiche du bateau, les
// suiveurs et contacts SOS (RG-PAR-08), le tracé sur un fond uni (sans les
// dalles d'OpenStreetMap : 08-architecture.md §7) avec départ, arrivée,
// événements et alertes SOS (RG-NAV-31), les alertes SOS et le journal de
// bord chronologique (RG-JRN-03) avec ses photos ; une note vocale y est
// signalée, elle s'écoute sur l'Application web (RG-JRN-09).

var (
	couleurAction = [3]int{14, 107, 168}
	couleursPoint = map[string][3]int{"depart": {19, 166, 173}, "arrivee": {14, 42, 71}, "derniere": {14, 42, 71},
		"evenement": {242, 193, 78}, "sos": {217, 67, 67}}
)

// exportPDF : le document, avec les photos du journal déjà lues
// (identifiant de l'événement → JPEG).
func exportPDF(d donneesNavigation, evts []evenementJSON, photos map[string][]byte) []byte {
	n := d.N
	doc := nouveauPDF(func(p int) string {
		return "NautiLink · " + n.Nom + " · page " + strconv.Itoa(p)
	})
	doc.paragraphe(n.Nom, 18, true, 0)
	etat := "Navigation terminée"
	if d.EnCours {
		etat = "Navigation en cours"
	} else if d.Corbeille {
		etat = "Navigation dans la corbeille"
	}
	doc.paragraphe(etat+" · journal de bord NautiLink", 9, false, 0)
	doc.espace(8)

	titre := func(s string) {
		doc.besoin(40)
		doc.espace(10)
		doc.paragraphe(s, 13, true, 0)
		doc.espace(2)
	}
	ligne := func(nom, valeur string) {
		if valeur != "" {
			doc.paragraphe(nom+" : "+valeur, 10, false, 0)
		}
	}
	titre("Informations")
	if n.Navigateur != nil {
		ligne("Navigateur", n.Navigateur.Nom)
	}
	ligne("Bateau", n.Bateau.Nom)
	ligne("Début", d.L.Depart)
	ligne("Fin", d.L.Fin)
	ligne("Lieu de départ", d.L.LieuDepart)
	ligne("Lieu d'arrivée", d.L.LieuArrivee)
	ligne("Destination", d.Destination)
	ligne("Durée", d.L.Duree)
	ligne("Distance", d.L.Distance)
	if n.PersonnesABord > 0 {
		ligne("Personnes à bord", strconv.Itoa(n.PersonnesABord))
	}
	ligne("Fréquence des positions", d.Frequence)
	if n.ClotureAutomatiqueLe != nil {
		ligne("Clôture", "automatique, quota épuisé")
	}

	if b := n.Fiche; b != nil {
		titre("Bateau")
		typ := "Bateau à moteur"
		if b.Type == "voilier" {
			typ = "Voilier"
		}
		ligne("Nom", b.Nom)
		ligne("Type", typ)
		if b.LongueurMetres != nil {
			ligne("Longueur", decimal(*b.LongueurMetres, 2)+" m")
		}
		ligne("Immatriculation", b.Immatriculation)
		ligne("Port d'attache", b.PortAttache)
	}
	noms := func(l []personneJSON) string {
		var s []string
		for _, p := range l {
			s = append(s, p.Nom)
		}
		if len(s) == 0 {
			return "aucun"
		}
		return strings.Join(s, ", ")
	}
	titre("Suiveurs et contacts SOS")
	ligne("Suiveurs", noms(n.Suiveurs))
	ligne("Contacts SOS", noms(n.ContactsSos))

	titre("Tracé")
	const largeurCarte, hauteurCarte = largeurA4 - 2*margePDF, 300.0
	if c := carteDe(evts, d.EnCours, n.decalage, largeurCarte, hauteurCarte, false); c != nil {
		doc.besoin(hauteurCarte + 30)
		x0, y0 := margePDF, doc.y+6
		doc.rectangle(x0, y0, largeurCarte, hauteurCarte, [3]int{226, 240, 247})
		var trace [][2]float64
		for _, p := range c.traceXY {
			trace = append(trace, [2]float64{x0 + p[0], y0 + p[1]})
		}
		doc.polyligne(trace, 2, couleurAction)
		for _, p := range c.Points {
			if coul, ok := couleursPoint[p.Sorte]; ok {
				doc.cercle(x0+p.X, y0+p.Y, 4.5, coul)
			}
		}
		doc.y = y0 + hauteurCarte
		doc.paragraphe("Bleu clair : départ · bleu foncé : arrivée ou dernière position · jaune : note, photo ou note vocale · rouge : alerte SOS. Fond de carte non reproduit ; la carte avec OpenStreetMap et OpenSeaMap est sur l'Application web.", 8, false, 0)
	} else {
		doc.paragraphe("Aucune position reçue.", 10, false, 0)
	}

	if len(d.Alertes) > 0 {
		titre("Alertes SOS")
		for _, al := range d.Alertes {
			s := "SOS · " + al.Heure
			if al.Lieu != "" {
				s += " · " + al.Lieu
			} else {
				s += " · position non disponible"
			}
			if al.A.ProblemeRencontre != nil {
				s += " · " + *al.A.ProblemeRencontre
			}
			if al.A.PersonnesABord != nil {
				s += " · " + strconv.Itoa(*al.A.PersonnesABord) + " à bord"
			}
			if al.HorsNavigation {
				s += " · en dehors des heures de la navigation"
			}
			doc.paragraphe(s, 10, false, 0)
		}
	}

	titre("Journal de bord")
	if len(d.Journal) == 0 {
		doc.paragraphe("Le journal est vide.", 10, false, 0)
	}
	for _, j := range d.Journal {
		doc.besoin(30)
		doc.espace(4)
		entete := j.Libelle + " · " + j.Heure
		if j.Lieu != "" {
			entete += " · " + j.Lieu
		}
		if j.Masque {
			entete += " · en dehors des heures affichées"
		}
		doc.paragraphe(entete, 10, true, 0)
		if j.E.Texte != nil {
			doc.paragraphe(*j.E.Texte, 10, false, 12)
		}
		if j.Vocal {
			s := "Note vocale"
			if j.E.Fichier.DureeSecondes != nil {
				s += " de " + strconv.Itoa(*j.E.Fichier.DureeSecondes) + " s"
			}
			doc.paragraphe(s+", à écouter sur l'Application web.", 9, false, 12)
		}
		if j.Photo {
			if jpeg, ok := photos[j.E.ID]; ok {
				doc.besoin(180)
				h, err := doc.image(jpeg, margePDF+12, doc.y+6, 240, 170)
				if err == nil {
					doc.y += h + 6
					continue
				}
			}
			doc.paragraphe("Photo non disponible.", 9, false, 12)
		}
	}
	return doc.octets()
}

// photosDuJournal : photos reçues du journal (notes vocales exclues).
func (a *app) photosDuJournal(ctx context.Context, navID string) (map[string][]byte, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT f.evenement_id::text, f.contenu FROM fichiers f JOIN evenements e ON e.id = f.evenement_id
		WHERE e.navigation_id = $1 AND e.supprime_le IS NULL AND f.type_media = 'image/jpeg'`, navID)
	if err != nil {
		return nil, err
	}
	defer lignes.Close()
	photos := map[string][]byte{}
	for lignes.Next() {
		var id string
		var b []byte
		if err := lignes.Scan(&id, &b); err != nil {
			return nil, err
		}
		photos[id] = b
	}
	return photos, lignes.Err()
}

func (a *app) routesWebPDF(mux *http.ServeMux, c string) {
	mux.HandleFunc("GET "+c+"/navigations/{id}/pdf", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		nav, err := a.donneesDeLaNavigation(r.Context(), s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		n, err := a.navigation(r.Context(), a.b.pool, nav.N.ID)
		if err != nil {
			return err
		}
		evts, _, _, err := a.journalDeBord(r.Context(), n, 0)
		if err != nil {
			return err
		}
		photos, err := a.photosDuJournal(r.Context(), n.id)
		if err != nil {
			return err
		}
		doc := exportPDF(nav, evts, photos)
		w.Header().Set("Content-Type", "application/pdf")
		w.Header().Set("Content-Disposition", `attachment; filename="navigation-`+n.debut.In(zoneDe(n.decalage)).Format("2006-01-02")+`.pdf"`)
		w.Header().Set("Cache-Control", "private, no-store")
		w.Header().Set("Content-Length", strconv.Itoa(len(doc)))
		_, _ = w.Write(doc)
		return nil
	}))
}
