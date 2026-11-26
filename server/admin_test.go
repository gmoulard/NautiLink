package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// adminAppel : appel de l'API d'administration avec le cookie de l'espace
// administrateur du navigateur n.
func (n *navigateurWeb) adminAppel(methode, chemin string, corps any) (int, []byte) {
	n.e.t.Helper()
	var r *bytes.Reader
	if corps != nil {
		b, _ := json.Marshal(corps)
		r = bytes.NewReader(b)
	} else {
		r = bytes.NewReader(nil)
	}
	req := httptest.NewRequest(methode, "/nautilink/api/v1"+chemin, r)
	for _, c := range n.cookies {
		req.AddCookie(c)
	}
	rec := httptest.NewRecorder()
	n.e.h.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

func (e *essai) confirmerEmail(email string) {
	e.t.Helper()
	if _, err := e.a.b.pool.Exec(e.t.Context(), "UPDATE utilisateurs SET email_verifie_le = now() WHERE email = $1", email); err != nil {
		e.t.Fatal(err)
	}
}

func TestEspaceAdministrateur(t *testing.T) {
	e := nouvelEssai(t)
	e.a.cfg.Admins = []string{"admin@exemple.org"}
	e.h = e.a.routeur()

	jAdmin := e.compte("admin@exemple.org", "Admin")
	jMarin := e.compte("marin@exemple.org", "Marin")
	e.compte("autre@exemple.org", "Autre")
	_ = jAdmin
	code, b := e.appel("POST", "/bateaux", jMarin, map[string]any{"nom": "Alizé", "type": "voilier"})
	if code != http.StatusCreated {
		t.Fatalf("bateau : %d %v", code, b)
	}
	bateau := b["id"].(string)

	n := e.navigateur()
	// Espace distinct : sans session administrateur, renvoi vers sa connexion ;
	// la session de l'Application web ne suffit pas.
	if rec := n.envoyer("GET", "/nautilink/admin/", nil); rec.Code != http.StatusSeeOther ||
		rec.Header().Get("Location") != "/nautilink/admin/connexion" {
		t.Fatalf("sans session : %d %q", rec.Code, rec.Header().Get("Location"))
	}
	if code, _ := e.appelBrut("GET", "/admin/utilisateurs", jAdmin, nil); code != http.StatusUnauthorized {
		t.Fatalf("jeton utilisateur sur l'API admin : %d", code)
	}
	// Adresse non confirmée : refus ; compte non listé : refus.
	if rec := n.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "admin@exemple.org", "motdepasse": "motdepasse"}); rec.Code != http.StatusUnauthorized {
		t.Fatalf("adresse non confirmée : %d", rec.Code)
	}
	e.confirmerEmail("admin@exemple.org")
	e.confirmerEmail("marin@exemple.org")
	if rec := n.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "marin@exemple.org", "motdepasse": "motdepasse"}); rec.Code != http.StatusUnauthorized {
		t.Fatalf("non administrateur : %d", rec.Code)
	}
	if rec := n.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "admin@exemple.org", "motdepasse": "faux"}); rec.Code != http.StatusUnauthorized {
		t.Fatalf("mot de passe faux : %d", rec.Code)
	}
	if rec := n.envoyer("POST", "/nautilink/admin/connexion", map[string]string{"email": "admin@exemple.org", "motdepasse": "motdepasse"}); rec.Code != http.StatusSeeOther {
		t.Fatalf("connexion : %d %s", rec.Code, rec.Body.String())
	}
	if _, ok := n.cookies[nomCookieAdmin]; !ok {
		t.Fatal("cookie nautilink_admin absent")
	}

	// Pages.
	for _, p := range []string{"/", "/utilisateurs?recherche=marin", "/bateaux", "/bateaux/" + bateau, "/annonces", "/journal"} {
		if rec := n.envoyer("GET", "/nautilink/admin"+p, nil); rec.Code != http.StatusOK {
			t.Fatalf("page %s : %d %s", p, rec.Code, rec.Body.String())
		}
	}
	rec := n.envoyer("GET", "/nautilink/admin/utilisateurs?recherche=marin", nil)
	if !strings.Contains(rec.Body.String(), "marin@exemple.org") || strings.Contains(rec.Body.String(), "autre@exemple.org") {
		t.Fatal("recherche des utilisateurs")
	}
	marin := e.id(jMarin)
	if rec := n.envoyer("GET", "/nautilink/admin/utilisateurs/"+marin, nil); !strings.Contains(rec.Body.String(), "Alizé") {
		t.Fatal("fiche utilisateur sans son bateau")
	}

	// Modification d'un utilisateur.
	if rec := n.envoyer("POST", "/nautilink/admin/utilisateurs/"+marin, map[string]string{"nom": "Marin Modifié", "telephone": ""}); rec.Code != http.StatusSeeOther {
		t.Fatalf("modification : %d %s", rec.Code, rec.Body.String())
	}
	if _, p := e.appel("GET", "/compte", jMarin, nil); p["nom"] != "Marin Modifié" {
		t.Fatalf("nom non modifié : %v", p["nom"])
	}

	// Rattachement du bateau à un autre compte (API).
	code, brut := n.adminAppel("PATCH", "/admin/bateaux/"+bateau, map[string]string{"proprietaireEmail": "autre@exemple.org", "portAttache": "Brest"})
	if code != http.StatusOK || !strings.Contains(string(brut), `"proprietaireEmail":"autre@exemple.org"`) || !strings.Contains(string(brut), "Brest") {
		t.Fatalf("rattachement : %d %s", code, brut)
	}

	// Annonces : publication, bandeau, fermeture par l'utilisateur.
	if rec := n.envoyer("POST", "/nautilink/admin/annonces", map[string]string{"texte": "Maintenance dimanche", "fin": ""}); rec.Code != http.StatusSeeOther {
		t.Fatalf("annonce : %d %s", rec.Code, rec.Body.String())
	}
	code, l := e.liste("GET", "/annonces", jMarin, nil)
	if code != 200 || len(l) != 1 || l[0]["texte"] != "Maintenance dimanche" {
		t.Fatalf("annonces vues : %d %v", code, l)
	}
	web := e.navigateur()
	web.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "marin@exemple.org", "motdepasse": "motdepasse"})
	if rec := web.envoyer("GET", "/nautilink/", nil); !strings.Contains(rec.Body.String(), "Maintenance dimanche") {
		t.Fatal("bandeau absent du tableau de bord")
	}
	if code, _ := e.appelBrut("POST", "/annonces/"+l[0]["id"].(string)+"/fermeture", jMarin, nil); code != http.StatusNoContent {
		t.Fatalf("fermeture : %d", code)
	}
	if _, l := e.liste("GET", "/annonces", jMarin, nil); len(l) != 0 {
		t.Fatal("annonce fermée encore affichée")
	}
	if _, l := e.liste("GET", "/annonces", jAdmin, nil); len(l) != 1 {
		t.Fatal("annonce fermée pour tous")
	}
	// Annonce terminée : plus affichée.
	code, brut = n.adminAppel("POST", "/admin/annonces", map[string]any{"texte": "Ancienne", "finLe": "2020-01-01T00:00:00Z"})
	if code != http.StatusCreated {
		t.Fatalf("annonce passée : %d %s", code, brut)
	}
	if _, l := e.liste("GET", "/annonces", jAdmin, nil); len(l) != 1 {
		t.Fatal("annonce terminée affichée")
	}

	// Fonctions pas encore disponibles.
	if code, _ := n.adminAppel("GET", "/admin/navigations", nil); code != http.StatusNotFound {
		t.Fatalf("navigations : %d", code)
	}

	// Statistiques et supervision.
	code, brut = n.adminAppel("GET", "/admin/statistiques", nil)
	if code != 200 || !strings.Contains(string(brut), `"utilisateurs":3`) {
		t.Fatalf("statistiques : %d %s", code, brut)
	}

	// Suppression du bateau puis du compte.
	if rec := n.envoyer("POST", "/nautilink/admin/bateaux/"+bateau+"/suppression", map[string]string{}); rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("suppression sans confirmation : %d", rec.Code)
	}
	if rec := n.envoyer("POST", "/nautilink/admin/bateaux/"+bateau+"/suppression", map[string]string{"confirmation": "oui"}); rec.Code != http.StatusSeeOther {
		t.Fatalf("suppression bateau : %d", rec.Code)
	}
	if code, _ := n.adminAppel("DELETE", "/admin/utilisateurs/"+marin, nil); code != http.StatusNoContent {
		t.Fatalf("suppression compte : %d", code)
	}
	if code, _ := e.appelBrut("GET", "/compte", jMarin, nil); code != http.StatusUnauthorized {
		t.Fatalf("compte supprimé encore connecté : %d", code)
	}

	// Chaque action est tracée.
	code, brut = n.adminAppel("GET", "/admin/journal", nil)
	for _, attendu := range []string{`"action":"connexion"`, `"action":"modification","ressource":"utilisateurs"`,
		`"action":"modification","ressource":"bateaux"`, `"action":"creation","ressource":"annonces"`,
		`"action":"suppression","ressource":"bateaux"`, `"action":"suppression","ressource":"utilisateurs"`,
		`"action":"consultation","ressource":"statistiques"`} {
		if !strings.Contains(string(brut), attendu) {
			t.Errorf("journal sans %s", attendu)
		}
	}

	// Retirer l'adresse de NAUTILINK_ADMINS retire l'accès aussitôt.
	e.a.cfg.Admins = nil
	if rec := n.envoyer("GET", "/nautilink/admin/", nil); rec.Code != http.StatusSeeOther {
		t.Fatalf("accès après retrait : %d", rec.Code)
	}
	// Déconnexion de l'Application web sans effet sur l'API admin : déjà vu.
	_ = code
}
