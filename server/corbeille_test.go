package main

import (
	"strings"
	"testing"
	"time"
)

// webConnecte : client Web connecté avec ce compte (session « web »).
func (e *essai) webConnecte(email string) *navigateurWeb {
	e.t.Helper()
	web := e.navigateur()
	if rec := web.envoyer("POST", "/nautilink/connexion", map[string]string{"email": email, "motdepasse": "motdepasse"}); rec.Code != 303 {
		e.t.Fatalf("connexion Web : %d", rec.Code)
	}
	return web
}

func (e *essai) compter(requete string, args ...any) int {
	e.t.Helper()
	var n int
	if err := e.a.b.pool.QueryRow(e.t.Context(), requete, args...).Scan(&n); err != nil {
		e.t.Fatal(err)
	}
	return n
}

// TestCorbeille : RG-NAV-20, RG-NAV-21 (TS-NAV-21), Q-70, Q-71.
func TestCorbeille(t *testing.T) {
	e := nouvelEssai(t)
	t0 := time.Date(2026, 11, 16, 8, 0, 0, 0, time.UTC)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	web := e.webConnecte("nav@exemple.org")

	// Navigation en cours : pas de suppression.
	horloge(e, t0)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, nil)
	apiWeb := func(methode, chemin string) int {
		return web.envoyer(methode, "/nautilink/api/v1"+chemin, nil).Code
	}
	if code := apiWeb("DELETE", "/navigations/"+id); code != 409 {
		t.Fatalf("navigation en cours : %d", code)
	}
	fin := t0.Add(2 * time.Hour)
	if c, x := e.appel("PUT", "/navigations/"+id+"/fin", nav, map[string]any{"id": uuid(t), "type": "fin",
		"heureAcquisition": heure(fin)}); c != 200 {
		t.Fatalf("fin : %d %v", c, x)
	}
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	bob := e.compte("bob@exemple.org", "Bob")
	e.suivre(nav, bob, "bob@exemple.org", "navigation", id)

	// Depuis le Web seulement, et par le navigateur seulement.
	suppression := t0.Add(3 * time.Hour)
	horloge(e, suppression)
	if code, r := e.appel("DELETE", "/navigations/"+id, nav, nil); code != 403 || r["code"] != "web_seulement" {
		t.Fatalf("suppression depuis le téléphone : %d %v", code, r)
	}
	webLea := e.webConnecte("lea@exemple.org")
	if code := webLea.envoyer("DELETE", "/nautilink/api/v1/navigations/"+id, nil).Code; code != 403 {
		t.Fatalf("suppression par un suiveur : %d", code)
	}
	if code := apiWeb("DELETE", "/navigations/"+id); code != 204 {
		t.Fatalf("mise à la corbeille : %d", code)
	}

	// Suiveurs sans accès ; absente des listes du navigateur.
	for _, j := range []string{lea, bob} {
		if code, _ := e.appel("GET", "/navigations/"+id, j, nil); code != 404 {
			t.Fatalf("suiveur, navigation dans la corbeille : %d", code)
		}
	}
	if _, l := e.appel("GET", "/navigations?role=suiveur", lea, nil); len(l["navigations"].([]any)) != 0 {
		t.Fatalf("liste du suiveur : %v", l)
	}
	if _, l := e.appel("GET", "/navigations", nav, nil); len(l["navigations"].([]any)) != 0 {
		t.Fatalf("liste du navigateur : %v", l)
	}
	definitive := heure(suppression.Add(30 * 24 * time.Hour))
	_, c := e.liste("GET", "/corbeille", nav, nil)
	if len(c) != 1 || c[0]["id"] != id || c[0]["etat"] != "corbeille" || c[0]["supprimeeDefinitivementLe"] != definitive {
		t.Fatalf("corbeille : %v", c)
	}
	if _, c := e.liste("GET", "/corbeille", lea, nil); len(c) != 0 {
		t.Fatalf("corbeille du suiveur : %v", c)
	}

	// Page visible du navigateur, sans modification ; les envois du
	// téléphone restent acceptés (Q-70).
	if code, n := e.appel("GET", "/navigations/"+id, nav, nil); code != 200 || n["etat"] != "corbeille" {
		t.Fatalf("page dans la corbeille : %d %v", code, n)
	}
	if code, r := e.appel("PATCH", "/navigations/"+id, nav, map[string]any{"nom": "Autre"}); code != 409 || r["code"] != "navigation_corbeille" {
		t.Fatalf("modification dans la corbeille : %d %v", code, r)
	}
	p := uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+p, nav, position(p, t0.Add(time.Hour), 5, 47, -3)); code != 201 {
		t.Fatalf("envoi en attente du téléphone : %d", code)
	}

	// Temps toujours décompté du quota (RG-NAV-21).
	if _, q := e.appel("GET", "/quota", nav, nil); q["consommeMinutes"] != 120.0 {
		t.Fatalf("quota : %v", q)
	}

	// Rejouée plus tard : la date de suppression définitive ne bouge pas.
	horloge(e, suppression.Add(24*time.Hour))
	if code := apiWeb("DELETE", "/navigations/"+id); code != 204 {
		t.Fatalf("suppression rejouée : %d", code)
	}
	if _, c := e.liste("GET", "/corbeille", nav, nil); len(c) != 1 || c[0]["supprimeeDefinitivementLe"] != definitive {
		t.Fatalf("corbeille après une suppression rejouée : %v", c)
	}

	// Restauration dans les 30 jours : les suiveurs retrouvent l'accès.
	horloge(e, suppression.Add(29*24*time.Hour))
	if code, n := e.appel("POST", "/navigations/"+id+"/restauration", nav, nil); code != 200 || n["etat"] != "terminee" {
		t.Fatalf("restauration : %d %v", code, n)
	}
	if code, _ := e.appel("POST", "/navigations/"+id+"/restauration", nav, nil); code != 404 {
		t.Fatalf("restauration hors corbeille : %d", code)
	}
	for _, j := range []string{lea, bob} {
		if code, _ := e.appel("GET", "/navigations/"+id, j, nil); code != 200 {
			t.Fatalf("suiveur après restauration : %d", code)
		}
	}

	// Seconde mise à la corbeille ; restauration refusée par un autre
	// compte, puis après 30 jours ; suppression définitive par la tâche.
	suppression = suppression.Add(29 * 24 * time.Hour)
	if code := apiWeb("DELETE", "/navigations/"+id); code != 204 {
		t.Fatalf("seconde mise à la corbeille : %d", code)
	}
	if code, _ := e.appel("POST", "/navigations/"+id+"/restauration", lea, nil); code != 404 {
		t.Fatalf("restauration par un suiveur : %d", code)
	}
	horloge(e, suppression.Add(30*24*time.Hour-time.Minute))
	if err := e.a.purgerLaCorbeille(t.Context()); err != nil {
		t.Fatal(err)
	}
	if e.compter("SELECT count(*) FROM navigations WHERE id = $1", id) != 1 {
		t.Fatal("navigation supprimée avant 30 jours")
	}
	horloge(e, suppression.Add(30*24*time.Hour))
	if code, _ := e.appel("POST", "/navigations/"+id+"/restauration", nav, nil); code != 404 {
		t.Fatalf("restauration après 30 jours : %d", code)
	}
	if _, c := e.liste("GET", "/corbeille", nav, nil); len(c) != 0 {
		t.Fatalf("corbeille après 30 jours : %v", c)
	}
	if err := e.a.purgerLaCorbeille(t.Context()); err != nil {
		t.Fatal(err)
	}
	if e.compter("SELECT count(*) FROM navigations WHERE id = $1", id) != 0 ||
		e.compter("SELECT count(*) FROM evenements WHERE navigation_id = $1", id) != 0 {
		t.Fatal("navigation gardée après 30 jours")
	}
	// Accès de périmètre navigation retiré (Q-71) ; périmètre navigateur gardé.
	if e.compter("SELECT count(*) FROM acces WHERE navigation_id = $1", id) != 0 ||
		e.compter("SELECT count(*) FROM acces WHERE perimetre = 'navigateur'") != 1 {
		t.Fatal("accès après la suppression définitive")
	}
	if code, _ := e.appel("GET", "/navigations/"+id, nav, nil); code != 404 {
		t.Fatalf("navigation supprimée définitivement : %d", code)
	}
}

