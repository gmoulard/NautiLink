package main

import (
	"strings"
	"testing"
	"time"
)

// TestVueAmiWeb : avec PostgreSQL : vue de l'ami (TODO-6.6,
// RG-PAR-07, RG-PAR-08) : lecture seule ; fiche du bateau, autres amis,
// amis et export PDF visibles ; périmètre navigation limité à sa
// navigation (RG-PAR-02) ; plus rien après le retrait global (RG-PAR-06).
func TestVueAmiWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Date(2026, 11, 20, 8, 0, 0, 0, time.UTC)
	horloge(e, t0.Add(10*time.Hour))
	f1, f2 := t0.Add(time.Hour), t0.Add(3*time.Hour)
	id1, _, _ := e.naviguer(nav, bateau, tel, t0, &f1)
	id2, _, _ := e.naviguer(nav, bateau, tel, t0.Add(2*time.Hour), &f2)
	if code, r := e.appel("POST", "/contacts", nav, map[string]any{"nom": "Capitainerie", "telephone": "06 99 88 77 66", "inviter": false}); code != 201 {
		t.Fatalf("ami : %d %v", code, r)
	}
	paul := e.compte("paul@exemple.org", "Paul")
	e.suivre(nav, paul, "paul@exemple.org", "navigateur", "")
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigation", id1)
	webLea, webPaul := e.webConnecte("lea@exemple.org"), e.webConnecte("paul@exemple.org")

	page := webLea.envoyer("GET", "/nautilink/navigations/"+id1, nil).Body.String()
	for _, attendu := range []string{"Navigation de Navigateur : vous la suivez en lecture seule.", `id="titre-bateau"`, "Alizé",
		"Paul", "Léa", "Capitainerie", "Exporter en PDF"} {
		if !strings.Contains(page, attendu) {
			t.Fatalf("vue de l'ami sans %q : %s", attendu, page)
		}
	}
	for _, interdit := range []string{"Modifier la navigation", "Ajouter au journal", "/retrait", "/suppression", "Modifier ou supprimer"} {
		if strings.Contains(page, interdit) {
			t.Fatalf("vue de l'ami avec %q", interdit)
		}
	}
	if rec := webLea.envoyer("GET", "/nautilink/navigations/"+id1+"/pdf", nil); rec.Code != 200 {
		t.Fatalf("PDF de l'ami : %d", rec.Code)
	}
	if rec := webLea.envoyer("GET", "/nautilink/navigations/"+id2, nil); rec.Code != 404 {
		t.Fatalf("périmètre navigation : autre navigation vue : %d", rec.Code)
	}
	if rec := webPaul.envoyer("GET", "/nautilink/navigations/"+id2, nil); rec.Code != 200 {
		t.Fatalf("périmètre navigateur : %d", rec.Code)
	}

	// Retrait global de Paul : plus rien, tout de suite.
	_, donnes := e.liste("GET", "/acces?role=navigateur", nav, nil)
	var accesPaul string
	for _, ac := range donnes {
		if s, _ := ac["ami"].(map[string]any); s != nil && s["id"] == e.id(paul) {
			accesPaul, _ = ac["id"].(string)
		}
	}
	if accesPaul == "" {
		t.Fatalf("accès de Paul introuvable : %v", donnes)
	}
	if rec := e.webConnecte("nav@exemple.org").envoyer("POST", "/nautilink/acces/"+accesPaul+"/retrait", map[string]string{}); rec.Code != 303 {
		t.Fatalf("retrait global : %d", rec.Code)
	}
	for _, chemin := range []string{"/nautilink/navigations/" + id1, "/nautilink/navigations/" + id2, "/nautilink/navigations/" + id2 + "/pdf"} {
		if rec := webPaul.envoyer("GET", chemin, nil); rec.Code != 404 {
			t.Fatalf("après le retrait, %s : %d", chemin, rec.Code)
		}
	}
	if page := webPaul.envoyer("GET", "/nautilink/", nil).Body.String(); strings.Contains(page, id1) || strings.Contains(page, id2) {
		t.Fatal("après le retrait, navigations encore au tableau de bord")
	}
}

// TestRenduVueAmi : bandeau de lecture seule pour l'ami seulement.
func TestRenduVueAmi(t *testing.T) {
	if s := rendu(t, "navigation.html", donneesNavEssai(false, false)); !strings.Contains(s, "Navigation de Paul : vous la suivez en lecture seule.") {
		t.Error("ami : bandeau absent")
	}
	if s := rendu(t, "navigation.html", donneesNavEssai(true, false)); strings.Contains(s, "lecture seule") {
		t.Error("navigateur : bandeau de lecture seule affiché")
	}
}
