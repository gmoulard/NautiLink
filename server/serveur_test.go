package main

import (
	"bufio"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func requete(t *testing.T, h http.Handler, chemin string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, chemin, nil))
	return rec
}

func TestNormaliserChemin(t *testing.T) {
	for entree, attendu := range map[string]string{
		"": "", "/": "", "nautilink": "/nautilink", "/nautilink/": "/nautilink", " a/b/ ": "/a/b",
	} {
		if got := normaliserChemin(entree); got != attendu {
			t.Errorf("normaliserChemin(%q) = %q, attendu %q", entree, got, attendu)
		}
	}
}

func TestPagesSousChemin(t *testing.T) {
	h := nouveauRouteur(config{Chemin: "/nautilink"}, &base{})

	if rec := requete(t, h, "/nautilink/"); rec.Code != 200 || !strings.Contains(rec.Body.String(), "Version bêta") {
		t.Fatalf("accueil : %d %q", rec.Code, rec.Body.String())
	}
	// Sans base, l'espace administrateur dit qu'il est indisponible.
	if rec := requete(t, h, "/nautilink/admin/"); rec.Code != http.StatusServiceUnavailable || !strings.Contains(rec.Body.String(), "Administration") {
		t.Fatalf("admin : %d", rec.Code)
	}
	if rec := requete(t, h, "/nautilink/static/style.css"); rec.Code != 200 {
		t.Fatalf("style : %d", rec.Code)
	}
	for _, c := range []string{"/", "/nautilink"} {
		if rec := requete(t, h, c); rec.Code != http.StatusFound || rec.Header().Get("Location") != "/nautilink/" {
			t.Fatalf("%s : %d vers %q", c, rec.Code, rec.Header().Get("Location"))
		}
	}
	if rec := requete(t, h, "/nautilink/inconnu"); rec.Code != http.StatusNotFound {
		t.Fatalf("page inconnue : %d", rec.Code)
	}
	if rec := requete(t, h, "/"); rec.Header().Get("X-Frame-Options") != "DENY" {
		t.Fatal("en-têtes de sécurité absents")
	}
}

func TestPagesALaRacine(t *testing.T) {
	h := nouveauRouteur(config{}, &base{})
	if rec := requete(t, h, "/"); rec.Code != 200 {
		t.Fatalf("accueil : %d", rec.Code)
	}
	if rec := requete(t, h, "/api/sante"); rec.Code != 200 {
		t.Fatalf("santé : %d", rec.Code)
	}
}

func TestSanteSansBase(t *testing.T) {
	h := nouveauRouteur(config{Chemin: "/nautilink"}, &base{})
	rec := requete(t, h, "/nautilink/api/sante")
	var corps map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &corps); err != nil {
		t.Fatal(err)
	}
	if rec.Code != 200 || corps["etat"] != "ok" || corps["base"] != "absente" {
		t.Fatalf("santé : %d %v", rec.Code, corps)
	}
}

func TestBaseMalReglee(t *testing.T) {
	b := ouvrirBase(t.Context(), "pas une url ::")
	if got := b.etat(t.Context()); got != "erreur" {
		t.Fatalf("état = %q, attendu erreur", got)
	}
}

// TestMailEssai : faux serveur SMTP minimal, vérifie l'enveloppe et l'en-tête.
func TestMailEssai(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	recu := make(chan string, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		r := bufio.NewReader(conn)
		ecrire := func(s string) { conn.Write([]byte(s + "\r\n")) }
		ecrire("220 essai")
		var tout strings.Builder
		donnees := false
		for {
			ligne, err := r.ReadString('\n')
			if err != nil {
				return
			}
			tout.WriteString(ligne)
			switch {
			case donnees && ligne == ".\r\n":
				donnees = false
				ecrire("250 ok")
			case donnees:
			case strings.HasPrefix(ligne, "EHLO"), strings.HasPrefix(ligne, "HELO"):
				ecrire("250 essai")
			case strings.HasPrefix(ligne, "DATA"):
				donnees = true
				ecrire("354 suite")
			case strings.HasPrefix(ligne, "QUIT"):
				ecrire("221 au revoir")
				recu <- tout.String()
				return
			default:
				ecrire("250 ok")
			}
		}
	}()
	hote, port, _ := net.SplitHostPort(ln.Addr().String())
	cfg := config{SMTPHote: hote, SMTPPort: port, Expediteur: "nautilink@exemple.org"}
	if err := envoyerMail(cfg, "marin@exemple.org", "Essai é", "Bonjour\n"); err != nil {
		t.Fatal(err)
	}
	session := <-recu
	for _, attendu := range []string{"MAIL FROM:<nautilink@exemple.org>", "RCPT TO:<marin@exemple.org>", "To: marin@exemple.org", "Bonjour"} {
		if !strings.Contains(session, attendu) {
			t.Errorf("absent de la session SMTP : %q", attendu)
		}
	}
}

func TestMailRefuse(t *testing.T) {
	if err := envoyerMail(config{}, "a@b.c", "s", "t"); err == nil {
		t.Error("relais non réglé : erreur attendue")
	}
	if err := envoyerMail(config{SMTPHote: "x"}, "a@b.c\r\nBcc: z@y", "s", "t"); err == nil {
		t.Error("adresse avec saut de ligne : erreur attendue")
	}
}
