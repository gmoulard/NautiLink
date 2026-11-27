package main

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func evenementEssai(id, typ string, h time.Time, lat, lon float64) evenementJSON {
	e := evenementJSON{ID: id, Type: typ, HeureAcquisition: h}
	if lat != 0 {
		e.Position = &positionJSON{Latitude: lat, Longitude: lon, HeureAcquisition: h}
	}
	return e
}

// journalEssai : début, positions, note située, photo, note vocale, SOS
// hors des heures affichées, position masquée, fin.
func journalEssai() []evenementJSON {
	t0 := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	texte := "Dauphins par le travers"
	note := evenementEssai("e3", "note", t0.Add(40*time.Minute), 47.66, -3.43)
	note.Texte = &texte
	photo := evenementEssai("e4", "photo", t0.Add(50*time.Minute), 0, 0)
	photo.Fichier = &fichierJSON{TypeMedia: "image/jpeg", Recu: true}
	vocal := evenementEssai("e5", "note_vocale", t0.Add(55*time.Minute), 0, 0)
	vocal.Fichier = &fichierJSON{TypeMedia: "audio/mp4"}
	masquee := evenementEssai("e8", "position_automatique", t0.Add(5*time.Hour), 48.5, -5.0)
	masquee.Masque = true
	sos := evenementEssai("e9", "sos", t0.Add(6*time.Hour), 47.50, -3.20)
	return []evenementJSON{
		evenementEssai("e1", "debut", t0, 47.70, -3.40),
		evenementEssai("e2", "position_automatique", t0.Add(30*time.Minute), 47.68, -3.42),
		note, photo, vocal,
		evenementEssai("e6", "fin", t0.Add(2*time.Hour), 47.64, -3.45),
		masquee, sos,
	}
}

// TestCarteDe : tracé sans les positions masquées (RG-NAV-22), SOS toujours
// marqué (RG-NAV-31), note située marquée, arrivée ou dernière position.
func TestCarteDe(t *testing.T) {
	c := carteDe(journalEssai(), false, nil, 800, 500, true)
	if n := strings.Count(c.Trace, ","); n != 4 {
		t.Fatalf("tracé de %d points : %q", n, c.Trace)
	}
	sortes := map[string]int{}
	for _, p := range c.Points {
		sortes[p.Sorte]++
		if p.Sorte == "sos" && !strings.HasPrefix(p.Titre, "Alerte SOS · 2026-11-20 15:00") {
			t.Errorf("titre du SOS : %q", p.Titre)
		}
	}
	if sortes["sos"] != 1 || sortes["evenement"] != 1 || sortes["depart"] != 1 || sortes["arrivee"] != 1 || sortes["position"] != 4 || sortes["derniere"] != 0 {
		t.Fatalf("points : %v", sortes)
	}
	if en := carteDe(journalEssai(), true, nil, 800, 500, false); en.Points[5].Sorte != "derniere" || len(en.Dalles) != 0 {
		t.Fatalf("navigation en cours : %+v", en.Points)
	}
	if carteDe(nil, false, nil, 800, 500, true) != nil {
		t.Fatal("sans position : pas de carte")
	}
}

// TestJournalPresente : libellés (RG-JRN-02), lieu ou coordonnées
// (RG-JRN-10), seuls notes, photos, notes vocales et ajouts modifiables, et
// seulement par le navigateur (RG-JRN-06, RG-JRN-07).
func TestJournalPresente(t *testing.T) {
	l := journalPresente(journalEssai(), nil, true)
	if l[0].Libelle != "Début de navigation" || l[0].Lieu != "47,7000 N, 3,4000 O" || l[0].Modifiable {
		t.Fatalf("début : %+v", l[0])
	}
	modifiables := ""
	for _, j := range l {
		if j.Modifiable {
			modifiables += j.E.Type + " "
		}
	}
	if modifiables != "note photo note_vocale " || !l[3].Photo || !l[4].Vocal || !l[6].Masque {
		t.Fatalf("modifiables : %q", modifiables)
	}
	for _, j := range journalPresente(journalEssai(), nil, false) {
		if j.Modifiable {
			t.Fatal("ami : rien de modifiable")
		}
	}
}

