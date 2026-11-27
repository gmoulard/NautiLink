package main

import (
	"net/url"
	"strings"
	"testing"
	"time"
)

// TestDemarrageWebFormulaire : RG-WEB-05, RG-WEB-07 : position et décalage
// remplis par static/conduite.js, absents sans JavaScript.
func TestDemarrageWebFormulaire(t *testing.T) {
	if v := decalageWeb("60"); v == nil || *v != 60 {
		t.Errorf("decalageWeb(60) = %v", v)
	}
	for _, s := range []string{"", "abc", "900", "-900"} {
		if decalageWeb(s) != nil {
			t.Errorf("decalageWeb(%q) non nul", s)
		}
	}
	h := time.Date(2026, 11, 26, 10, 0, 0, 0, time.UTC)
	r := formulaireEssai(url.Values{"latitude": {"47.7"}, "longitude": {"-3.36"}, "precision": {"12"}})
	if p := positionWeb(r, h); p == nil || p.Latitude != 47.7 || p.Longitude != -3.36 || *p.PrecisionMetres != 12 || !p.HeureAcquisition.Equal(h) {
		t.Errorf("positionWeb : %+v", p)
	}
	if positionWeb(formulaireEssai(url.Values{"latitude": {""}}), h) != nil {
		t.Error("sans position : position non nulle")
	}
	r = formulaireEssai(url.Values{"bateauId": {"b1"}, "frequence": {"30"}, "personnesABord": {"3"}, "destination": {" Glénan "},
		"chefDeBord": {"Paul"}, "email": {"11111111-0000-4000-8000-000000000001", "pas-un-uuid", "11111111-0000-4000-8000-000000000001"}})
	d := demarrageWeb(r, "Paul", h)
	if !d.web || d.BateauID != "b1" || d.FrequenceMinutes != 30 || d.PersonnesABord != 3 || d.Destination.Texte != "Glénan" ||
		d.ChefDeBord != nil || len(*d.PersonnesAlertees) != 1 || d.Debut.Type != "debut" || d.Debut.Origine != "web" || d.Debut.Position != nil {
		t.Errorf("demarrageWeb : %+v", d)
	}
	r = formulaireEssai(url.Values{"chefDeBord": {"Léa"}})
	if d := demarrageWeb(r, "Paul", h); d.ChefDeBord == nil || *d.ChefDeBord != "Léa" || len(*d.PersonnesAlertees) != 0 {
		t.Errorf("chef de bord et aucune personne cochée : %+v", d)
	}
	q := &erreurQuota{&erreurAPI{message: "Quota épuisé."}, h}
	if s := texteQuotaEpuise(q); !strings.Contains(s, "Quota épuisé.") || !strings.Contains(s, "2026-11-26 10:00 UTC") {
		t.Errorf("quota : %s", s)
	}
}