func TestDateFrancaise(t *testing.T) {
	for d, attendu := range map[time.Time]string{
		time.Date(2026, 12, 25, 12, 0, 0, 0, time.UTC): "25 décembre 2026",
		time.Date(2026, 7, 31, 23, 30, 0, 0, time.UTC): "1er août 2026", // heure de Paris
	} {
		if got := dateFrancaise(d); got != attendu {
			t.Errorf("%v : %q", d, got)
		}
	}
}

func TestCorbeilleWeb(t *testing.T) {
	e := nouvelEssai(t)
	t0 := time.Date(2026, 11, 16, 8, 0, 0, 0, time.UTC)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	horloge(e, t0)
	fin := t0.Add(time.Hour)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, &fin)
	horloge(e, t0.Add(2*time.Hour))
	web := e.webConnecte("nav@exemple.org")
	if page := web.envoyer("GET", "/nautilink/corbeille", nil).Body.String(); !strings.Contains(page, "La corbeille est vide.") {
		t.Fatalf("corbeille vide : %s", page)
	}
	rec := web.envoyer("POST", "/nautilink/navigations/"+id+"/suppression", map[string]string{})
	if rec.Code != 303 || rec.Header().Get("Location") != "/nautilink/corbeille?ok=corbeille" {
		t.Fatalf("suppression : %d %s", rec.Code, rec.Header().Get("Location"))
	}
	page := web.envoyer("GET", "/nautilink/corbeille?ok=corbeille", nil).Body.String()
	for _, attendu := range []string{"Alizé — Glénan", "16 novembre 2026", "le 16 décembre 2026", "Restaurer", "restaurer pendant 30 jours"} {
		if !strings.Contains(page, attendu) {
			t.Fatalf("page de la corbeille sans %q : %s", attendu, page)
		}
	}
	if rec := web.envoyer("POST", "/nautilink/corbeille/"+id+"/restauration", map[string]string{}); rec.Code != 303 {
		t.Fatalf("restauration : %d", rec.Code)
	}
	if code, n := e.appel("GET", "/navigations/"+id, nav, nil); code != 200 || n["etat"] != "terminee" {
		t.Fatalf("après restauration : %d %v", code, n)
	}
	if rec := web.envoyer("POST", "/nautilink/corbeille/"+id+"/restauration", map[string]string{}); rec.Code != 404 {
		t.Fatalf("restauration hors corbeille : %d", rec.Code)
	}
}
