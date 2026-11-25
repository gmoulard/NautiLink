package main

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

const (
	appareil1 = "11111111-1111-4111-8111-111111111111"
	appareil2 = "22222222-2222-4222-8222-222222222222"
)

var jpegEssai = append([]byte{0xFF, 0xD8, 0xFF, 0xE0}, bytes.Repeat([]byte{1}, 100)...)

func TestBateaux(t *testing.T) {
	e := nouvelEssai(t)
	j := e.compte("marin@exemple.org", "Marin")
	autre := e.compte("autre@exemple.org", "Autre")

	if code, _ := e.appel("POST", "/bateaux", j, map[string]any{"nom": "Alizé"}); code != 422 {
		t.Fatalf("sans type : %d", code)
	}
	if code, _ := e.appel("POST", "/bateaux", j, map[string]any{"nom": "Alizé", "type": "voilier", "longueurMetres": -2}); code != 422 {
		t.Fatalf("longueur négative : %d", code)
	}
	// Plusieurs bateaux par compte (RG-CPT-04), fiche complète (RG-BAT-01).
	code, b1 := e.appel("POST", "/bateaux", j, map[string]any{"nom": "Alizé", "type": "voilier", "longueurMetres": 9.5,
		"immatriculation": "TL 123456", "portAttache": "Toulon", "moteur": "Yanmar 20 ch", "autonomie": "200 milles",
		"capaciteCarburantLitres": 40, "vitesseNoeuds": 6.5, "tirantEauMetres": 1.6})
	if code != 201 || b1["proprietaireId"] != e.id(j) || b1["longueurMetres"] != 9.5 || b1["aUnePhoto"] != false {
		t.Fatalf("création : %d %v", code, b1)
	}
	_, b2 := e.appel("POST", "/bateaux", j, map[string]any{"nom": "Mistral", "type": "moteur"})
	id1, id2 := b1["id"].(string), b2["id"].(string)
	if _, l := e.liste("GET", "/bateaux", j, nil); len(l) != 2 {
		t.Fatalf("liste : %v", l)
	}
	if _, l := e.liste("GET", "/bateaux", autre, nil); len(l) != 0 {
		t.Fatal("bateaux d'un autre compte visibles")
	}
	// Modification partielle : les autres champs restent (RG-COM-04).
	code, b1 = e.appel("PATCH", "/bateaux/"+id1, j, map[string]any{"portAttache": "Porquerolles", "vitesseNoeuds": nil})
	if code != 200 || b1["portAttache"] != "Porquerolles" || b1["immatriculation"] != "TL 123456" || b1["vitesseNoeuds"] != nil {
		t.Fatalf("modification : %d %v", code, b1)
	}
	// Un autre compte ne voit ni ne modifie le bateau.
	if code, _ := e.appel("GET", "/bateaux/"+id1, autre, nil); code != 404 {
		t.Fatalf("fiche vue par un autre compte : %d", code)
	}
	if code, _ := e.appel("PATCH", "/bateaux/"+id1, autre, map[string]any{"nom": "Volé"}); code != 404 {
		t.Fatalf("fiche modifiée par un autre compte : %d", code)
	}
	if code, _ := e.appel("GET", "/bateaux/pas-un-uuid", j, nil); code != 404 {
		t.Fatalf("identifiant mal formé : %d", code)
	}

	// Photo.
	req := httptest.NewRequest("PUT", "/nautilink/api/v1/bateaux/"+id1+"/photo", bytes.NewReader([]byte("pas une photo")))
	req.Header.Set("Authorization", "Bearer "+j)
	req.Header.Set("Content-Type", "image/jpeg")
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != 422 {
		t.Fatalf("photo qui n'est pas un JPEG : %d", rec.Code)
	}
	req = httptest.NewRequest("PUT", "/nautilink/api/v1/bateaux/"+id1+"/photo", bytes.NewReader(jpegEssai))
	req.Header.Set("Authorization", "Bearer "+j)
	req.Header.Set("Content-Type", "image/jpeg")
	rec = httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != 204 {
		t.Fatalf("photo : %d %s", rec.Code, rec.Body.String())
	}
	if code, corps := e.appelBrut("GET", "/bateaux/"+id1+"/photo", j, nil); code != 200 || !bytes.Equal(corps, jpegEssai) {
		t.Fatalf("lecture de la photo : %d", code)
	}
	if code, _ := e.appelBrut("GET", "/bateaux/"+id2+"/photo", j, nil); code != 404 {
		t.Fatalf("bateau sans photo : %d", code)
	}

	// Téléphones (RG-BAT-02) : un téléphone peut servir plusieurs bateaux du
	// compte ; associer un autre téléphone remplace le précédent.
	if code, _ := e.appel("PUT", "/appareils/"+appareil1, j, map[string]any{"plateforme": "windows"}); code != 422 {
		t.Fatalf("plateforme inconnue : %d", code)
	}
	if code, ap := e.appel("PUT", "/appareils/"+appareil1, j, map[string]any{"plateforme": "android", "nom": "Pixel 8", "jetonPush": "fcm-1"}); code != 200 || ap["nom"] != "Pixel 8" {
		t.Fatalf("appareil : %d %v", code, ap)
	}
	e.appel("PUT", "/appareils/"+appareil2, j, map[string]any{"plateforme": "ios"})
	if code, _ := e.appel("PUT", "/appareils/"+appareil1, autre, map[string]any{"plateforme": "android"}); code != 403 {
		t.Fatalf("téléphone d'un autre compte : %d", code)
	}
	var appareilSession *string
	_ = e.a.b.pool.QueryRow(t.Context(), "SELECT appareil_id::text FROM sessions WHERE jeton_acces = $1", empreinte(j)).Scan(&appareilSession)
	if appareilSession == nil || *appareilSession != appareil2 {
		t.Fatalf("session non rattachée au téléphone : %v", appareilSession)
	}
	if _, b := e.appel("PUT", "/bateaux/"+id1+"/telephone", j, map[string]string{"appareilId": appareil1}); b["appareilAssocieId"] != appareil1 {
		t.Fatalf("association : %v", b)
	}
	if _, b := e.appel("PUT", "/bateaux/"+id2+"/telephone", j, map[string]string{"appareilId": appareil1}); b["appareilAssocieId"] != appareil1 {
		t.Fatalf("même téléphone, deuxième bateau : %v", b)
	}
	if _, b := e.appel("PUT", "/bateaux/"+id1+"/telephone", j, map[string]string{"appareilId": appareil2}); b["appareilAssocieId"] != appareil2 {
		t.Fatalf("remplacement : %v", b)
	}
	e.appel("PUT", "/appareils/"+"33333333-3333-4333-8333-333333333333", autre, map[string]any{"plateforme": "android"})
	if code, _ := e.appel("PUT", "/bateaux/"+id1+"/telephone", j, map[string]string{"appareilId": "33333333-3333-4333-8333-333333333333"}); code != 403 {
		t.Fatalf("téléphone d'un autre compte associé : %d", code)
	}

	// Seul le propriétaire démarre une navigation avec ce bateau (RG-CPT-05).
	if ok, _ := e.a.peutDemarrer(t.Context(), e.id(j), id1); !ok {
		t.Fatal("le propriétaire ne peut pas démarrer")
	}
	if ok, _ := e.a.peutDemarrer(t.Context(), e.id(autre), id1); ok {
		t.Fatal("un autre compte peut démarrer")
	}
}