// TestRenduDemarrage : écran de démarrage (RG-NAV-25, RG-NAV-27, RG-NAV-35,
// RG-SOS-14, RG-ECO-04) et formulaires de conduite (RG-WEB-05, RG-JRN-11).
func TestRenduDemarrage(t *testing.T) {
	dd := donneesDemarrage{Bateaux: []bateauJSON{{ID: "b1", Nom: "Alizé"}, {ID: "b2", Nom: "Mistral"}}, BateauID: "b2",
		Frequences: []optionFrequence{{30, "30 minutes", false}, {60, "1 heure", true}}, PersonnesABord: 2, ChefDeBord: "Paul",
		Personnes: []personneAlertee{{ID: "c1", Nom: "Léa", Cochee: true}, {ID: "c2", Nom: "Marc", Sos: true, Cochee: true, SansEmail: true}}}
	page := rendu(t, "demarrer.html", &donneesPage{Base: "/nautilink", Connecte: true, EmailVerifie: true, D: dd})
	for _, attendu := range []string{"<h1>Démarrer navigation</h1>", `class="avec-position"`, `name="latitude"`, `name="decalage"`,
		`<option value="b2" selected>Mistral`, `<option value="60" selected>1 heure`, `value="Paul"`, `name="personnesABord"`,
		`value="c2" checked data-sos`, "aucune adresse connue", `id="sans-sos" hidden`, "Ajouter une personne", "Aucun SMS ne part",
		"tant que la page de la navigation reste ouverte", ">Début de navigation</button>", "/nautilink/static/conduite.js"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("démarrage : %q absent", attendu)
		}
	}
	if strings.Contains(page, " style=") || strings.Contains(page, "onclick") || strings.Contains(page, "<script>") {
		t.Error("démarrage : script ou style en ligne, refusé par la politique de sécurité")
	}
	dd.SansContactSos, dd.Personnes = true, nil
	if page := rendu(t, "demarrer.html", &donneesPage{Base: "/nautilink", Connecte: true, EmailVerifie: true, D: dd}); !strings.Contains(page, `<p class="erreur" id="sans-sos" >`) {
		t.Error("sans contact SOS : avertissement caché")
	}
	dd.QuotaEpuise = "Quota épuisé."
	if page := rendu(t, "demarrer.html", &donneesPage{Base: "/nautilink", Connecte: true, EmailVerifie: true, D: dd}); !strings.Contains(page, "Quota épuisé.") ||
		!strings.Contains(page, "/nautilink/quota") || strings.Contains(page, "Début de navigation") {
		t.Error("quota épuisé : démarrage proposé")
	}
	if page := rendu(t, "demarrer.html", &donneesPage{Base: "/nautilink", Connecte: true, EmailVerifie: true, D: donneesDemarrage{}}); !strings.Contains(page, "Aucun bateau dans votre compte") {
		t.Error("sans bateau : message absent")
	}
	if page := rendu(t, "demarrer.html", &donneesPage{Base: "/nautilink", Connecte: true, D: dd}); !strings.Contains(page, "Confirmez d'abord votre adresse") {
		t.Error("adresse non confirmée : message absent")
	}

	enCours := donneesNavEssai(true, true)
	page = rendu(t, "navigation.html", enCours)
	for _, attendu := range []string{">Envoyer position</button>", `<option value="incident">Incident - avarie</option>`,
		`id="positions-auto"`, `data-frequence="0"`, "/nautilink/static/conduite.js", "/position"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("conduite : %q absent", attendu)
		}
	}
	nav := enCours.D.(donneesNavigation)
	nav.AvecTelephone = true
	enCours.D = nav
	if page := rendu(t, "navigation.html", enCours); strings.Contains(page, `id="positions-auto"`) || !strings.Contains(page, "Le téléphone associé au bateau envoie") {
		t.Error("navigation rattachée au téléphone : positions automatiques du Web")
	}
	if page := rendu(t, "navigation.html", donneesNavEssai(false, true)); strings.Contains(page, "conduite.js") {
		t.Error("suiveur : script de conduite chargé")
	}
	if page := rendu(t, "tableau.html", &donneesPage{Base: "/nautilink", Connecte: true, D: donneesTableau{}}); !strings.Contains(page, `href="/nautilink/demarrer"`) {
		t.Error("tableau de bord : « Démarrer navigation » absent")
	}
	rec := requete(t, nouveauRouteur(config{Chemin: "/nautilink"}, &base{}), "/nautilink/static/conduite.js")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "geolocation") {
		t.Errorf("conduite.js : %d", rec.Code)
	}
}

