package main

import (
	"strings"
	"testing"
	"time"
)

// TestRenduConduite : formulaires de conduite pour le navigateur d'une
// navigation en cours seulement (RG-WEB-01) ; bouton SOS sur la page et le
// tableau de bord (RG-SOS-01, RG-WEB-02).
func TestRenduConduite(t *testing.T) {
	enCours := donneesNavEssai(true, true)
	if s := rendu(t, "navigation.html", enCours); !strings.Contains(s, "Pendant la navigation") || !strings.Contains(s, "/sos?navigation=") ||
		!strings.Contains(s, "/conduite") || !strings.Contains(s, "Terminer la navigation") {
		t.Error("navigateur, navigation en cours : formulaires absents")
	}
	if s := rendu(t, "navigation.html", donneesNavEssai(false, true)); strings.Contains(s, "Pendant la navigation") {
		t.Error("suiveur : formulaires de conduite affichés")
	}
	if s := rendu(t, "navigation.html", donneesNavEssai(true, false)); strings.Contains(s, "Pendant la navigation") {
		t.Error("navigation terminée : formulaires de conduite affichés")
	}
	page := rendu(t, "sos.html", &donneesPage{Base: "/nautilink", Connecte: true, D: donneesPageSos{Bateaux: []bateauJSON{{ID: "b1", Nom: "Alizé"}, {ID: "b2", Nom: "Mistral"}}}})
	for _, attendu := range []string{"Envoyer un SOS ?", `name="bateauId"`, "Mistral", "Problème rencontré (facultatif)", "Confirmer le SOS", "canal 16"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("boîte du SOS : %q absent", attendu)
		}
	}
}

// TestConduiteWeb : avec PostgreSQL : TS-WEB-01, TS-WEB-02 : note, photo,
// fin et SOS depuis l'Application web, sans SMS ; refus pour un suiveur.
func TestConduiteWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Date(2026, 11, 20, 8, 0, 0, 0, time.FixedZone("", 3600))
	horloge(e, t0.Add(time.Hour))
	id, code, _ := e.naviguer(nav, bateau, tel, t0, nil)
	if code != 201 {
		t.Fatalf("démarrage : %d", code)
	}
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	web, webLea := e.webConnecte("nav@exemple.org"), e.webConnecte("lea@exemple.org")
	base := "/nautilink/navigations/" + id

	if rec := web.envoyerFichier(base+"/conduite", map[string]string{"texte": "Ris pris"}, nil); rec.Code != 303 {
		t.Fatalf("note : %d %s", rec.Code, rec.Body.String())
	}
	if rec := web.envoyerFichier(base+"/conduite", nil, jpegEssai); rec.Code != 303 {
		t.Fatalf("photo : %d %s", rec.Code, rec.Body.String())
	}
	if rec := web.envoyerFichier(base+"/conduite", nil, nil); rec.Code != 422 {
		t.Fatalf("envoi vide : %d", rec.Code)
	}
	if rec := webLea.envoyerFichier(base+"/conduite", map[string]string{"texte": "x"}, nil); rec.Code != 403 {
		t.Fatalf("note d'un suiveur : %d", rec.Code)
	}
	_, j := e.appel("GET", "/navigations/"+id+"/evenements", nav, nil)
	types := map[string]bool{}
	for _, x := range j["evenements"].([]any) {
		ev := x.(map[string]any)
		if ev["origine"] == "web" {
			types[ev["type"].(string)] = true
		}
	}
	if !types["note"] || !types["photo"] {
		t.Fatalf("journal : %v", j)
	}

	// SOS pendant la navigation : dernière position du journal, e-mail au
	// suiveur, alerte inscrite au journal (RG-WEB-02).
	if page := web.envoyer("GET", "/nautilink/sos?navigation="+id, nil).Body.String(); !strings.Contains(page, `name="navigationId" value="`+id+`"`) {
		t.Fatalf("boîte du SOS : %s", page)
	}
	n0 := e.courrier.nombre()
	if rec := web.envoyer("POST", "/nautilink/sos", map[string]string{"navigationId": id, "probleme": "Voie d'eau"}); rec.Code != 303 ||
		rec.Header().Get("Location") != "/nautilink/alertes-sos?ok=sos" {
		t.Fatalf("SOS : %d %s", rec.Code, rec.Body.String())
	}
	if e.courrier.nombre() == n0 || !strings.Contains(e.courrier.dernier(t, "lea@exemple.org"), "Voie d'eau") {
		t.Fatal("SOS : e-mail du suiveur absent")
	}
	_, l := e.liste("GET", "/alertes-sos?navigationId="+id, nav, nil)
	if len(l) != 1 || l[0]["naturePosition"] != "derniere_connue" || func() bool { s, _ := l[0]["sms"].([]any); return len(s) != 0 }() {
		t.Fatalf("alerte : %v", l)
	}
	if rec := webLea.envoyer("POST", "/nautilink/sos", map[string]string{"navigationId": id}); rec.Code != 403 {
		t.Fatalf("SOS d'un suiveur sur la navigation : %d", rec.Code)
	}

	// Fin : confirmation demandée, puis navigation terminée.
	if rec := web.envoyer("POST", base+"/fin", map[string]string{}); rec.Code != 422 {
		t.Fatalf("fin sans confirmation : %d", rec.Code)
	}
	if rec := web.envoyer("POST", base+"/fin", map[string]string{"confirmation": "on"}); rec.Code != 303 {
		t.Fatalf("fin : %d %s", rec.Code, rec.Body.String())
	}
	if _, n := e.appel("GET", "/navigations/"+id, nav, nil); n["etat"] != "terminee" {
		t.Fatalf("après la fin : %v", n)
	}
	if rec := web.envoyerFichier(base+"/conduite", map[string]string{"texte": "trop tard"}, nil); rec.Code != 409 {
		t.Fatalf("note après la fin : %d", rec.Code)
	}

	// SOS hors navigation : bateau du compte seulement.
	if rec := web.envoyer("POST", "/nautilink/sos", map[string]string{"bateauId": bateau}); rec.Code != 303 {
		t.Fatalf("SOS hors navigation : %d %s", rec.Code, rec.Body.String())
	}
	if rec := webLea.envoyer("POST", "/nautilink/sos", map[string]string{"bateauId": bateau}); rec.Code != 422 ||
		!strings.Contains(rec.Body.String(), "Choisissez l&#39;un de vos bateaux.") {
		t.Fatalf("SOS sur le bateau d'un autre : %d", rec.Code)
	}
	if page := webLea.envoyer("GET", "/nautilink/sos", nil).Body.String(); !strings.Contains(page, "Aucun bateau dans votre compte") {
		t.Fatalf("SOS sans bateau : %s", page)
	}
}
