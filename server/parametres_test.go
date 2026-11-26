package main

import (
	"strings"
	"testing"
)

func TestLibelleFrequence(t *testing.T) {
	for m, attendu := range map[int]string{15: "15 minutes", 60: "1 heure", 360: "6 heures", 1440: "1 jour", 14400: "10 jours"} {
		if got := libelleFrequence(m); got != attendu {
			t.Errorf("%d : %q", m, got)
		}
	}
}

func TestParametres(t *testing.T) {
	e := nouvelEssai(t)
	j := e.compte("nav@exemple.org", "Navigateur")
	// Nouveau compte : SMS activés, tous les types cochés, photo en MMS,
	// 1 heure (RG-PRM-06, D-148, TS-PRM-06).
	_, p0 := e.appel("GET", "/parametres", j, nil)
	if p0["smsActifs"] != true || p0["photoEnMms"] != true || p0["frequenceParDefaut"] != float64(60) || p0["version"].(float64) != 0 {
		t.Fatalf("paramètres initiaux : %v", p0)
	}
	for nom, v := range p0["smsParType"].(map[string]any) {
		if v != true {
			t.Fatalf("type %s non coché pour un nouveau compte : %v", nom, p0)
		}
	}
	if code, _ := e.appel("PATCH", "/parametres", j, map[string]any{"frequenceParDefaut": 45}); code != 422 {
		t.Fatalf("fréquence hors liste : %d", code)
	}
	// Modification sur le Web, puis sur le téléphone (hors connexion, reçue ensuite) :
	// champ par champ, la dernière reçue l'emporte (RG-COM-04).
	web := e.navigateur()
	web.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "nav@exemple.org", "motdepasse": "motdepasse"})
	rec := web.envoyer("POST", "/nautilink/parametres", map[string]string{"smsActifs": "on", "debut": "on", "fin": "on",
		"positionsAutomatiques": "on", "frequenceParDefaut": "60"})
	if rec.Code != 303 {
		t.Fatalf("Web : %d %s", rec.Code, rec.Body.String())
	}
	// Le téléphone relit au lancement : il voit la modification du Web (RG-PRM-02).
	_, p := e.appel("GET", "/parametres", j, nil)
	types := p["smsParType"].(map[string]any)
	if p["smsActifs"] != true || p["frequenceParDefaut"].(float64) != 60 || types["debut"] != true || types["photos"] != false || p["version"].(float64) != 1 {
		t.Fatalf("lu par le téléphone : %v", p)
	}
	_, p = e.appel("PATCH", "/parametres", j, map[string]any{"frequenceParDefaut": 30, "smsParType": map[string]bool{"photos": true}})
	types = p["smsParType"].(map[string]any)
	if p["frequenceParDefaut"].(float64) != 30 || types["photos"] != true || types["debut"] != true || p["smsActifs"] != true {
		t.Fatalf("modification du téléphone : %v", p)
	}
	// Le Web voit la modification du téléphone.
	page := web.envoyer("GET", "/nautilink/parametres", nil).Body.String()
	if !strings.Contains(page, `value="30" selected`) || !strings.Contains(page, `name="photos" checked`) {
		t.Fatalf("page Web : %s", page)
	}
	if rec := web.envoyer("POST", "/nautilink/parametres", map[string]string{"frequenceParDefaut": "abc"}); rec.Code != 422 {
		t.Fatalf("fréquence illisible : %d", rec.Code)
	}
	// Chaque compte a ses paramètres.
	autre := e.compte("autre@exemple.org", "Autre")
	if _, p := e.appel("GET", "/parametres", autre, nil); p["frequenceParDefaut"] != float64(60) {
		t.Fatal("paramètres partagés entre comptes")
	}
	// Compte créé avant RG-PRM-06, jamais réglé : inchangé (null).
	if _, err := e.a.b.pool.Exec(t.Context(), "DELETE FROM parametres WHERE utilisateur_id = $1", e.id(autre)); err != nil {
		t.Fatal(err)
	}
	if _, p := e.appel("GET", "/parametres", autre, nil); p["smsActifs"] != nil || p["frequenceParDefaut"] != nil {
		t.Fatalf("compte existant : %v", p)
	}
}