func TestPagesWebBateaux(t *testing.T) {
	e := nouvelEssai(t)
	n := e.navigateur()
	n.envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Paul", "email": "paul@exemple.org",
		"motdepasse": "motdepasse", "avertissement": versionAvertissement})
	if rec := n.envoyer("GET", "/nautilink/bateaux", nil); rec.Code != 200 || !strings.Contains(rec.Body.String(), "pas encore de bateau") {
		t.Fatalf("liste vide : %d", rec.Code)
	}
	rec := n.envoyer("POST", "/nautilink/bateaux", map[string]string{"nom": "Alizé", "type": "voilier", "longueurMetres": "abc"})
	if rec.Code != 422 || !strings.Contains(rec.Body.String(), "Alizé") {
		t.Fatalf("saisie invalide : %d", rec.Code)
	}
	rec = n.envoyer("POST", "/nautilink/bateaux", map[string]string{"nom": "Alizé", "type": "voilier", "longueurMetres": "9,5", "portAttache": "Toulon"})
	if rec.Code != 303 {
		t.Fatalf("ajout : %d %s", rec.Code, rec.Body.String())
	}
	fiche := strings.Split(rec.Header().Get("Location"), "?")[0]
	if rec := n.envoyer("GET", fiche, nil); !strings.Contains(rec.Body.String(), `value="9,5"`) || !strings.Contains(rec.Body.String(), "Aucun téléphone") {
		t.Fatalf("fiche : %s", rec.Body.String())
	}
	if rec := n.envoyer("POST", fiche, map[string]string{"nom": "Alizé II", "type": "voilier"}); rec.Code != 303 {
		t.Fatalf("modification : %d", rec.Code)
	}
	// Photo envoyée par le formulaire.
	var corps bytes.Buffer
	mp := multipart.NewWriter(&corps)
	p, _ := mp.CreateFormFile("photo", "bateau.jpg")
	p.Write(jpegEssai)
	mp.Close()
	req := httptest.NewRequest("POST", fiche+"/photo", &corps)
	req.Header.Set("Content-Type", mp.FormDataContentType())
	for _, c := range n.cookies {
		req.AddCookie(c)
	}
	rr := httptest.NewRecorder()
	e.h.ServeHTTP(rr, req)
	if rr.Code != http.StatusSeeOther {
		t.Fatalf("photo : %d %s", rr.Code, rr.Body.String())
	}
	if rec := n.envoyer("GET", fiche, nil); !strings.Contains(rec.Body.String(), "/photo\" alt=") {
		t.Fatal("photo non affichée")
	}
	if rec := n.envoyer("GET", "/nautilink/api/v1/bateaux/"+strings.TrimPrefix(fiche, "/nautilink/bateaux/")+"/photo", nil); rec.Code != 200 {
		t.Fatalf("photo par cookie : %d", rec.Code)
	}
	// Fiche d'un autre compte : introuvable.
	n2 := e.navigateur()
	n2.envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Eve", "email": "eve@exemple.org",
		"motdepasse": "motdepasse", "avertissement": versionAvertissement})
	if rec := n2.envoyer("GET", fiche, nil); rec.Code != 404 {
		t.Fatalf("fiche d'un autre compte : %d", rec.Code)
	}
}
