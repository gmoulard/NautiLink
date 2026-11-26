package main

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Trace au navigateur (RG-NOT-06, D-159) : un e-mail pour chaque élément
// reçu de sa navigation, positions automatiques comprises, puis un
// récapitulatif avec tout le journal à la fin. Ne se désactive pas ; langue
// du navigateur (RG-PRM-04).

func nomTypeTrace(l, typ string) string {
	switch typ {
	case "debut":
		return enLangue(l, "Début de navigation", "Trip start")
	case "position_automatique":
		return enLangue(l, "Position automatique", "Automatic position")
	case "position_manuelle":
		return enLangue(l, "Position envoyée", "Position sent")
	case "note", "ajout":
		return enLangue(l, "Note", "Note")
	case "photo":
		return enLangue(l, "Photo", "Photo")
	case "note_vocale":
		return enLangue(l, "Note vocale", "Voice note")
	case "sos":
		return "SOS"
	case "fin":
		return enLangue(l, "Fin de navigation", "Trip end")
	}
	return typ
}

// ligneTrace : une ligne du journal, avec l'heure, la position ou « GPS non
// disponible », le lieu et le texte.
func ligneTrace(l, typ string, h time.Time, decalage *int, lat, lon *float64, lieu, texte *string) string {
	var s strings.Builder
	s.WriteString(heureEnvoyee(h, decalage, true) + " · " + nomTypeTrace(l, typ)) // RG-PRM-07
	switch {
	case lat != nil && lon != nil:
		fmt.Fprintf(&s, " · %.5f, %.5f (https://maps.google.com/?q=%.5f,%.5f)", *lat, *lon, *lat, *lon)
	case typ == "debut" || typ == "position_automatique" || typ == "position_manuelle" || typ == "fin":
		s.WriteString(" · " + enLangue(l, "GPS non disponible", "GPS unavailable"))
	}
	if lieu != nil && *lieu != "" {
		s.WriteString(" · " + *lieu)
	}
	if texte != nil && *texte != "" {
		s.WriteString("\n   " + *texte)
	}
	return s.String()
}

type infosTrace struct {
	email, langue, nom, bateau string
	decalage                   *int
}

func (a *app) infosTrace(ctx context.Context, navigation string) (infosTrace, error) {
	var i infosTrace
	err := a.b.pool.QueryRow(ctx, `SELECT u.email, u.langue, n.nom, b.nom, n.decalage_minutes FROM navigations n
		JOIN utilisateurs u ON u.id = n.navigateur_id JOIN bateaux b ON b.id = n.bateau_id WHERE n.id = $1`, navigation).
		Scan(&i.email, &i.langue, &i.nom, &i.bateau, &i.decalage)
	return i, err
}

func (a *app) lienNavigation(navigation string) string {
	if a.cfg.AdressePublique == "" {
		return ""
	}
	return a.cfg.AdressePublique + "/navigations/" + navigation
}

// traceEvenement : e-mail au navigateur pour un élément reçu (début,
// position, note, photo, note vocale).
func (a *app) traceEvenement(ctx context.Context, navigation string, e evenementJSON) {
	i, err := a.infosTrace(ctx, navigation)
	if err != nil || i.email == "" {
		if err != nil {
			log.Printf("trace %s : %v", navigation, err)
		}
		return
	}
	var lat, lon *float64
	if e.Position != nil {
		lat, lon = &e.Position.Latitude, &e.Position.Longitude
	}
	l := i.langue
	var s strings.Builder
	s.WriteString(enLangue(l, "Trace de votre navigation « ", "Trace of your trip “") + i.nom + enLangue(l, " » (", "” (") + i.bateau + ") :\n\n")
	s.WriteString(ligneTrace(l, e.Type, e.HeureAcquisition, i.decalage, lat, lon, e.Lieu, e.Texte) + "\n")
	if lien := a.lienNavigation(navigation); lien != "" {
		s.WriteString("\n" + enLangue(l, "Page de la navigation : ", "Trip page: ") + lien + "\n")
	}
	s.WriteString("\nNautiLink — " + enLangue(l, "Version bêta", "Beta version") + "\n")
	a.courriel(i.email, "NautiLink — "+nomTypeTrace(l, e.Type)+" · "+i.nom, s.String())
}

// recapitulatifNavigation : à la fin de la navigation, e-mail au navigateur
// avec tout le journal de bord, dans l'ordre de l'heure d'acquisition.
func (a *app) recapitulatifNavigation(ctx context.Context, navigation string) {
	i, err := a.infosTrace(ctx, navigation)
	if err != nil || i.email == "" {
		if err != nil {
			log.Printf("récapitulatif %s : %v", navigation, err)
		}
		return
	}
	lignes, err := a.b.pool.Query(ctx, `SELECT type, heure_acquisition, latitude, longitude, lieu, texte FROM evenements
		WHERE navigation_id = $1 AND supprime_le IS NULL ORDER BY heure_acquisition, numero_ordre NULLS LAST`, navigation)
	if err != nil {
		log.Printf("récapitulatif %s : %v", navigation, err)
		return
	}
	l := i.langue
	journal, err := pgx.CollectRows(lignes, func(r pgx.CollectableRow) (string, error) {
		var typ string
		var h time.Time
		var lat, lon *float64
		var lieu, texte *string
		if err := r.Scan(&typ, &h, &lat, &lon, &lieu, &texte); err != nil {
			return "", err
		}
		return ligneTrace(l, typ, h, i.decalage, lat, lon, lieu, texte), nil
	})
	if err != nil {
		log.Printf("récapitulatif %s : %v", navigation, err)
		return
	}
	var s strings.Builder
	s.WriteString(enLangue(l, "Journal de bord de votre navigation « ", "Logbook of your trip “") + i.nom + enLangue(l, " » (", "” (") + i.bateau + ") :\n\n")
	for _, x := range journal {
		s.WriteString(x + "\n")
	}
	if lien := a.lienNavigation(navigation); lien != "" {
		s.WriteString("\n" + enLangue(l, "Page de la navigation : ", "Trip page: ") + lien + "\n")
	}
	s.WriteString("\nNautiLink — " + enLangue(l, "Version bêta", "Beta version") + "\n")
	a.courriel(i.email, enLangue(l, "NautiLink — Journal de bord · ", "NautiLink — Logbook · ")+i.nom, s.String())
}
