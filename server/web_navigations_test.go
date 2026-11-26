package main

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

// Essais sans base : calculs de la carte, textes et rendu des gabarits de
// l'Application web (TODO-6.1 à TODO-6.4).

func TestMercator(t *testing.T) {
	x, y := mercator(0, 0, 0)
	if x != 128 || y != 128 {
		t.Fatalf("origine : %v %v", x, y)
	}
	x, y = mercator(85.05112878, 180, 1)
	if x != 512 || y > 0.001 {
		t.Fatalf("coin : %v %v", x, y)
	}
}

// TestCadrer : tous les points dans la carte, zoom le plus grand possible,
// dalles OpenStreetMap et OpenSeaMap couvrant la carte (RG-NAV-29).
func TestCadrer(t *testing.T) {
	if cadrer(nil, nil, 800, 500, true) != nil {
		t.Fatal("sans point : pas de carte")
	}
	trace := []pointCarte{{Latitude: 47.80, Longitude: -3.95}, {Latitude: 47.72, Longitude: -3.99}, {Latitude: 47.70, Longitude: -4.00}}
	marques := []pointCarte{{Latitude: 47.70, Longitude: -4.00, Sorte: "sos", Titre: "SOS"}}
	c := cadrer(trace, marques, 800, 500, true)
	if c.Zoom < 10 || c.Zoom > zoomMax {
		t.Fatalf("zoom %d", c.Zoom)
	}
	plus := cadrer(trace, marques, 800, 500, false)
	for _, p := range plus.Points {
		if p.X < 0 || p.X > 800 || p.Y < 0 || p.Y > 500 {
			t.Fatalf("point hors de la carte : %+v", p)
		}
	}
	// Au zoom suivant, les points ne tiendraient plus.
	x1, y1 := mercator(47.80, -3.95, c.Zoom+1)
	x2, y2 := mercator(47.70, -4.00, c.Zoom+1)
	if c.Zoom < zoomMax && x1-x2 <= 800-48 && y2-y1 <= 500-48 {
		t.Fatalf("zoom %d trop petit", c.Zoom)
	}
	if len(c.Dalles) == 0 || len(plus.Dalles) != 0 {
		t.Fatalf("dalles : %d et %d", len(c.Dalles), len(plus.Dalles))
	}
	for _, d := range c.Dalles {
		if !strings.HasPrefix(d.Fond, "https://tile.openstreetmap.org/") || !strings.HasPrefix(d.Balise, "https://tiles.openseamap.org/seamark/") {
			t.Fatalf("dalle : %+v", d)
		}
		if d.X > 800 || d.X+256 < 0 || d.Y > 500 || d.Y+256 < 0 {
			t.Fatalf("dalle hors de la carte : %+v", d)
		}
	}
	if strings.Count(c.Trace, ",") != 3 {
		t.Fatalf("tracé : %q", c.Trace)
	}
	// Un seul point : zoom maximal, point au centre.
	un := cadrer([]pointCarte{{Latitude: 47.7, Longitude: -4}}, nil, 320, 200, false)
	if un.Zoom != zoomMax || un.Trace != "160,100" {
		t.Fatalf("un point : %d %q", un.Zoom, un.Trace)
	}
}

func TestTextesWeb(t *testing.T) {
	for m, attendu := range map[int]string{0: "0 min", 45: "45 min", 185: "3 h 05", 60*24*2 + 4*60 + 5: "2 j 4 h 05"} {
		if got := dureeTexte(m); got != attendu {
			t.Errorf("dureeTexte(%d) = %q", m, got)
		}
	}
	if got := distanceTexte(18520); got != "18,5 km (10,0 milles)" {
		t.Errorf("distance : %q", got)
	}
	nom := "Port-Tudy"
	p := &positionJSON{Latitude: 47.64561, Longitude: -3.44789}
	if lieuTexte(&lieuJSON{Nom: &nom, Position: p}) != "Port-Tudy" || lieuTexte(&lieuJSON{Position: p}) != "47,6456 N, 3,4479 O" || lieuTexte(nil) != "" {
		t.Error("lieuTexte")
	}
	dec := 60
	if got := heureWeb(time.Date(2026, 11, 26, 13, 32, 0, 0, time.UTC), &dec); got != "2026-11-26 14:32 (13:32 UTC)" {
		t.Errorf("heureWeb : %q", got)
	}
}

