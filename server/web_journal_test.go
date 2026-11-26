package main

import (
	"bytes"
	"encoding/binary"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// m4aEssai : en-tête « ftyp » et boîte « moov » avec « mvhd » (version 0)
// d'une durée de secondes.
func m4aEssai(secondes uint32) []byte {
	boite := func(nom string, contenu []byte) []byte {
		b := make([]byte, 8, 8+len(contenu))
		binary.BigEndian.PutUint32(b, uint32(8+len(contenu)))
		copy(b[4:], nom)
		return append(b, contenu...)
	}
	mvhd := make([]byte, 100)
	binary.BigEndian.PutUint32(mvhd[12:], 1000)
	binary.BigEndian.PutUint32(mvhd[16:], secondes*1000)
	return append(boite("ftyp", []byte("M4A \x00\x00\x00\x00")), boite("moov", boite("mvhd", mvhd))...)
}

func TestDureeM4A(t *testing.T) {
	if s, ok := dureeM4A(m4aEssai(42)); !ok || s != 42 {
		t.Fatalf("durée : %v %v", s, ok)
	}
	if _, ok := dureeM4A([]byte("pas un m4a du tout")); ok {
		t.Fatal("fichier illisible accepté")
	}
}

// TestFichierAjout : photo JPEG ou note vocale d'une minute au plus
// (RG-JRN-04, RG-JRN-08), reconnues à leur contenu.
func TestFichierAjout(t *testing.T) {
	if f, err := fichierAjout(nil); f != nil || err != nil {
		t.Fatal("sans fichier")
	}
	if f, err := fichierAjout(jpegEssai); err != nil || f.TypeMedia != "image/jpeg" {
		t.Fatalf("photo : %v %v", f, err)
	}
	if f, err := fichierAjout(m4aEssai(60)); err != nil || f.TypeMedia != "audio/mp4" || *f.DureeSecondes != 60 {
		t.Fatalf("note vocale : %v %v", f, err)
	}
	if _, err := fichierAjout(m4aEssai(75)); err == nil || !strings.Contains(err.Error(), "1 minute") {
		t.Fatalf("note vocale trop longue : %v", err)
	}
	if _, err := fichierAjout([]byte("GIF89a……")); err == nil {
		t.Fatal("autre format accepté")
	}
	if _, err := fichierAjout(append(append([]byte{}, jpegEssai...), make([]byte, tailleFichierMax)...)); err == nil {
		t.Fatal("fichier trop gros accepté")
	}
}

func TestHeuresSaisies(t *testing.T) {
	dec := 60
	h := time.Date(2026, 11, 20, 8, 30, 37, 0, time.UTC)
	if v := valeurSaisie(h, &dec); v != "2026-11-20T09:30" {
		t.Fatalf("valeur : %q", v)
	}
	if v := valeurSaisie(h, nil); v != "2026-11-20T08:30" {
		t.Fatalf("valeur UTC : %q", v)
	}
	if got, err := heureSaisie("2026-11-20T09:30", &dec); err != nil || !got.Equal(h.Truncate(time.Minute)) {
		t.Fatalf("saisie : %v %v", got, err)
	}
	if _, err := heureSaisie("hier", nil); err == nil {
		t.Fatal("heure illisible acceptée")
	}
	moins := -210
	if libelleZone(&dec) != "heure locale du téléphone (UTC+01:00)" || libelleZone(&moins) != "heure locale du téléphone (UTC-03:30)" || libelleZone(nil) != "heure UTC" {
		t.Fatal("libellé du fuseau")
	}
	for range 20 {
		if id := nouvelUUID(); !estUUID(id) || id[14] != '4' {
			t.Fatalf("UUID : %q", id)
		}
	}
}

// TestChampsModifies : seuls les champs changés partent (RG-COM-04) ; une
// heure laissée telle quelle garde ses secondes ; en cours, le nom seul
// (RG-NAV-17, RG-NAV-22).
func TestChampsModifies(t *testing.T) {
	debut := time.Date(2026, 11, 20, 8, 0, 37, 0, time.UTC)
	fin := debut.Add(3 * time.Hour)
	n := navLigne{nom: "Alizé — Glénan", bateau: "b1", debut: debut, fin: &fin, finEnr: &fin, destination: &destinationJSON{Texte: "Glénan"}}
	formulaire := func(v url.Values) *http.Request {
		r := httptest.NewRequest("POST", "/", strings.NewReader(v.Encode()))
		r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		_ = r.ParseForm()
		return r
	}
	inchange := url.Values{"nom": {"Alizé — Glénan"}, "destination": {"Glénan"}, "bateauId": {"b1"},
		"debut": {"2026-11-20T08:00"}, "fin": {"2026-11-20T11:00"}}
	if c, err := champsModifies(formulaire(inchange), n, ""); err != nil || len(c) != 0 {
		t.Fatalf("rien de changé : %v %v", c, err)
	}
	change := url.Values{"nom": {"Sortie aux Glénan"}, "destination": {""}, "bateauId": {"b2"},
		"debut": {"2026-11-20T08:00"}, "fin": {"2026-11-20T12:15"}}
	c, err := champsModifies(formulaire(change), n, "")
	if err != nil || string(c["nom"]) != `"Sortie aux Glénan"` || string(c["destination"]) != "null" || string(c["bateauId"]) != `"b2"` ||
		c.a("debut") || string(c["fin"]) != `"2026-11-20T12:15:00Z"` {
		t.Fatalf("changements : %v %v", c, err)
	}
	if _, err := champsModifies(formulaire(url.Values{"fin": {"demain"}}), n, ""); err == nil {
		t.Fatal("heure illisible acceptée")
	}
	enCours := n
	enCours.fin, enCours.finEnr = nil, nil
	if c, _ := champsModifies(formulaire(change), enCours, ""); len(c) != 1 || !c.a("nom") {
		t.Fatalf("en cours, le nom seul : %v", c)
	}
}

// TestRenduModifier : formulaires du navigateur seulement (RG-PAR-07) ;
// notes, photos et notes vocales modifiables, pas les positions (RG-JRN-07).
func TestRenduModifier(t *testing.T) {
	d := donneesNavEssai(true, false)
	nav := d.D.(donneesNavigation)
	nav.Modifier = &modificationNav{Terminee: true, Nom: nav.N.Nom, BateauID: "b1", Bateaux: []bateauJSON{{ID: "b1", Nom: "Alizé"}, {ID: "b2", Nom: "Mistral"}},
		Debut: "2026-11-20T09:00", Fin: "2026-11-20T11:05", Zone: "heure UTC", PhotosRestantes: 19}
	d.D = nav
	page := rendu(t, "navigation.html", d)
	for _, attendu := range []string{"Modifier la navigation", `action="/nautilink/navigations/11111111-0000-4000-8000-000000000001/modification"`,
		`<option value="b1" selected>Alizé</option>`, `<option value="b2" >Mistral</option>`, `name="debut" type="datetime-local" required value="2026-11-20T09:00"`,
		"Ajouter au journal", `enctype="multipart/form-data"`, "Encore 19 photos possibles", "L'ajout prend l'heure à laquelle vous le faites",
		`action="/nautilink/navigations/11111111-0000-4000-8000-000000000001/evenements/e3"`, ">Dauphins par le travers</textarea>",
		"/evenements/e4/suppression", "et de son fichier"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("%q absent", attendu)
		}
	}
	for _, interdit := range []string{"/evenements/e1", "/evenements/e2", "/evenements/e6", "/evenements/e9"} {
		if strings.Contains(page, interdit) {
			t.Errorf("début, position, fin ou SOS modifiable : %q", interdit)
		}
	}
	if s := rendu(t, "navigation.html", donneesNavEssai(false, false)); strings.Contains(s, "Modifier") || strings.Contains(s, "Ajouter au journal") {
		t.Error("suiveur : formulaires de modification affichés")
	}
}