// TestDemarrageWeb : avec PostgreSQL : TS-WEB-05 à TS-WEB-07 : démarrage
// depuis l'Application web sans téléphone, positions, reprise par le
// téléphone associé, incident, fin et SOS avec position.
func TestDemarrageWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Paul", "Alizé")
	code, k := e.appel("POST", "/contacts", nav, map[string]any{"nom": "Marc", "telephone": "06 99 88 77 66", "email": "marc@exemple.org", "suiveur": false})
	if code != 201 {
		t.Fatalf("contact SOS : %d %v", code, k)
	}
	marc := k["id"].(string)
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	web := e.webConnecte("nav@exemple.org")

	page := web.envoyer("GET", "/nautilink/demarrer", nil).Body.String()
	for _, attendu := range []string{"Alizé", "Marc", `value="` + marc + `"`, `value="Paul"`, "Début de navigation"} {
		if !strings.Contains(page, attendu) {
			t.Fatalf("écran de démarrage : %q absent", attendu)
		}
	}
	if strings.Count(page, `name="email"`) != 2 { // le contact SOS et le suiveur
		t.Fatalf("écran de démarrage : personnes alertées : %s", page)
	}
	rec := web.envoyer("POST", "/nautilink/demarrer", map[string]string{"bateauId": bateau, "frequence": "30", "personnesABord": "3",
		"chefDeBord": "Paul", "destination": "Glénan", "email": marc, "latitude": "47.7", "longitude": "-3.36", "precision": "15", "decalage": "60"})
	if rec.Code != 303 || !strings.HasSuffix(rec.Header().Get("Location"), "?ok=demarree") {
		t.Fatalf("démarrage : %d %s", rec.Code, rec.Body.String())
	}
	id := strings.TrimSuffix(strings.TrimPrefix(rec.Header().Get("Location"), "/nautilink/navigations/"), "?ok=demarree")
	_, n := e.appel("GET", "/navigations/"+id, nav, nil)
	if n["etat"] != "en_cours" || n["chefDeBord"] != "Paul" || n["personnesABord"] != 3.0 || n["frequenceMinutes"] != 30.0 || n["nom"] != "Alizé — Glénan" {
		t.Fatalf("navigation démarrée : %v", n)
	}
	if e.compter("SELECT count(*) FROM navigations WHERE id = $1 AND appareil_id IS NULL AND decalage_minutes = 60 AND personnes_alertees = ARRAY[$2::uuid]", id, marc) != 1 {
		t.Fatal("navigation sans téléphone, fuseau du navigateur Internet et personne cochée attendus")
	}
	if e.compter("SELECT count(*) FROM evenements WHERE navigation_id = $1 AND type = 'debut' AND origine = 'web' AND latitude = 47.7", id) != 1 {
		t.Fatal("début sans la position du navigateur Internet")
	}
	// Un bateau, une navigation en cours (RG-NAV-03).
	if rec := web.envoyer("POST", "/nautilink/demarrer", map[string]string{"bateauId": bateau, "frequence": "30", "personnesABord": "1"}); rec.Code != 409 ||
		!strings.Contains(rec.Body.String(), "déjà en cours") {
		t.Fatalf("second démarrage : %d", rec.Code)
	}

	base := "/nautilink/navigations/" + id
	if rec := web.envoyer("POST", base+"/position", map[string]string{"type": "position_automatique", "latitude": "47.71", "longitude": "-3.37", "decalage": "60"}); rec.Code != 204 {
		t.Fatalf("position automatique : %d", rec.Code)
	}
	if rec := web.envoyer("POST", base+"/position", map[string]string{"type": "position_automatique"}); rec.Code != 422 {
		t.Fatalf("position automatique sans position : %d", rec.Code)
	}
	if rec := web.envoyer("POST", base+"/position", map[string]string{}); rec.Code != 422 || !strings.Contains(rec.Body.String(), "Position indisponible") {
		t.Fatalf("« Envoyer position » sans position : %d", rec.Code)
	}
	if rec := web.envoyer("POST", base+"/position", map[string]string{"latitude": "47.72", "longitude": "-3.38"}); rec.Code != 303 {
		t.Fatalf("« Envoyer position » : %d", rec.Code)
	}
	if rec := web.envoyerFichier(base+"/conduite", map[string]string{"type": "incident", "texte": "Safran cassé", "latitude": "47.73", "longitude": "-3.39"}, nil); rec.Code != 303 {
		t.Fatalf("incident : %d %s", rec.Code, rec.Body.String())
	}
	if rec := web.envoyerFichier(base+"/conduite", map[string]string{"type": "incident"}, nil); rec.Code != 422 {
		t.Fatalf("incident sans texte : %d", rec.Code)
	}
	for typ, nombre := range map[string]int{"position_automatique": 1, "position_manuelle": 1, "incident": 1} {
		if e.compter("SELECT count(*) FROM evenements WHERE navigation_id = $1 AND type = $2 AND origine = 'web' AND latitude IS NOT NULL", id, typ) != nombre {
			t.Errorf("%s : %d attendu", typ, nombre)
		}
	}
	if page := web.envoyer("GET", base, nil).Body.String(); !strings.Contains(page, `id="positions-auto"`) {
		t.Fatal("page de la navigation : positions automatiques du Web absentes")
	}

	// SOS avec la position du navigateur Internet : position actuelle.
	if rec := web.envoyer("POST", "/nautilink/sos", map[string]string{"navigationId": id, "latitude": "47.74", "longitude": "-3.4", "decalage": "60"}); rec.Code != 303 {
		t.Fatalf("SOS : %d", rec.Code)
	}
	_, l := e.liste("GET", "/alertes-sos?navigationId="+id, nav, nil)
	if len(l) != 1 || l[0]["naturePosition"] != "actuelle" {
		t.Fatalf("alerte : %v", l)
	}

	// Reprise par le téléphone associé (RG-NAV-33) : rattaché à son premier envoi.
	h := time.Now().Truncate(time.Second)
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+uuid(t), nav, position("", h, 1, 47.75, -3.41)); code != 201 {
		t.Fatalf("position du téléphone : %d %v", code, r)
	}
	if e.compter("SELECT count(*) FROM navigations WHERE id = $1 AND appareil_id = $2", id, tel) != 1 {
		t.Fatal("navigation non rattachée au téléphone associé")
	}
	if page := web.envoyer("GET", base, nil).Body.String(); strings.Contains(page, `id="positions-auto"`) {
		t.Fatal("téléphone rattaché : positions automatiques du Web encore envoyées")
	}

	// Fin depuis le Web, avec position.
	if rec := web.envoyer("POST", base+"/fin", map[string]string{"confirmation": "on", "latitude": "47.76", "longitude": "-3.42"}); rec.Code != 303 {
		t.Fatalf("fin : %d", rec.Code)
	}
	if e.compter("SELECT count(*) FROM evenements WHERE navigation_id = $1 AND type = 'fin' AND latitude = 47.76", id) != 1 {
		t.Fatal("fin sans position")
	}
	if rec := web.envoyer("POST", base+"/position", map[string]string{"type": "position_automatique", "latitude": "47.7", "longitude": "-3.3"}); rec.Code != 409 {
		t.Fatalf("position après la fin : %d", rec.Code)
	}
}