// rendu : page rendue sans base, avec ces données.
func rendu(t *testing.T, nom string, d *donneesPage) string {
	t.Helper()
	var b bytes.Buffer
	if err := pages.ExecuteTemplate(&b, nom, d); err != nil {
		t.Fatal(err)
	}
	return b.String()
}

func navEssai(nom, etat, role string) navigationJSON {
	debut := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	n := navigationJSON{ID: "11111111-0000-4000-8000-000000000001", Nom: nom, Etat: etat, Role: role, Debut: debut,
		Bateau: resumeBateau{Nom: "Alizé"}, DureeMinutes: 125, DistanceMetres: 9260}
	if etat == "terminee" {
		fin := debut.Add(125 * time.Minute)
		n.Fin = &fin
	}
	return n
}

// TestTitreLog : une ligne du log de nav (D-156) : « 26-nov-26 14:00-18:00
// 7 milles vers Toulon ».
func TestTitreLog(t *testing.T) {
	dec := 60
	debut := time.Date(2026, 11, 26, 13, 0, 0, 0, time.UTC)
	fin := debut.Add(4 * time.Hour)
	n := navigationJSON{Debut: debut, Fin: &fin, DistanceMetres: 7 * 1852, decalage: &dec, destinationTexte: "Toulon darse vieille"}
	if got := titreLog(n); got != "26-nov-26 14:00-18:00 7 milles vers Toulon darse vieille" {
		t.Errorf("titre : %q", got)
	}
	arrivee := "Port-Tudy"
	n.destinationTexte, n.LieuArrivee = "", &lieuJSON{Nom: &arrivee}
	if got := titreLog(n); got != "26-nov-26 14:00-18:00 7 milles vers Port-Tudy" {
		t.Errorf("sans destination : %q", got)
	}
	n.Fin, n.decalage, n.DistanceMetres = nil, nil, 700
	if got := titreLog(n); got != "26-nov-26 13:00-en cours UTC 0,4 mille" {
		t.Errorf("en cours, fuseau inconnu : %q", got)
	}
	if millesTexte(1852) != "1 mille" || millesTexte(2.6*1852) != "3 milles" {
		t.Error("millesTexte")
	}
}

