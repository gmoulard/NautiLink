package main

import (
	"strings"
	"testing"
	"time"
)

// TestRenduAlertesAssistance : pages « Alertes SOS » (RG-SOS-12, RG-SOS-13)
// et « Assistance » (RG-COM-09, RG-CPT-07, RG-SOS-22), sans base.
func TestRenduAlertesAssistance(t *testing.T) {
	nav, probleme, personnes := "11111111-0000-4000-8000-000000000001", "Voie d'eau", 3
	l := []ligneHistoriqueSos{
		{A: alerteSosJSON{NavigationID: &nav, ProblemeRencontre: &probleme, PersonnesABord: &personnes, EmailsEnvoyesA: []string{"lea@exemple.org"}},
			Heure: "2026-11-20 10:15 (09:15 UTC)", Bateau: "Alizé", Mienne: true, Nature: "position actuelle",
			Position: "47,7123 N, 3,3679 O, 2026-11-20 10:15 (09:15 UTC)",
			Sms:      []ligneSms{{Telephone: "+33612345678", Statut: "livraison confirmée"}, {Telephone: "+33612345678", Statut: "échec", Second: true}}},
		{A: alerteSosJSON{EmailsEnvoyesA: []string{}}, Heure: "2026-11-21 08:00 UTC", Bateau: "Mistral", Navigateur: "Paul",
			Nature: "GPS indisponible, aucune position connue"},
	}
	page := rendu(t, "alertes.html", &donneesPage{Base: "/nautilink", Connecte: true, D: l})
	for _, attendu := range []string{"2026-11-20 10:15 (09:15 UTC) · Alizé", `href="/nautilink/navigations/` + nav + `"`, "Voie d&#39;eau",
		"33612345678 : livraison confirmée", "(second SMS) : échec", "lea@exemple.org", "alerte de Paul", "hors navigation",
		"GPS indisponible, aucune position connue", `href="/nautilink/alertes-sos">Alertes SOS</a>`, `href="/nautilink/assistance">Assistance</a>`} {
		if !strings.Contains(page, attendu) {
			t.Errorf("alertes : %q absent", attendu)
		}
	}
	if !strings.Contains(rendu(t, "alertes.html", &donneesPage{Connecte: true, D: []ligneHistoriqueSos{}}), "Aucune alerte SOS.") {
		t.Error("historique vide")
	}
	page = rendu(t, "assistance.html", &donneesPage{Base: "/nautilink", Connecte: true, Avertissement: adresseAvertissement,
		D: donneesAssistance{Equipe: adresseEquipe, Memo: adresseMemo, Profil: profilJSON{AvertissementVersionAcceptee: "2026-11-24"},
			AccepteLe: "24 novembre 2026"}})
	for _, attendu := range []string{"Écrire à l'équipe NautiLink", adresseEquipe, adresseAvertissement, "acceptée le 24 novembre 2026",
		"Mémo sécurité en mer", adresseMemo} {
		if !strings.Contains(page, attendu) {
			t.Errorf("assistance : %q absent", attendu)
		}
	}
}

// TestPagesAlertesAssistance : avec PostgreSQL : TS-SOS-19 sur le Web ; le
// ami de périmètre navigateur voit l'alerte (RG-SOS-20), un autre compte
// non.
func TestPagesAlertesAssistance(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, _ := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	h := time.Date(2026, 11, 20, 10, 15, 0, 0, time.FixedZone("", 3600))
	if code, r := e.appel("PUT", "/alertes-sos/"+uuid(t), nav, alerteSos(bateau, nil, h, true)); code != 201 {
		t.Fatalf("alerte : %d %v", code, r)
	}
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	e.compte("autre@exemple.org", "Autre")

	page := e.webConnecte("nav@exemple.org").envoyer("GET", "/nautilink/alertes-sos", nil).Body.String()
	for _, attendu := range []string{"2026-11-20 10:15 (09:15 UTC) · Alizé", "Voie d&#39;eau", "hors navigation", "position actuelle"} {
		if !strings.Contains(page, attendu) {
			t.Fatalf("historique du navigateur sans %q : %s", attendu, page)
		}
	}
	if page := e.webConnecte("lea@exemple.org").envoyer("GET", "/nautilink/alertes-sos", nil).Body.String(); !strings.Contains(page, "alerte de Navigateur") {
		t.Fatalf("historique de l'ami : %s", page)
	}
	if page := e.webConnecte("autre@exemple.org").envoyer("GET", "/nautilink/alertes-sos", nil).Body.String(); !strings.Contains(page, "Aucune alerte SOS.") {
		t.Fatalf("historique d'un autre compte : %s", page)
	}
	page = e.webConnecte("nav@exemple.org").envoyer("GET", "/nautilink/assistance", nil).Body.String()
	if !strings.Contains(page, adresseEquipe) || !strings.Contains(page, "Version du "+versionAvertissement) {
		t.Fatalf("assistance : %s", page)
	}
}
