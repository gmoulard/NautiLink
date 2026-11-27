package main

import (
	"context"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
)

// Export PDF d'une navigation (TODO-6.4, RG-NAV-19) : par son navigateur et
// par ses amis (RG-PAR-08), depuis la page de la navigation. Le PDF
// reprend les informations (RG-NAV-16, RG-NAV-27), la fiche du bateau, les
// amis (RG-PAR-08, D-176), la carte sur le fond OpenStreetMap et OpenSeaMap
// avec sa mention (RG-NAV-29, dalles.go ; fond uni si les dalles ne viennent
// pas) avec départ, arrivée, événements et alertes SOS (RG-NAV-31), les
// alertes SOS et le journal de bord chronologique (RG-JRN-03) avec ses
// photos ; une note vocale y est signalée, elle s'écoute sur l'Application
// web (RG-JRN-09). En tête, le logo NautiLink ; en bas de chaque page, le
// pied de page des écrans avec ses liens actifs (D-180, RG-WEB-11).

var (
	couleurAction = [3]int{14, 107, 168}
	couleursPoint = map[string][3]int{"depart": {19, 166, 173}, "arrivee": {14, 42, 71}, "derniere": {14, 42, 71},
		"evenement": {242, 193, 78}, "incident": {232, 131, 58}, "sos": {217, 67, 67}}
)

// logoPDF : logo NautiLink de l'en-tête des écrans, en JPEG sur blanc.
var logoPDF = sync.OnceValue(func() []byte {
	png, err := fichiersWeb.ReadFile("web/static/logo-nautilink.png")
	if err != nil {
		return nil
	}
	j, err := jpegSurBlanc(png)
	if err != nil {
		return nil
	}
	return j
})

const (
	adresseOSMCopyright = "https://www.openstreetmap.org/copyright"
	adresseOpenSeaMap   = "https://www.openseamap.org"
)

// piedPDF : pied de page des écrans (cadre.html), liens actifs, et numéro
// de la page.
func piedPDF(v construction) func(doc *docPDF, p int) {
	return func(doc *docPDF, p int) {
		commit := morceau{texte: v.CommitCourt()}
		if v.Commit != "" {
			commit.adresse = v.Depot() + "/commit/" + v.Commit
		}
		doc.ligneLiee(-1, hauteurA4-30, 7.5, []morceau{{texte: "NautiLink · "}, {"Version bêta", adresseAvertissement},
			{texte: " · "}, {"Mémo sécurité en mer", v.Memo()}, {texte: " · page " + strconv.Itoa(p)}})
		doc.ligneLiee(-1, hauteurA4-19, 7.5, []morceau{{texte: "Tous droits réservés · "}, {"NautiLink", v.Site()},
			{texte: " · V" + v.Numero + " · build " + v.Build + " · commit "}, commit})
	}
}

// exportPDF : le document, avec les photos du journal déjà lues
// (identifiant de l'événement → JPEG) ; fond : image JPEG du fond de la
// carte (nil : fond uni).
func exportPDF(d donneesNavigation, evts []evenementJSON, photos map[string][]byte, fond func(*carte) []byte, v construction) []byte {
	n := d.N
	doc := nouveauPDF(piedPDF(v))
	// En-tête : logo, nom et signature, comme les écrans.
	if logo := logoPDF(); logo != nil {
		if h, err := doc.image(logo, margePDF, doc.y, 44, 44); err == nil {
			doc.lien(margePDF, doc.y, 44, h, v.Site())
		}
	}
	doc.texte(margePDF+54, doc.y+22, 20, true, "NautiLink")
	doc.texte(margePDF+54, doc.y+38, 9.5, false, "Your sea, your safety, your story.")
	doc.y += 44
	doc.espace(14)
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
	ligne("Chef de bord", n.ChefDeBord)
	ligne("Bateau", n.Bateau.Nom)
	ligne("Début", d.L.Depart)
	ligne("Fin", d.L.Fin)
	ligne("Lieu de départ", d.L.LieuDepart)
	ligne("Lieu d'arrivée", d.L.LieuArrivee)
	ligne("Météo au départ", d.L.MeteoDepart)
	ligne("Météo à l'arrivée", d.L.MeteoArrivee)
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
	titre("Amis")
	ligne("Amis", noms(append(slices.Clone(n.Suiveurs), n.ContactsSos...))) // D-176

	const largeurCarte, hauteurCarte = largeurA4 - 2*margePDF, 300.0
	doc.besoin(hauteurCarte + 80) // titre et carte sur la même page
	titre("Carte")
	if c := carteDe(evts, d.EnCours, n.decalage, largeurCarte, hauteurCarte, true); c != nil {
		doc.besoin(hauteurCarte + 40)
		x0, y0 := margePDF, doc.y+6
		doc.rectangle(x0, y0, largeurCarte, hauteurCarte, [3]int{170, 211, 223})
		var image []byte
		if fond != nil {
			image = fond(c)
		}
		if image != nil {
			_, _ = doc.image(image, x0, y0, largeurCarte, hauteurCarte)
		}
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
		doc.paragraphe("Bleu clair : départ · bleu foncé : arrivée ou dernière position · jaune : note, photo ou note vocale · orange : incident ou avarie · rouge : alerte SOS.", 8, false, 0)
		doc.besoin(12)
		doc.y += 11
		if image != nil {
			doc.ligneLiee(margePDF, doc.y, 8, []morceau{{texte: "Fond de carte © "}, {"les contributeurs d'OpenStreetMap", adresseOSMCopyright},
				{texte: " · balisage © "}, {"OpenSeaMap", adresseOpenSeaMap}})
		} else {
			doc.texte(margePDF, doc.y, 8, false, "Fond de carte indisponible pour l'instant : la carte complète est sur l'Application web.")
		}
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
		doc := exportPDF(nav, evts, photos, func(c *carte) []byte { return a.dalles.composer(r.Context(), c) }, constructionServeur())
		w.Header().Set("Content-Type", "application/pdf")
		w.Header().Set("Content-Disposition", `attachment; filename="navigation-`+n.debut.In(zoneDe(n.decalage)).Format("2006-01-02")+`.pdf"`)
		w.Header().Set("Cache-Control", "private, no-store")
		w.Header().Set("Content-Length", strconv.Itoa(len(doc)))
		_, _ = w.Write(doc)
		return nil
	}))
}
