package main

import (
	"net/http"
	"strings"
	"testing"
)

// Mot de passe oublié (RG-CPT-10).
func TestMotDePasseOublie(t *testing.T) {
	e := nouvelEssai(t)
	mobile := e.compte("oubli@exemple.org", "Oubli")
	n := e.navigateur()
	n.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "oubli@exemple.org", "motdepasse": "motdepasse"})
	if rec := n.envoyer("GET", "/nautilink/compte", nil); rec.Code != 200 {
		t.Fatalf("session Web : %d", rec.Code)
	}

	// Adresse inconnue : même réponse, aucun e-mail.
	avant := e.courrier.nombre()
	if code, _ := e.appel("POST", "/compte/mot-de-passe/oubli", "", map[string]string{"email": "personne@exemple.org"}); code != 204 {
		t.Fatalf("adresse inconnue : %d", code)
	}
	if e.courrier.nombre() != avant {
		t.Fatal("e-mail envoyé à une adresse sans compte")
	}

	if code, _ := e.appel("POST", "/compte/mot-de-passe/oubli", "", map[string]string{"email": " Oubli@Exemple.org "}); code != 204 {
		t.Fatalf("demande : %d", code)
	}
	texte := e.courrier.dernier(t, "oubli@exemple.org")
	if !strings.Contains(texte, "/mot-de-passe?jeton=") || !strings.Contains(texte, "1 heure") {
		t.Fatalf("e-mail : %q", texte)
	}
	jeton := jetonDuTexte(t, texte)

	// Page Web du lien, mot de passe trop court refusé.
	if rec := n.envoyer("GET", "/nautilink/mot-de-passe?jeton="+jeton, nil); rec.Code != 200 || !strings.Contains(rec.Body.String(), "Nouveau mot de passe") {
		t.Fatalf("page du lien : %d", rec.Code)
	}
	if code, r := e.appel("POST", "/compte/mot-de-passe", "", map[string]string{"jeton": jeton, "motDePasse": "court"}); code != 422 {
		t.Fatalf("mot de passe court : %d %v", code, r)
	}
	rec := n.envoyer("POST", "/nautilink/mot-de-passe", map[string]string{"jeton": jeton, "motdepasse": "nouveaumdp"})
	if rec.Code != http.StatusSeeOther || rec.Header().Get("Location") != "/nautilink/connexion?ok=motdepasse" {
		t.Fatalf("changement par le Web : %d %q", rec.Code, rec.Header().Get("Location"))
	}

	// Toutes les sessions sont fermées, sur le Web comme sur le téléphone.
	if code, _ := e.appel("GET", "/compte", mobile, nil); code != 401 {
		t.Fatalf("session mobile encore ouverte : %d", code)
	}
	if rec := n.envoyer("GET", "/nautilink/compte", nil); rec.Code != http.StatusSeeOther {
		t.Fatalf("session Web encore ouverte : %d", rec.Code)
	}
	// Ancien mot de passe refusé, nouveau accepté.
	if code, _ := e.appel("POST", "/sessions", "", map[string]string{"email": "oubli@exemple.org", "motDePasse": "motdepasse"}); code != 401 {
		t.Fatalf("ancien mot de passe : %d", code)
	}
	if code, _ := e.appel("POST", "/sessions", "", map[string]string{"email": "oubli@exemple.org", "motDePasse": "nouveaumdp"}); code != 200 {
		t.Fatalf("nouveau mot de passe : %d", code)
	}
	// Le lien ne sert qu'une fois.
	if code, _ := e.appel("POST", "/compte/mot-de-passe", "", map[string]string{"jeton": jeton, "motDePasse": "encoreautre"}); code != 404 {
		t.Fatalf("lien réutilisé : %d", code)
	}
	if rec := n.envoyer("GET", "/nautilink/mot-de-passe?jeton="+jeton, nil); rec.Code != 404 {
		t.Fatalf("page d'un lien usé : %d", rec.Code)
	}

	// Lien expiré (plus d'une heure) : refusé.
	e.appel("POST", "/compte/mot-de-passe/oubli", "", map[string]string{"email": "oubli@exemple.org"})
	jeton = jetonDuTexte(t, e.courrier.dernier(t, "oubli@exemple.org"))
	if _, err := e.a.b.pool.Exec(t.Context(), "UPDATE jetons_email SET expire_le = now() - interval '1 second' WHERE objet = 'mot_de_passe'"); err != nil {
		t.Fatal(err)
	}
	if code, _ := e.appel("POST", "/compte/mot-de-passe", "", map[string]string{"jeton": jeton, "motDePasse": "encoreautre"}); code != 404 {
		t.Fatalf("lien expiré : %d", code)
	}

	// Page « Mot de passe oublié ? » et lien depuis la connexion.
	if rec := n.envoyer("GET", "/nautilink/connexion", nil); !strings.Contains(rec.Body.String(), "Mot de passe oublié ?") {
		t.Fatal("lien « Mot de passe oublié ? » absent de la connexion")
	}
	rec = n.envoyer("POST", "/nautilink/mot-de-passe-oublie", map[string]string{"email": "oubli@exemple.org"})
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "un e-mail vient de lui être envoyé") {
		t.Fatalf("page « Mot de passe oublié » : %d", rec.Code)
	}
}
