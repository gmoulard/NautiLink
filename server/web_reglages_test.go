package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
)

// TestNormaliserCodeMeteo : RG-ADM-08 : chaîne du portail, avec ou sans
// « Basic », ou « identifiant:secret » encodé par le serveur.
func TestNormaliserCodeMeteo(t *testing.T) {
	for _, c := range []struct{ entree, attendu string }{
		{"aWQ6c2VjcmV0", "aWQ6c2VjcmV0"},
		{"  Basic aWQ6c2VjcmV0\n", "aWQ6c2VjcmV0"},
		{"basic aWQ6c2VjcmV0", "aWQ6c2VjcmV0"},
		{"id:secret", "aWQ6c2VjcmV0"},
	} {
		if v, err := normaliserCodeMeteo(c.entree); err != nil || v != c.attendu {
			t.Errorf("%q : %q, %v", c.entree, v, err)
		}
	}
	for _, v := range []string{"", "pas du base64 !", "c2VjcmV0", ":secret", "id:", "a b:c", strings.Repeat("a", 4001) + ":b"} {
		if _, err := normaliserCodeMeteo(v); err == nil {
			t.Errorf("%q accepté", v)
		}
	}
}

// TestCodeMeteoPrioritaire : le code de l'espace administrateur l'emporte
// sur la variable ; un nouveau code fait redemander un jeton ; un code
// refusé donne errCodeRefuse.
func TestCodeMeteoPrioritaire(t *testing.T) {
	f := &fauxMeteoFrance{}
	m := meteoEssai(t, f)
	m.variable = "ZmF1eDpjb2Rl" // faux:code, refusé par le faux Météo-France
	if _, err := m.obtenirJeton(t.Context(), false); err == nil || !strings.Contains(err.Error(), errCodeRefuse.Error()) {
		t.Fatalf("code refusé : %v", err)
	}
	m.poserReglage("aWQ6c2VjcmV0")
	if j, err := m.obtenirJeton(t.Context(), false); err != nil || j != "jeton1" {
		t.Fatalf("code de l'écran : %q %v", j, err)
	}
	if j, _ := m.obtenirJeton(t.Context(), false); j != "jeton1" {
		t.Fatalf("jeton non gardé : %q", j)
	}
	m.poserReglage("")
	if m.identifiant() != "ZmF1eDpjb2Rl" {
		t.Fatal("retour à la variable")
	}
	if _, err := m.obtenirJeton(t.Context(), false); err == nil {
		t.Fatal("jeton de l'ancien code réutilisé")
	}
}

// TestReglagesMeteoAdmin : avec PostgreSQL : TS-ADM-07 : poser, vérifier et
// retirer le code dans l'espace administrateur ; code refusé non enregistré ;
// jamais réaffiché ni tracé.
func TestReglagesMeteoAdmin(t *testing.T) {
	e := nouvelEssai(t)
	e.a.cfg.Admins = []string{"admin@exemple.org"}
	e.a.cfg.MeteoFrance = ""
	f := &fauxMeteoFrance{}
	e.a.meteo = meteoEssai(t, f)
	e.a.meteo.variable = ""
	e.h = e.a.routeur()
	e.compte("admin@exemple.org", "Admin")
	e.confirmerEmail("admin@exemple.org")
	n := e.navigateur()
	if rec := n.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "admin@exemple.org", "motdepasse": "motdepasse"}); rec.Code != http.StatusSeeOther {
		t.Fatalf("connexion : %d", rec.Code)
	}
	if rec := n.envoyer("GET", "/nautilink/admin/reglages", nil); rec.Code != 200 || !strings.Contains(rec.Body.String(), "la météo n'est pas relevée") {
		t.Fatalf("page sans code : %d %s", rec.Code, rec.Body.String())
	}
	if rec := n.envoyer("GET", "/nautilink/admin/", nil); !strings.Contains(rec.Body.String(), `href="/nautilink/admin/reglages">Réglages</a>`) {
		t.Fatal("menu sans « Réglages »")
	}

	// code refusé par Météo-France : rien d'enregistré
	if rec := n.envoyer("POST", "/nautilink/admin/reglages/meteofrance", map[string]string{"code": "faux:code"}); rec.Code != http.StatusUnprocessableEntity || !strings.Contains(rec.Body.String(), "refuse ce code") {
		t.Fatalf("code refusé : %d", rec.Code)
	}
	if e.compter("SELECT count(*) FROM reglages") != 0 || e.a.meteo.actif() {
		t.Fatal("code refusé enregistré")
	}
	// code accepté
	rec := n.envoyer("POST", "/nautilink/admin/reglages/meteofrance", map[string]string{"code": "Basic aWQ6c2VjcmV0"})
	if rec.Code != http.StatusSeeOther || !strings.Contains(rec.Header().Get("Location"), "ok=meteo-accepte") {
		t.Fatalf("code accepté : %d %q", rec.Code, rec.Header().Get("Location"))
	}
	if !e.a.meteo.actif() || e.a.meteo.identifiant() != "aWQ6c2VjcmV0" {
		t.Fatal("code non mis en service")
	}
	page := n.envoyer("GET", "/nautilink/admin/reglages", nil).Body.String()
	if !strings.Contains(page, "Posé sur cet écran") || !strings.Contains(page, "admin@exemple.org") || strings.Contains(page, "aWQ6c2VjcmV0") {
		t.Fatalf("page avec code : %s", page)
	}
	if e.compter("SELECT count(*) FROM journal_admin WHERE ressource = 'reglages' AND action = 'modification'") != 1 ||
		e.compter("SELECT count(*) FROM journal_admin WHERE details::text LIKE '%aWQ6%'") != 0 {
		t.Fatal("journal : modification absente ou code écrit")
	}
	// relu au passage de la tâche de relevé (après un redémarrage du serveur)
	e.a.meteo.poserReglage("")
	if err := e.a.chargerCodeMeteo(t.Context()); err != nil || e.a.meteo.identifiant() != "aWQ6c2VjcmV0" {
		t.Fatalf("code relu : %v", err)
	}
	// vérification
	if rec := n.envoyer("POST", "/nautilink/admin/reglages/meteofrance/verification", nil); rec.Code != http.StatusSeeOther || !strings.Contains(rec.Header().Get("Location"), "ok=meteo-verifie") {
		t.Fatalf("vérification : %d", rec.Code)
	}
	// Météo-France injoignable : enregistré sans vérification
	f.refuser = true
	if rec := n.envoyer("POST", "/nautilink/admin/reglages/meteofrance", map[string]string{"code": "id:secret"}); !strings.Contains(rec.Header().Get("Location"), "ok=meteo-non-verifie") {
		t.Fatalf("sans réponse : %d %q", rec.Code, rec.Header().Get("Location"))
	}
	f.refuser = false
	// retrait : retour à la variable
	e.a.cfg.MeteoFrance, e.a.meteo.variable = "dmFyOmlhYmxl", "dmFyOmlhYmxl"
	if rec := n.envoyer("POST", "/nautilink/admin/reglages/meteofrance/suppression", nil); rec.Code != http.StatusSeeOther {
		t.Fatalf("retrait : %d", rec.Code)
	}
	if e.compter("SELECT count(*) FROM reglages") != 0 || e.a.meteo.identifiant() != "dmFyOmlhYmxl" {
		t.Fatal("retrait : code gardé")
	}
	if page := n.envoyer("GET", "/nautilink/admin/reglages", nil).Body.String(); !strings.Contains(page, "Celui de la variable NAUTILINK_METEOFRANCE") {
		t.Fatalf("page après retrait : %s", page)
	}
	// réservé à l'espace administrateur
	if rec := e.navigateur().envoyer("POST", "/nautilink/admin/reglages/meteofrance", map[string]string{"code": "id:secret"}); rec.Code != http.StatusSeeOther || rec.Header().Get("Location") != "/nautilink/admin/connexion" {
		t.Fatalf("sans session : %d", rec.Code)
	}
}

