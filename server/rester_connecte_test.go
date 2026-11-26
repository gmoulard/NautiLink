package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// cookieRendu : cookie nom posé par la réponse, ou nil.
func cookieRendu(rec *httptest.ResponseRecorder, nom string) *http.Cookie {
	for _, c := range rec.Result().Cookies() {
		if c.Name == nom {
			return c
		}
	}
	return nil
}

// verifierCookie : cookie persistant d'une heure si persistant, cookie de
// session (ni Max-Age ni Expires) sinon (D-148).
func verifierCookie(t *testing.T, rec *httptest.ResponseRecorder, nom string, persistant bool, quand string) {
	t.Helper()
	c := cookieRendu(rec, nom)
	if c == nil {
		t.Fatalf("%s : cookie %s absent", quand, nom)
	}
	entete := strings.Join(rec.Result().Header.Values("Set-Cookie"), "\n")
	if persistant && (c.MaxAge != 3600 || !strings.Contains(entete, "Max-Age=3600")) {
		t.Fatalf("%s : cookie persistant d'une heure attendu : %q", quand, entete)
	}
	if !persistant && (c.MaxAge != 0 || c.RawExpires != "" || strings.Contains(entete, "Max-Age") || strings.Contains(entete, "Expires")) {
		t.Fatalf("%s : cookie de session attendu : %q", quand, entete)
	}
}

func TestResterConnecteWeb(t *testing.T) {
	e := nouvelEssai(t)
	jMobile := e.compte("paul@exemple.org", "Paul")

	// Case « Rester connecté » présente et cochée par défaut.
	n := e.navigateur()
	page := n.envoyer("GET", "/nautilink/connexion", nil).Body.String()
	if !strings.Contains(page, `name="rester" value="oui" checked`) || !strings.Contains(page, "Rester connecté") {
		t.Fatalf("case « Rester connecté » absente ou décochée : %s", page)
	}

	// Cochée : cookie persistant, prolongé à chaque page.
	rec := n.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "paul@exemple.org", "motdepasse": "motdepasse", "rester": "oui"})
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("connexion : %d", rec.Code)
	}
	verifierCookie(t, rec, nomCookie, true, "connexion cochée")
	verifierCookie(t, n.envoyer("GET", "/nautilink/compte", nil), nomCookie, true, "page, case cochée")

	// Décochée : cookie de session, y compris quand il est prolongé.
	n2 := e.navigateur()
	rec = n2.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "paul@exemple.org", "motdepasse": "motdepasse"})
	verifierCookie(t, rec, nomCookie, false, "connexion décochée")
	if rec := n2.envoyer("GET", "/nautilink/compte", nil); rec.Code != http.StatusOK {
		t.Fatalf("page, case décochée : %d", rec.Code)
	} else {
		verifierCookie(t, rec, nomCookie, false, "page, case décochée")
	}
	// Erreur de saisie : la case garde le choix de l'utilisateur.
	if page := e.navigateur().envoyer("POST", "/nautilink/connexion", map[string]string{"email": "paul@exemple.org", "motdepasse": "faux"}).Body.String(); strings.Contains(page, `value="oui" checked`) {
		t.Fatal("case recochée après une erreur alors qu'elle était décochée")
	}

	// 59 minutes sans usage : les sessions Web tiennent, la session mobile aussi.
	vieillir := func(intervalle string) {
		t.Helper()
		if _, err := e.a.b.pool.Exec(t.Context(), "UPDATE sessions SET derniere_utilisation = now() - $1::interval", intervalle); err != nil {
			t.Fatal(err)
		}
	}
	vieillir("59 minutes")
	for i, nav := range []*navigateurWeb{n, n2} {
		if rec := nav.envoyer("GET", "/nautilink/compte", nil); rec.Code != http.StatusOK {
			t.Fatalf("session Web %d après 59 minutes : %d", i, rec.Code)
		}
	}
	// 61 minutes sans usage : les sessions Web, cochée ou non, ont expiré ;
	// la session mobile tient (90 jours, RG-CPT-08).
	vieillir("61 minutes")
	for i, nav := range []*navigateurWeb{n, n2} {
		rec := nav.envoyer("GET", "/nautilink/compte", nil)
		if rec.Code != http.StatusSeeOther || !strings.HasPrefix(rec.Header().Get("Location"), "/nautilink/connexion") {
			t.Fatalf("session Web %d après 61 minutes : %d", i, rec.Code)
		}
		if nav.cookies[nomCookie] != nil {
			t.Fatalf("session Web %d : cookie non effacé", i)
		}
	}
	if code, _ := e.appel("GET", "/compte", jMobile, nil); code != http.StatusOK {
		t.Fatalf("session mobile après 61 minutes : %d", code)
	}
	vieillir("89 days")
	if code, _ := e.appel("GET", "/compte", jMobile, nil); code != http.StatusOK {
		t.Fatalf("session mobile après 89 jours : %d", code)
	}

	// Inscription sur le Web : sans case, comme la case cochée par défaut.
	rec = e.navigateur().envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Lou", "email": "lou@exemple.org",
		"motdepasse": "motdepasse", "avertissement": versionAvertissement})
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("inscription : %d %s", rec.Code, rec.Body.String())
	}
	verifierCookie(t, rec, nomCookie, true, "inscription")
}

func TestResterConnecteAdmin(t *testing.T) {
	e := nouvelEssai(t)
	e.a.cfg.Admins = []string{"admin@exemple.org"}
	e.h = e.a.routeur()
	e.compte("admin@exemple.org", "Admin")
	e.confirmerEmail("admin@exemple.org")

	n := e.navigateur()
	page := n.envoyer("GET", "/nautilink/admin/connexion", nil).Body.String()
	if !strings.Contains(page, `name="rester" value="oui" checked`) || !strings.Contains(page, "Rester connecté") {
		t.Fatalf("case « Rester connecté » absente ou décochée : %s", page)
	}
	rec := n.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "admin@exemple.org", "motdepasse": "motdepasse", "rester": "oui"})
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("connexion : %d %s", rec.Code, rec.Body.String())
	}
	verifierCookie(t, rec, nomCookieAdmin, true, "connexion cochée")
	verifierCookie(t, n.envoyer("GET", "/nautilink/admin/", nil), nomCookieAdmin, true, "page, case cochée")

	n2 := e.navigateur()
	rec = n2.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "admin@exemple.org", "motdepasse": "motdepasse"})
	verifierCookie(t, rec, nomCookieAdmin, false, "connexion décochée")
	verifierCookie(t, n2.envoyer("GET", "/nautilink/admin/", nil), nomCookieAdmin, false, "page, case décochée")

	vieillir := func(intervalle string) {
		t.Helper()
		if _, err := e.a.b.pool.Exec(t.Context(), "UPDATE sessions_admin SET derniere_utilisation = now() - $1::interval", intervalle); err != nil {
			t.Fatal(err)
		}
	}
	vieillir("59 minutes")
	for i, nav := range []*navigateurWeb{n, n2} {
		if rec := nav.envoyer("GET", "/nautilink/admin/", nil); rec.Code != http.StatusOK {
			t.Fatalf("session admin %d après 59 minutes : %d", i, rec.Code)
		}
	}
	vieillir("61 minutes")
	for i, nav := range []*navigateurWeb{n, n2} {
		if rec := nav.envoyer("GET", "/nautilink/admin/", nil); rec.Code != http.StatusSeeOther ||
			rec.Header().Get("Location") != "/nautilink/admin/connexion" {
			t.Fatalf("session admin %d après 61 minutes : %d", i, rec.Code)
		}
	}
}