func donneesNavEssai(navigateur, enCours bool) *donneesPage {
	n := navEssai("Alizé — Glénan", "terminee", "navigateur")
	if enCours {
		n = navEssai("Alizé — Glénan", "en_cours", "navigateur")
	}
	n.Navigateur = &personneJSON{Nom: "Paul"}
	n.Fiche = &bateauJSON{ID: "22222222-0000-4000-8000-000000000002", Nom: "Alizé", Type: "voilier", PortAttache: "Lorient", AUnePhoto: true}
	n.Amis = []amiJSON{{personneJSON: personneJSON{ID: "33333333-0000-4000-8000-000000000003", Nom: "Léa"}, Suit: true}, {personneJSON: personneJSON{Nom: "Secours"}}}
	n.PersonnesABord, n.Version = 3, 2
	evts := journalEssai()
	d := donneesNavigation{N: n, Navigateur: navigateur, EnCours: enCours, Destination: "Glénan", Frequence: libelleFrequence(60),
		Journal: journalPresente(evts, nil, navigateur), Carte: carteDe(evts, enCours, nil, 800, 500, true), Curseur: 42,
		L: ligneNav{Depart: "2026-11-20 09:00 UTC", Duree: "2 h 05", Distance: distanceTexte(9260)}}
	probleme := "Voie d'eau"
	d.Alertes = []ligneAlerte{{A: alerteSosJSON{ProblemeRencontre: &probleme}, Heure: "2026-11-20 15:00 UTC", Lieu: "47,5000 N, 3,2000 O", HorsNavigation: true}}
	return &donneesPage{Base: "/nautilink", Connecte: true, Titre: n.Nom, D: d}
}

// TestRenduNavigation : cahier des charges 6.2 ; RG-NAV-29 (mentions de
// source), RG-JRN-09 (photo en grand, note vocale à écouter), RG-PAR-07
// (ami en lecture seule), RG-NAV-20 (suppression confirmée).
func TestRenduNavigation(t *testing.T) {
	page := rendu(t, "navigation.html", donneesNavEssai(true, false))
	for _, attendu := range []string{"<h1>Alizé — Glénan</h1>", "Navigation terminée", "Personnes à bord</dt><dd>3",
		"Fréquence des positions</dt><dd>1 heure", "Destination</dt><dd>Glénan", "https://tile.openstreetmap.org/",
		"https://tiles.openseamap.org/seamark/", "les contributeurs d'OpenStreetMap", "OpenSeaMap", "<polyline",
		`class="point sos"`, "Alerte SOS", "Voie d&#39;eau", "en dehors des heures de la navigation",
		"Dauphins par le travers", `<a href="/nautilink/api/v1/fichiers/e4"><img class="photo" src="/nautilink/api/v1/fichiers/e4"`,
		"Note vocale en cours d'envoi", "en dehors des heures affichées", `id="evenement-e3"`,
		"Port d'attache</dt><dd>Lorient", "/nautilink/api/v1/bateaux/22222222-0000-4000-8000-000000000002/photo",
		"Léa", "Retirer de cette navigation", "Secours", "Je confirme la suppression", `action="/nautilink/navigations/11111111-0000-4000-8000-000000000001/suppression"`,
		`data-curseur="42"`, `data-version="2"`, `data-etat="terminee"`} {
		if !strings.Contains(page, attendu) {
			t.Errorf("%q absent de la page du navigateur", attendu)
		}
	}
	if strings.Contains(page, "navigation.js") {
		t.Error("navigation terminée : pas de mise à jour en direct")
	}
	// Ordre chronologique du journal (RG-JRN-03).
	journal := page[strings.Index(page, "Journal de bord"):]
	if strings.Index(journal, "Début de navigation") > strings.Index(journal, "Dauphins") || strings.Index(journal, "Dauphins") > strings.Index(journal, "Fin de navigation") {
		t.Error("journal hors de l'ordre chronologique")
	}

	ami := rendu(t, "navigation.html", donneesNavEssai(false, true))
	if strings.Contains(ami, "/suppression") || strings.Contains(ami, "/retrait") {
		t.Error("ami : formulaires du navigateur affichés")
	}
	for _, attendu := range []string{"Navigation en cours", "/nautilink/static/navigation.js", `data-etat="en_cours"`,
		`aria-live="polite"`, "Dernière position"} {
		if !strings.Contains(ami, attendu) {
			t.Errorf("%q absent de la page en cours", attendu)
		}
	}

	// Partie « en direct » seule, pour static/navigation.js.
	var b bytes.Buffer
	if err := pages.ExecuteTemplate(&b, "navigation-direct", donneesNavEssai(false, true)); err != nil {
		t.Fatal(err)
	}
	if f := b.String(); strings.Contains(f, "<html") || !strings.Contains(f, "Journal de bord") || !strings.Contains(f, "<svg") {
		t.Fatalf("partie en direct : %s", f)
	}
}