// envoyerFichier : formulaire multipart de l'Application web.
func (n *navigateurWeb) envoyerFichier(chemin string, champs map[string]string, fichier []byte) *httptest.ResponseRecorder {
	n.e.t.Helper()
	var corps bytes.Buffer
	mp := multipart.NewWriter(&corps)
	for k, v := range champs {
		_ = mp.WriteField(k, v)
	}
	if fichier != nil {
		p, _ := mp.CreateFormFile("fichier", "ajout")
		p.Write(fichier)
	}
	mp.Close()
	req := httptest.NewRequest("POST", chemin, &corps)
	req.Header.Set("Content-Type", mp.FormDataContentType())
	for _, c := range n.cookies {
		req.AddCookie(c)
	}
	rec := httptest.NewRecorder()
	n.e.h.ServeHTTP(rec, req)
	return rec
}

// TestJournalWeb : avec PostgreSQL : TS-JRN-05, TS-JRN-06, TS-JRN-07,
// TS-NAV-24 depuis l'Application web.
func TestJournalWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Date(2026, 11, 20, 8, 0, 37, 0, time.FixedZone("", 3600))
	horloge(e, t0)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, nil)
	note := uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+note, nav, map[string]any{"type": "note", "texte": "Ris pris",
		"heureAcquisition": heure(t0.Add(time.Hour)), "origine": "android"}); code != 201 {
		t.Fatal("note")
	}
	web := e.webConnecte("nav@exemple.org")
	base := "/nautilink/navigations/" + id

	// En cours : nom seul, pas d'ajout.
	if rec := web.envoyer("POST", base+"/modification", map[string]string{"nom": "Sortie du matin", "destination": "Groix"}); rec.Code != 303 {
		t.Fatalf("renommer en cours : %d", rec.Code)
	}
	if rec := web.envoyerFichier(base+"/ajouts", map[string]string{"texte": "x"}, nil); rec.Code != 422 {
		t.Fatalf("ajout en cours : %d", rec.Code)
	}
	fin := t0.Add(3 * time.Hour)
	if c, x := e.appel("PUT", "/navigations/"+id+"/fin", nav, map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(fin)}); c != 200 {
		t.Fatalf("fin : %d %v", c, x)
	}
	_, n := e.appel("GET", "/navigations/"+id, nav, nil)
	if n["nom"] != "Sortie du matin" || n["destination"].(map[string]any)["texte"] != "Glénan" {
		t.Fatalf("après renommage : %v", n)
	}

	// Terminée : destination et fin changées, début gardé à la seconde.
	if rec := web.envoyer("POST", base+"/modification", map[string]string{"nom": "Sortie du matin", "destination": "Groix",
		"bateauId": bateau, "debut": "2026-11-20T08:00", "fin": "2026-11-20T11:30"}); rec.Code != 303 {
		t.Fatalf("modification : %d %s", rec.Code, rec.Body.String())
	}
	_, n = e.appel("GET", "/navigations/"+id, nav, nil)
	memeHeure := func(v any, attendu string) bool {
		a, err1 := time.Parse(time.RFC3339, v.(string))
		b, err2 := time.Parse(time.RFC3339, attendu)
		return err1 == nil && err2 == nil && a.Equal(b)
	}
	if n["destination"].(map[string]any)["texte"] != "Groix" || !memeHeure(n["debut"], "2026-11-20T07:00:37Z") || !memeHeure(n["fin"], "2026-11-20T10:30:00Z") {
		t.Fatalf("après modification : %v", n)
	}
	if rec := web.envoyer("POST", base+"/modification", map[string]string{"nom": "Sortie du matin", "debut": "2026-11-20T08:00", "fin": "2026-11-20T07:00"}); rec.Code != 422 ||
		!strings.Contains(rec.Body.String(), "La fin ne peut pas précéder le début.") {
		t.Fatalf("fin avant le début : %d", rec.Code)
	}

	// Note modifiée puis supprimée ; positions et début intouchables (RG-JRN-07).
	if rec := web.envoyer("POST", base+"/evenements/"+note, map[string]string{"texte": "Deux ris pris"}); rec.Code != 303 {
		t.Fatalf("modification de la note : %d", rec.Code)
	}
	_, j := e.appel("GET", "/navigations/"+id+"/evenements", nav, nil)
	var debutID string
	for _, x := range j["evenements"].([]any) {
		ev := x.(map[string]any)
		if ev["id"] == note && ev["texte"] != "Deux ris pris" {
			t.Fatalf("note : %v", ev)
		}
		if ev["type"] == "debut" {
			debutID = ev["id"].(string)
		}
	}
	if rec := web.envoyer("POST", base+"/evenements/"+debutID, map[string]string{"texte": "x"}); rec.Code != 403 {
		t.Fatalf("modification du début : %d", rec.Code)
	}
	if rec := web.envoyer("POST", base+"/evenements/"+debutID+"/suppression", map[string]string{"confirmation": "on"}); rec.Code != 403 {
		t.Fatalf("suppression du début : %d", rec.Code)
	}
	if rec := web.envoyer("POST", base+"/evenements/"+note+"/suppression", map[string]string{"confirmation": "on"}); rec.Code != 303 {
		t.Fatalf("suppression de la note : %d", rec.Code)
	}

	// Ajouts : texte, photo, note vocale, à l'heure où ils sont faits, après
	// la fin, sans être masqués (RG-JRN-05, D-152) ; une heure envoyée par le
	// formulaire est ignorée.
	ajout := time.Date(2026, 11, 22, 18, 45, 12, 0, time.UTC)
	horloge(e, ajout)
	if rec := web.envoyerFichier(base+"/ajouts", map[string]string{"texte": "Escale à Port-Tudy", "heure": "2026-11-20T09:15"}, nil); rec.Code != 303 {
		t.Fatalf("ajout de texte : %d %s", rec.Code, rec.Body.String())
	}
	if rec := web.envoyerFichier(base+"/ajouts", nil, jpegEssai); rec.Code != 303 {
		t.Fatalf("ajout de photo : %d %s", rec.Code, rec.Body.String())
	}
	if rec := web.envoyerFichier(base+"/ajouts", nil, m4aEssai(30)); rec.Code != 303 {
		t.Fatalf("ajout de note vocale : %d %s", rec.Code, rec.Body.String())
	}
	_, j = e.appel("GET", "/navigations/"+id+"/evenements", nav, nil)
	evts := j["evenements"].([]any)
	for _, x := range evts[len(evts)-3:] {
		ev := x.(map[string]any)
		if ev["type"] != "ajout" || !memeHeure(ev["heureAcquisition"], heure(ajout)) || ev["masque"] != false {
			t.Fatalf("ajout à la fin du journal, à l'heure de l'ajout : %v", ev)
		}
	}
	if rec := web.envoyerFichier(base+"/ajouts", nil, m4aEssai(90)); rec.Code != 422 {
		t.Fatalf("note vocale trop longue : %d", rec.Code)
	}
	if rec := web.envoyerFichier(base+"/ajouts", nil, nil); rec.Code != 422 {
		t.Fatalf("ajout vide : %d", rec.Code)
	}
	if nb := e.compter(`SELECT count(*) FROM evenements e JOIN fichiers f ON f.evenement_id = e.id
		WHERE e.navigation_id = $1 AND e.type = 'ajout' AND e.origine = 'web'`, id); nb != 2 {
		t.Fatalf("fichiers des ajouts : %d", nb)
	}
	page := web.envoyer("GET", base, nil).Body.String()
	if !strings.Contains(page, "Escale à Port-Tudy") || !strings.Contains(page, "Ajout complémentaire") || strings.Contains(page, "Deux ris pris") {
		t.Fatalf("journal après les ajouts : %s", page)
	}

	// Suiveur : rien de modifiable.
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	webLea := e.webConnecte("lea@exemple.org")
	if rec := webLea.envoyer("POST", base+"/modification", map[string]string{"nom": "Pirate"}); rec.Code != 403 {
		t.Fatalf("modification par un suiveur : %d", rec.Code)
	}
	if rec := webLea.envoyerFichier(base+"/ajouts", map[string]string{"texte": "x"}, nil); rec.Code != 403 {
		t.Fatalf("ajout par un suiveur : %d", rec.Code)
	}
}