// TestLiensRelectureWeb : D-166 : « Mémo sécurité en mer » dans le pied de
// page de chaque page (RG-SOS-22), « Météo marine » pendant la navigation
// (RG-NAV-37).
func TestLiensRelectureWeb(t *testing.T) {
	h := nouveauRouteur(config{Chemin: "/nautilink"}, &base{})
	for _, chemin := range []string{"/nautilink/", "/nautilink/connexion", "/nautilink/inscription"} {
		if corps := requete(t, h, chemin).Body.String(); !strings.Contains(corps, `<a href="`+adresseMemo+`">Mémo sécurité en mer</a>`) {
			t.Errorf("%s : mémo absent du pied de page", chemin)
		}
	}
	if page := rendu(t, "navigation.html", donneesNavEssai(true, true)); !strings.Contains(page, `<a class="bouton" href="https://meteofrance.com/meteo-marine">Météo marine</a>`) {
		t.Error("navigation en cours : lien « Météo marine » absent")
	}
	if page := rendu(t, "navigation.html", donneesNavEssai(true, false)); strings.Contains(page, "Météo marine") {
		t.Error("navigation terminée : lien « Météo marine » affiché")
	}
	d := donneesNavEssai(true, true)
	nd := d.D.(donneesNavigation)
	nd.N.MeteoMarine = lienMeteoMarine(&lieuJSON{Nom: ptr("Lorient")})
	d.D = nd
	if page := rendu(t, "navigation.html", d); !strings.Contains(page, `<a class="bouton" href="https://meteofrance.com/recherche/Lorient">Météo marine</a>`) {
		t.Error("navigation en cours : lien « Météo marine » sans la commune de la dernière position")
	}
}

// TestLienMeteoMarine : RG-NAV-37, D-169 : recherche de Météo-France sur le
// lieu de la dernière position, encodé dans l'adresse ; sinon page générale.
func TestLienMeteoMarine(t *testing.T) {
	for _, c := range []struct {
		lieu    *lieuJSON
		attendu string
	}{
		{nil, "https://meteofrance.com/meteo-marine"},
		{&lieuJSON{}, "https://meteofrance.com/meteo-marine"},
		{&lieuJSON{Nom: ptr("  ")}, "https://meteofrance.com/meteo-marine"},
		{&lieuJSON{Nom: ptr("Lorient")}, "https://meteofrance.com/recherche/Lorient"},
		{&lieuJSON{Nom: ptr("Île de Groix")}, "https://meteofrance.com/recherche/%C3%8Ele%20de%20Groix"},
		{&lieuJSON{Nom: ptr("Saint-Pierre/Quiberon")}, "https://meteofrance.com/recherche/Saint-Pierre%2FQuiberon"},
	} {
		if got := lienMeteoMarine(c.lieu); got != c.attendu {
			t.Errorf("lienMeteoMarine(%v) = %q, attendu %q", c.lieu, got, c.attendu)
		}
	}
}