// TestRenduTableau : log de nav par bateau sous le filtre, une ligne par
// navigation, en cours d'abord, fenêtre au survol avec le détail et l'aperçu
// (cahier des charges 6.1, D-156).
func TestRenduTableau(t *testing.T) {
	ligne := func(n navigationJSON, bateau string) ligneNav {
		n.Bateau = resumeBateau{ID: bateau, Nom: bateau}
		l := ligneNav{Titre: titreLog(n), N: n, Depart: heureWeb(n.Debut, nil), Duree: dureeTexte(n.DureeMinutes), Distance: distanceTexte(n.DistanceMetres)}
		l.Apercu = cadrer([]pointCarte{{Latitude: 47.7, Longitude: -4}, {Latitude: 47.6, Longitude: -3.9}}, nil, 320, 200, false)
		return l
	}
	enCours := []ligneNav{ligne(navEssai("Alizé — Glénan", "en_cours", "navigateur"), "Alizé")}
	hist := []ligneNav{ligne(navEssai("Mistral — Groix", "terminee", "suiveur"), "Mistral"), ligne(navEssai("Alizé — Houat", "terminee", "navigateur"), "Alizé")}
	d := &donneesPage{Base: "/nautilink", Connecte: true, EmailVerifie: true, Nom: "Paul", D: donneesTableau{
		EnCours: enCours, Historique: hist, Bateaux: parBateau(enCours, hist), Role: "suiveur", Suivant: 50}}
	page := rendu(t, "tableau.html", d)
	filtre, alize, mistral := strings.Index(page, "Afficher :"), strings.Index(page, "Log de nav de Alizé"), strings.Index(page, "Log de nav de Mistral")
	glenan, houat := strings.Index(page, "Alizé — Glénan"), strings.Index(page, "Alizé — Houat")
	if filtre < 0 || alize < filtre || mistral < alize || glenan > houat || houat > mistral {
		t.Fatalf("ordre : filtre %d, Alizé %d, Mistral %d, en cours %d, terminée %d", filtre, alize, mistral, glenan, houat)
	}
	for _, attendu := range []string{"Bonjour Paul", "Comme navigateur", "Comme suiveur",
		`href="/nautilink/?role=suiveur" aria-current="page"`, "Vous suivez cette navigation", "Votre navigation",
		"20-nov-26 09:00-11:05 UTC 5 milles", "20-nov-26 09:00-en cours UTC", "En cours",
		"2 h 05", "9,3 km (5,0 milles)", "2026-11-20 09:00 UTC", `class="bulle"`, "<polyline",
		`href="/nautilink/navigations/11111111-0000-4000-8000-000000000001"`, "?curseur=50&amp;role=suiveur"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("%q absent du log de nav", attendu)
		}
	}
	for _, absent := range []string{"<h1>Tableau de bord</h1>", "Aperçu</summary>", "openstreetmap"} {
		if strings.Contains(page, absent) {
			t.Errorf("%q présent dans le log de nav", absent)
		}
	}
	vide := rendu(t, "tableau.html", &donneesPage{Base: "/nautilink", Connecte: true, D: donneesTableau{}})
	if !strings.Contains(vide, "Aucune navigation.") {
		t.Error("log de nav vide")
	}
	if !strings.Contains(page, `src="/nautilink/static/logo-nautilink.png"`) {
		t.Error("logo absent devant le titre")
	}
}

// TestTableauDeBordWeb : avec PostgreSQL ; la connexion mène au tableau de
// bord (demande du 2026-11-26) ; navigations du navigateur et suivies.
func TestTableauDeBordWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().Add(-48 * time.Hour).Truncate(time.Second)
	fin := t0.Add(3 * time.Hour)
	terminee, _, _ := e.naviguer(nav, bateau, tel, t0, &fin)
	enCours, _, _ := e.naviguer(nav, bateau, tel, time.Now().Add(-time.Hour).Truncate(time.Second), nil)
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")

	web := e.navigateur()
	rec := web.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "lea@exemple.org", "motdepasse": "motdepasse"})
	if rec.Code != 303 || rec.Header().Get("Location") != "/nautilink/" {
		t.Fatalf("connexion : %d %q", rec.Code, rec.Header().Get("Location"))
	}
	page := web.envoyer("GET", "/nautilink/", nil).Body.String()
	if !strings.Contains(page, "Log de nav de Alizé") || !strings.Contains(page, "/navigations/"+enCours) || !strings.Contains(page, "/navigations/"+terminee) {
		t.Fatalf("tableau de bord du suiveur : %s", page)
	}
	if strings.Index(page, enCours) > strings.Index(page, terminee) {
		t.Fatal("navigation en cours après l'historique")
	}
	if p := web.envoyer("GET", "/nautilink/?role=navigateur", nil).Body.String(); strings.Contains(p, "/navigations/"+terminee) {
		t.Fatal("filtre « comme navigateur » : navigation suivie affichée")
	}
	navWeb := e.webConnecte("nav@exemple.org")
	p := navWeb.envoyer("GET", "/nautilink/?role=navigateur", nil).Body.String()
	if !strings.Contains(p, "/navigations/"+terminee) || !strings.Contains(p, "Votre navigation") || !strings.Contains(p, "<polyline") {
		t.Fatalf("tableau de bord du navigateur : %s", p)
	}
}
