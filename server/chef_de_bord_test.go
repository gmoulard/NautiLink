package main

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// TestChefDeBordTexte : RG-NAV-36 : texte libre, vide pour le navigateur.
func TestChefDeBordTexte(t *testing.T) {
	vide, blanc, long := "", "   ", strings.Repeat("é", 201)
	for _, c := range []*string{nil, &vide, &blanc} {
		if v, err := texteChef(c); err != nil || v != nil {
			t.Errorf("texteChef(%v) = %v, %v", c, v, err)
		}
	}
	nom := "  Léa Marin "
	if v, err := texteChef(&nom); err != nil || *v != "Léa Marin" {
		t.Errorf("texteChef : %v, %v", v, err)
	}
	if _, err := texteChef(&long); err == nil {
		t.Error("201 caractères acceptés")
	}
	if chefDeBord(navLigne{}, "Paul") != "Paul" || chefDeBord(navLigne{chef: &nom}, "Paul") != nom {
		t.Error("chefDeBord : navigateur par défaut, sinon le chef saisi")
	}
	n := navLigne{nom: "Alizé", debut: time.Now()}
	r := formulaireEssai(url.Values{"nom": {"Alizé"}, "chefDeBord": {"Paul"}})
	if c, err := champsModifies(r, n, "Paul"); err != nil || len(c) != 0 {
		t.Errorf("chef inchangé : %v %v", c, err)
	}
	r = formulaireEssai(url.Values{"nom": {"Alizé"}, "chefDeBord": {" Léa "}})
	if c, _ := champsModifies(r, n, "Paul"); string(c["chefDeBord"]) != `"Léa"` {
		t.Errorf("chef changé : %v", c)
	}
}

// TestChefDeBordRendu : page, PDF et e-mail SOS (RG-NAV-36, RG-SOS-07).
func TestChefDeBordRendu(t *testing.T) {
	d := donneesNavEssai(true, true)
	nav := d.D.(donneesNavigation)
	nav.N.ChefDeBord = "Léa Marin"
	nav.Modifier = &modificationNav{Nom: nav.N.Nom}
	d.D = nav
	page := rendu(t, "navigation.html", d)
	for _, attendu := range []string{"Chef de bord</dt><dd>Léa Marin", `name="chefDeBord"`, `value="Léa Marin"`} {
		if !strings.Contains(page, attendu) {
			t.Errorf("%q absent de la page", attendu)
		}
	}
	_, texte := texteSos(donneesSos{navigateur: "Paul", chef: "Léa Marin", bateau: bateauJSON{Nom: "Alizé"}}, "")
	if !strings.Contains(texte, "Chef de bord : Léa Marin") {
		t.Errorf("e-mail SOS sans le chef de bord : %s", texte)
	}
	if _, texte := texteSos(donneesSos{navigateur: "Paul", bateau: bateauJSON{Nom: "Alizé"}}, ""); strings.Contains(texte, "Chef de bord") {
		t.Error("SOS hors navigation : chef de bord affiché")
	}
}

// TestChefDeBordAPI : avec PostgreSQL : chefDeBord au démarrage, par défaut
// le navigateur, modifiable pendant la navigation (API et Web), dans
// l'e-mail SOS et le PDF.
func TestChefDeBordAPI(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Paul", "Alizé")
	t0 := time.Now().Add(-time.Hour).Truncate(time.Second)
	id := uuid(t)
	d := demarrage(bateau, tel, t0, 47.7, -3.36)
	d["debut"].(map[string]any)["id"] = uuid(t)
	d["chefDeBord"] = "  Léa Marin "
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d); code != 201 || r["chefDeBord"] != "Léa Marin" {
		t.Fatalf("démarrage : %d %v", code, r)
	}
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d); code != 200 || r["chefDeBord"] != "Léa Marin" {
		t.Fatalf("renvoi : %d %v", code, r)
	}
	if code, r := e.appel("PATCH", "/navigations/"+id, nav, map[string]any{"chefDeBord": ""}); code != 200 || r["chefDeBord"] != "Paul" {
		t.Fatalf("chef effacé : %d %v", code, r)
	}
	web := e.webConnecte("nav@exemple.org")
	if rec := web.envoyer("POST", "/nautilink/navigations/"+id+"/modification", map[string]string{"nom": "Alizé — Glénan", "chefDeBord": "Jean"}); rec.Code != 303 {
		t.Fatalf("modification Web : %d %s", rec.Code, rec.Body.String())
	}
	if _, r := e.appel("GET", "/navigations/"+id, nav, nil); r["chefDeBord"] != "Jean" {
		t.Fatalf("après la modification Web : %v", r)
	}
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	if rec := web.envoyer("POST", "/nautilink/sos", map[string]string{"navigationId": id}); rec.Code != 303 {
		t.Fatalf("SOS : %d", rec.Code)
	}
	if !strings.Contains(e.courrier.dernier(t, "lea@exemple.org"), "Chef de bord : Jean") {
		t.Fatal("e-mail SOS sans le chef de bord")
	}
	if pdf := web.envoyer("GET", "/nautilink/navigations/"+id+"/pdf", nil); pdf.Code != 200 || !strings.Contains(textePDF(t, pdf.Body.Bytes()), "Chef de bord : Jean") {
		t.Fatalf("PDF : %d", pdf.Code)
	}
}

func formulaireEssai(v url.Values) *http.Request {
	r := httptest.NewRequest("POST", "/", strings.NewReader(v.Encode()))
	r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	_ = r.ParseForm()
	return r
}