// jwtEssai : clé d'API d'essai (JWT non signé) expirant à fin.
func jwtEssai(typ string, fin time.Time) string {
	e := base64.RawURLEncoding.EncodeToString([]byte(`{"typ":"` + typ + `","alg":"RS256"}`))
	c := base64.RawURLEncoding.EncodeToString([]byte(fmt.Sprintf(`{"sub":"nautilink","exp":%d}`, fin.Unix())))
	return e + "." + c + ".c2lnbmF0dXJl"
}

// TestCleAPIMeteo : clé d'API du portail collée sans en-tête : reconnue,
// envoyée avec l'en-tête « apikey » (ou « Bearer » si c'est celui qui
// marche), sans passer par /token ; jeton d'une heure et clé expirée refusés.
func TestCleAPIMeteo(t *testing.T) {
	cle := jwtEssai("JWT", time.Now().Add(365*24*time.Hour))
	for _, v := range []string{cle, "apikey: " + cle, "Bearer " + cle, "  " + cle + "\n"} {
		if n, err := normaliserCodeMeteo(v); err != nil || n != cle {
			t.Errorf("%q : %q %v", v[:10], n, err)
		}
	}
	if _, err := normaliserCodeMeteo(jwtEssai("at+jwt", time.Now().Add(time.Hour))); err == nil || !strings.Contains(err.Error(), "une heure") {
		t.Errorf("jeton d'une heure : %v", err)
	}
	if _, err := normaliserCodeMeteo(jwtEssai("JWT", time.Now().Add(-time.Hour))); err == nil || !strings.Contains(err.Error(), "expiré") {
		t.Errorf("clé expirée : %v", err)
	}
	if !finJWT(cle).After(time.Now().Add(364 * 24 * time.Hour)) {
		t.Error("date de fin de la clé")
	}

	for _, entete := range []string{"", "Authorization"} {
		f := &fauxMeteoFrance{cle: cle, enteteCle: entete}
		a := &app{meteo: meteoEssai(t, f)}
		a.meteo.variable = ""
		code, err := a.verifierCodeMeteo(t.Context(), cle)
		attendu := map[string]string{"": "apikey ", "Authorization": "Bearer "}[entete] + cle
		if err != nil || code != attendu {
			t.Fatalf("en-tête %q : %q %v", entete, code, err)
		}
		a.meteo.poserReglage(code)
		if _, err := a.meteo.obtenir(t.Context(), a.meteo.vaguesURL+"0.025/packages/SP1/productMFWAM?format=grib2&time=001H", 10<<20); err != nil {
			t.Fatalf("appel avec la clé (%q) : %v", entete, err)
		}
		if f.jetons != 0 {
			t.Errorf("clé d'API : /token appelé")
		}
	}
	f := &fauxMeteoFrance{cle: "autre"}
	a := &app{meteo: meteoEssai(t, f)}
	if _, err := a.verifierCodeMeteo(t.Context(), cle); !errors.Is(err, errCodeRefuse) {
		t.Fatalf("clé refusée : %v", err)
	}
}
