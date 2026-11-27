package main

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Exports CSV et YAML d'une navigation (TODO-6.15, D-180, RG-WEB-09) : à
// côté de « Exporter en PDF », avec les mêmes droits (navigateur et suiveurs,
// RG-NAV-19, RG-PAR-08). CSV : une ligne par événement du journal de bord,
// séparateur point-virgule et marque UTF-8 pour les tableurs ; YAML : fiche de
// la navigation (informations, bateau, suiveurs et contacts SOS par leur nom,
// comme le PDF), alertes SOS et journal. Les fichiers (photos, notes
// vocales) n'y sont que signalés.

// typeFichier : nature du fichier joint à un événement, en clair.
func typeFichier(j ligneJournal) string {
	switch {
	case j.Photo:
		return "photo"
	case j.Vocal:
		return "note vocale"
	}
	return ""
}

func texteDe(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func coordonnee(v float64) string { return strconv.FormatFloat(v, 'f', 6, 64) }

// exportCSV : une ligne par événement du journal, dans l'ordre du journal.
func exportCSV(d donneesNavigation) []byte {
	var b bytes.Buffer
	b.WriteString("\xEF\xBB\xBF")
	w := csv.NewWriter(&b)
	w.Comma = ';'
	_ = w.Write([]string{"Heure", "Heure UTC", "Type", "Latitude", "Longitude", "Lieu", "Texte", "Fichier", "En dehors des heures affichées"})
	for _, j := range d.Journal {
		lat, lon := "", ""
		if p := j.E.Position; p != nil {
			lat, lon = coordonnee(p.Latitude), coordonnee(p.Longitude)
		}
		masque := ""
		if j.Masque {
			masque = "oui"
		}
		_ = w.Write([]string{j.Heure, j.E.HeureAcquisition.UTC().Format(time.RFC3339), j.Libelle, lat, lon, j.Lieu, texteDe(j.E.Texte), typeFichier(j), masque})
	}
	w.Flush()
	return b.Bytes()
}

// yaml : document YAML écrit à la main (pas de bibliothèque) ; les textes
// sont entre guillemets, échappés comme en JSON, ce que YAML accepte.
type yaml struct {
	b bytes.Buffer
}

func chaineYAML(s string) string {
	o, _ := json.Marshal(s)
	return string(o)
}

func (y *yaml) champ(retrait int, cle, valeur string) {
	if valeur != "" {
		y.b.WriteString(strings.Repeat("  ", retrait) + cle + ": " + valeur + "\n")
	}
}

func (y *yaml) texte(retrait int, cle, valeur string) {
	if valeur != "" {
		y.champ(retrait, cle, chaineYAML(valeur))
	}
}

func (y *yaml) bloc(retrait int, cle string) {
	y.b.WriteString(strings.Repeat("  ", retrait) + cle + ":\n")
}

func heureYAML(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.UTC().Format(time.RFC3339)
}

func (y *yaml) lieu(retrait int, cle string, l *lieuJSON) {
	if l == nil || (l.Nom == nil && l.Position == nil) {
		return
	}
	y.bloc(retrait, cle)
	y.texte(retrait+1, "nom", texteDe(l.Nom))
	if l.Position != nil {
		y.champ(retrait+1, "latitude", coordonnee(l.Position.Latitude))
		y.champ(retrait+1, "longitude", coordonnee(l.Position.Longitude))
	}
}

func (y *yaml) noms(retrait int, cle string, l []personneJSON) {
	if len(l) == 0 {
		y.champ(retrait, cle, "[]")
		return
	}
	y.bloc(retrait, cle)
	for _, p := range l {
		y.b.WriteString(strings.Repeat("  ", retrait+1) + "- " + chaineYAML(p.Nom) + "\n")
	}
}

// exportYAML : fiche de la navigation, alertes SOS et journal de bord.
func exportYAML(d donneesNavigation) []byte {
	n := d.N
	y := &yaml{}
	y.b.WriteString("# Navigation NautiLink : fiche et journal de bord. Heures en UTC (ISO 8601).\n")
	y.bloc(0, "navigation")
	y.texte(1, "nom", n.Nom)
	y.texte(1, "etat", n.Etat)
	if n.Navigateur != nil {
		y.texte(1, "navigateur", n.Navigateur.Nom)
	}
	y.texte(1, "chefDeBord", n.ChefDeBord)
	y.champ(1, "debut", heureYAML(&n.Debut))
	y.champ(1, "fin", heureYAML(n.Fin))
	y.lieu(1, "lieuDepart", n.LieuDepart)
	y.lieu(1, "lieuArrivee", n.LieuArrivee)
	y.texte(1, "destination", d.Destination)
	y.champ(1, "dureeMinutes", strconv.Itoa(n.DureeMinutes))
	y.champ(1, "distanceMetres", strconv.FormatFloat(n.DistanceMetres, 'f', 0, 64))
	if n.PersonnesABord > 0 {
		y.champ(1, "personnesABord", strconv.Itoa(n.PersonnesABord))
	}
	if n.FrequenceMinutes > 0 {
		y.champ(1, "frequenceMinutes", strconv.Itoa(n.FrequenceMinutes))
	}
	y.texte(1, "meteoDepart", d.L.MeteoDepart)
	y.texte(1, "meteoArrivee", d.L.MeteoArrivee)
	if n.ClotureAutomatiqueLe != nil {
		y.champ(1, "clotureAutomatique", heureYAML(n.ClotureAutomatiqueLe))
	}
	y.bloc(1, "bateau")
	y.texte(2, "nom", n.Bateau.Nom)
	if b := n.Fiche; b != nil {
		y.texte(2, "type", b.Type)
		if b.LongueurMetres != nil {
			y.champ(2, "longueurMetres", decimal(*b.LongueurMetres, 2))
		}
		y.texte(2, "immatriculation", b.Immatriculation)
		y.texte(2, "portAttache", b.PortAttache)
	}
	y.noms(1, "suiveurs", n.Suiveurs)
	y.noms(1, "contactsSos", n.ContactsSos)

	if len(d.Alertes) == 0 {
		y.champ(0, "alertesSos", "[]")
	} else {
		y.bloc(0, "alertesSos")
		for _, al := range d.Alertes {
			y.b.WriteString("  - heure: " + al.A.HeureDeclenchement.UTC().Format(time.RFC3339) + "\n")
			if p := al.A.Position; p != nil {
				y.champ(2, "latitude", coordonnee(p.Latitude))
				y.champ(2, "longitude", coordonnee(p.Longitude))
			}
			y.texte(2, "probleme", texteDe(al.A.ProblemeRencontre))
			if al.A.PersonnesABord != nil {
				y.champ(2, "personnesABord", strconv.Itoa(*al.A.PersonnesABord))
			}
			if al.HorsNavigation {
				y.champ(2, "horsNavigation", "true")
			}
		}
	}

	if len(d.Journal) == 0 {
		y.champ(0, "journal", "[]")
	} else {
		y.bloc(0, "journal")
		for _, j := range d.Journal {
			y.b.WriteString("  - heure: " + j.E.HeureAcquisition.UTC().Format(time.RFC3339) + "\n")
			y.champ(2, "type", j.E.Type)
			y.texte(2, "libelle", j.Libelle)
			if p := j.E.Position; p != nil {
				y.champ(2, "latitude", coordonnee(p.Latitude))
				y.champ(2, "longitude", coordonnee(p.Longitude))
			}
			y.texte(2, "lieu", texteDe(j.E.Lieu))
			y.texte(2, "texte", texteDe(j.E.Texte))
			y.texte(2, "fichier", typeFichier(j))
			if j.Masque {
				y.champ(2, "horsHeuresAffichees", "true")
			}
		}
	}
	return y.b.Bytes()
}

func (a *app) routesWebExports(mux *http.ServeMux, c string) {
	export := func(extension, typeMedia string, produire func(donneesNavigation) []byte) {
		mux.HandleFunc("GET "+c+"/navigations/{id}/"+extension, a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
			nav, err := a.donneesDeLaNavigation(r.Context(), s.utilisateur, r.PathValue("id"))
			if err != nil {
				return err
			}
			doc := produire(nav)
			w.Header().Set("Content-Type", typeMedia)
			w.Header().Set("Content-Disposition", `attachment; filename="navigation-`+nav.N.Debut.In(zoneDe(nav.N.decalage)).Format("2006-01-02")+`.`+extension+`"`)
			w.Header().Set("Cache-Control", "private, no-store")
			w.Header().Set("Content-Length", strconv.Itoa(len(doc)))
			_, _ = w.Write(doc)
			return nil
		}))
	}
	export("csv", "text/csv; charset=utf-8", exportCSV)
	export("yaml", "application/yaml; charset=utf-8", exportYAML)
}
