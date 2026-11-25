package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Essais avec PostgreSQL : base désignée par NAUTILINK_BASE_TEST (vidée à
// chaque essai, jamais une base réelle), par exemple celle de
// compose.test.yaml ou le service PostgreSQL du workflow « Serveur ».
// Sans cette variable, ces essais sont sautés.

type courrierEssai struct {
	mu    sync.Mutex
	recus []struct{ A, Sujet, Texte string }
}

func (c *courrierEssai) dernier(t *testing.T, a string) string {
	t.Helper()
	c.mu.Lock()
	defer c.mu.Unlock()
	for i := len(c.recus) - 1; i >= 0; i-- {
		if c.recus[i].A == a {
			return c.recus[i].Texte
		}
	}
	t.Fatalf("aucun e-mail pour %s", a)
	return ""
}

func (c *courrierEssai) nombre() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.recus)
}

type essai struct {
	t        *testing.T
	a        *app
	h        http.Handler
	courrier *courrierEssai
}

func nouvelEssai(t *testing.T) *essai {
	t.Helper()
	adresse := os.Getenv("NAUTILINK_BASE_TEST")
	if adresse == "" {
		t.Skip("NAUTILINK_BASE_TEST absente : essai avec PostgreSQL sauté")
	}
	pool, err := pgxpool.New(t.Context(), adresse)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if _, err := pool.Exec(t.Context(), "DROP SCHEMA public CASCADE; CREATE SCHEMA public"); err != nil {
		t.Fatal(err)
	}
	if err := migrer(t.Context(), pool); err != nil {
		t.Fatal(err)
	}
	// Une seconde passe ne change rien.
	if err := migrer(t.Context(), pool); err != nil {
		t.Fatal(err)
	}
	b := &base{pool: pool}
	b.pret.Store(true)
	a := nouvelleApp(config{Chemin: "/nautilink", AdressePublique: "https://exemple.org/nautilink"}, b)
	c := &courrierEssai{}
	a.mailSynchrone = true
	a.envoyer = func(dest, sujet, texte string) error {
		c.mu.Lock()
		defer c.mu.Unlock()
		c.recus = append(c.recus, struct{ A, Sujet, Texte string }{dest, sujet, texte})
		return nil
	}
	return &essai{t: t, a: a, h: a.routeur(), courrier: c}
}

// appel : appel de l'API avec un jeton porteur ; rend le code et le corps.
func (e *essai) appel(methode, chemin, jeton string, corps any) (int, map[string]any) {
	e.t.Helper()
	code, brut := e.appelBrut(methode, chemin, jeton, corps)
	var m map[string]any
	if len(brut) > 0 && brut[0] == '{' {
		if err := json.Unmarshal(brut, &m); err != nil {
			e.t.Fatalf("%s %s : réponse illisible %q", methode, chemin, brut)
		}
	}
	return code, m
}

func (e *essai) appelBrut(methode, chemin, jeton string, corps any) (int, []byte) {
	e.t.Helper()
	var r io.Reader
	if corps != nil {
		b, _ := json.Marshal(corps)
		r = bytes.NewReader(b)
	}
	req := httptest.NewRequest(methode, "/nautilink/api/v1"+chemin, r)
	if jeton != "" {
		req.Header.Set("Authorization", "Bearer "+jeton)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

func (e *essai) liste(methode, chemin, jeton string, corps any) (int, []map[string]any) {
	e.t.Helper()
	code, brut := e.appelBrut(methode, chemin, jeton, corps)
	var l []map[string]any
	_ = json.Unmarshal(brut, &l)
	return code, l
}

// compte : crée un compte et rend son jeton d'accès.
func (e *essai) compte(email, nom string) string {
	e.t.Helper()
	code, s := e.appel("POST", "/comptes", "", map[string]string{"email": email, "motDePasse": "motdepasse",
		"nom": nom, "avertissementVersion": versionAvertissement})
	if code != http.StatusCreated {
		e.t.Fatalf("création du compte %s : %d %v", email, code, s)
	}
	return s["jetonAcces"].(string)
}

func (e *essai) id(jeton string) string {
	e.t.Helper()
	_, p := e.appel("GET", "/compte", jeton, nil)
	return p["id"].(string)
}

var reJeton = regexp.MustCompile(`jeton=([A-Za-z0-9_-]+)`)

func jetonDuTexte(t *testing.T, texte string) string {
	t.Helper()
	m := reJeton.FindStringSubmatch(texte)
	if m == nil {
		t.Fatalf("pas de lien dans %q", texte)
	}
	return m[1]
}

// navigateurWeb : client de la plateforme Web qui garde ses cookies.
type navigateurWeb struct {
	e       *essai
	cookies map[string]*http.Cookie
}

func (e *essai) navigateur() *navigateurWeb {
	return &navigateurWeb{e: e, cookies: map[string]*http.Cookie{}}
}

func (n *navigateurWeb) envoyer(methode, chemin string, formulaire map[string]string, entetes ...string) *httptest.ResponseRecorder {
	n.e.t.Helper()
	var corps io.Reader
	if formulaire != nil {
		v := url.Values{}
		for k, x := range formulaire {
			v.Set(k, x)
		}
		corps = strings.NewReader(v.Encode())
	}
	req := httptest.NewRequest(methode, chemin, corps)
	if formulaire != nil {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}
	for i := 0; i+1 < len(entetes); i += 2 {
		req.Header.Set(entetes[i], entetes[i+1])
	}
	for _, c := range n.cookies {
		req.AddCookie(c)
	}
	rec := httptest.NewRecorder()
	n.e.h.ServeHTTP(rec, req)
	for _, c := range rec.Result().Cookies() {
		if c.MaxAge < 0 {
			delete(n.cookies, c.Name)
		} else {
			n.cookies[c.Name] = c
		}
	}
	return rec
}