// TestSecuriteCarte : les dalles de la carte sont permises par la politique
// de sécurité du contenu, rien d'autre hors du site.
func TestSecuriteCarte(t *testing.T) {
	h := nouveauRouteur(config{Chemin: "/nautilink"}, &base{})
	csp := requete(t, h, "/nautilink/").Header().Get("Content-Security-Policy")
	if !strings.Contains(csp, "img-src 'self' data: https://tile.openstreetmap.org https://tiles.openseamap.org;") || !strings.Contains(csp, "default-src 'self'") {
		t.Fatalf("CSP : %q", csp)
	}
	if rec := requete(t, h, "/nautilink/static/navigation.js"); rec.Code != 200 || !strings.Contains(rec.Body.String(), "X-Curseur") {
		t.Fatalf("navigation.js : %d", rec.Code)
	}
}

// TestPageNavigationWeb : avec PostgreSQL : page du navigateur et du
// ami, mise à jour en direct (une position envoyée par le téléphone
// apparaît), retrait d'un ami, accès refusé sans accès.
func TestPageNavigationWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().Add(-2 * time.Hour).Truncate(time.Second)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, nil)
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	photo := uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+photo, nav, map[string]any{"id": photo, "type": "photo",
		"heureAcquisition": heure(t0.Add(time.Hour)), "fichier": map[string]any{"typeMedia": "image/jpeg"}}); code != 201 {
		t.Fatal("photo")
	}
	if code := e.fichier("PUT", photo, nav, "image/jpeg", append([]byte{0xFF, 0xD8, 0xFF, 0xE0}, bytes.Repeat([]byte{1}, 100)...)); code != 204 {
		t.Fatal("fichier de la photo")
	}

	web := e.webConnecte("nav@exemple.org")
	rec := web.envoyer("GET", "/nautilink/navigations/"+id, nil)
	page := rec.Body.String()
	if rec.Code != 200 || !strings.Contains(page, "Alizé — Glénan") || !strings.Contains(page, "/api/v1/fichiers/"+photo) ||
		!strings.Contains(page, "navigation.js") || !strings.Contains(page, "Retirer de cette navigation") {
		t.Fatalf("page du navigateur : %d %s", rec.Code, page)
	}
	if rec.Header().Get("Referrer-Policy") != "strict-origin-when-cross-origin" {
		t.Fatal("origine à transmettre aux serveurs de dalles")
	}
	curseur := entre(page, `data-curseur="`, `"`)
	version := entre(page, `data-version="`, `"`)

	// Rien de nouveau : 204 ; une position reçue : la partie en direct la montre.
	direct := "/nautilink/navigations/" + id + "/direct?depuis=" + curseur + "&version=" + version
	if rec := web.envoyer("GET", direct, nil); rec.Code != 204 || rec.Header().Get("X-Etat") != "en_cours" {
		t.Fatalf("rien de nouveau : %d", rec.Code)
	}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+uuid(t), nav, position("", t0.Add(90*time.Minute), 5, 47.5, -3.1)); code != 201 {
		t.Fatal("position")
	}
	rec = web.envoyer("GET", direct, nil)
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "47,5000 N, 3,1000 O") || rec.Header().Get("X-Curseur") == curseur ||
		strings.Contains(rec.Body.String(), "<html") {
		t.Fatalf("nouvelle position : %d %s", rec.Code, rec.Body.String())
	}

	// Ami : lecture seule.
	webLea := e.webConnecte("lea@exemple.org")
	p := webLea.envoyer("GET", "/nautilink/navigations/"+id, nil).Body.String()
	if !strings.Contains(p, "Alizé — Glénan") || strings.Contains(p, "/retrait") || strings.Contains(p, "/suppression") {
		t.Fatalf("page de l'ami : %s", p)
	}
	if rec := webLea.envoyer("POST", "/nautilink/navigations/"+id+"/amis/"+e.id(lea)+"/retrait", map[string]string{}); rec.Code != 403 {
		t.Fatalf("retrait par un ami : %d", rec.Code)
	}
	// Retrait de cette navigation (RG-PAR-06) : plus d'accès.
	if rec := web.envoyer("POST", "/nautilink/navigations/"+id+"/amis/"+e.id(lea)+"/retrait", map[string]string{}); rec.Code != 303 {
		t.Fatalf("retrait : %d", rec.Code)
	}
	if rec := webLea.envoyer("GET", "/nautilink/navigations/"+id, nil); rec.Code != 404 {
		t.Fatalf("après le retrait : %d", rec.Code)
	}
	if rec := webLea.envoyer("GET", "/nautilink/navigations/"+id+"/direct", nil); rec.Code != 404 {
		t.Fatalf("partie en direct après le retrait : %d", rec.Code)
	}
}

// entre : texte entre debut et fin.
func entre(s, debut, fin string) string {
	i := strings.Index(s, debut)
	if i < 0 {
		return ""
	}
	s = s[i+len(debut):]
	return s[:strings.Index(s, fin)]
}
