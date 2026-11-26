package main

import (
	"strings"
	"testing"
)

// TestRenduAcces : écrans d'accès au style de l'étude (D-157) : décor,
// logo, nom et signature, champs nommés pour les lecteurs d'écran, bouton
// « œil » caché sans JavaScript, libellés des règles (RG-CPT-02, RG-CPT-10,
// RG-PRM-05) ; pas de connexion Google ou Apple tant que le Web ne l'a pas.
func TestRenduAcces(t *testing.T) {
	d := &donneesPage{Base: "/nautilink", F: map[string]string{"email": "lea@exemple.org"}}
	page := rendu(t, "connexion.html", d)
	for _, attendu := range []string{`class="acces-decor"`, "/nautilink/static/logo-nautilink.png", "Your sea, your safety, your story.",
		`<h1 id="titre-acces">Se connecter</h1>`, "Accédez à votre compte NautiLink", `<label class="masque" for="email">Adresse e-mail</label>`,
		`value="lea@exemple.org"`, `<label class="masque" for="motdepasse">Mot de passe</label>`, `autocomplete="current-password"`,
		`class="oeil" type="button" data-cible="motdepasse" aria-label="Afficher le mot de passe" aria-pressed="false" hidden`,
		"Rester connecté", `class="pleine" type="submit">Se connecter</button>`, "Mot de passe oublié ?", "Pas encore de compte ?",
		"/nautilink/static/acces.js", `class="acces-vagues"`} {
		if !strings.Contains(page, attendu) {
			t.Errorf("connexion : %q absent", attendu)
		}
	}
	for _, interdit := range []string{"Google", "Apple", "style="} {
		if strings.Contains(page, interdit) {
			t.Errorf("connexion : %q présent", interdit)
		}
	}
	page = rendu(t, "inscription.html", d)
	for _, attendu := range []string{`<h1 id="titre-acces">Créer un compte</h1>`, `autocomplete="new-password"`, `minlength="8"`, "Créer mon compte", "Déjà inscrit ?"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("inscription : %q absent", attendu)
		}
	}
	if page := rendu(t, "mot-de-passe-oublie.html", d); !strings.Contains(page, "Recevoir le lien") || !strings.Contains(page, `class="acces-decor"`) {
		t.Error("mot de passe oublié : écran d'accès absent")
	}
}
