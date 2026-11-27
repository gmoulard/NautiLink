package main

import (
	"strings"
	"testing"
)

// TestRubriqueDe : entrée du menu de chaque page (D-178, RG-WEB-10).
func TestRubriqueDe(t *testing.T) {
	for chemin, attendu := range map[string]string{"/": "log", "": "log", "/navigations/abc": "log", "/navigations/abc/pdf": "log",
		"/demarrer": "log", "/bateaux": "bateaux", "/bateaux/b1": "bateaux", "/contacts/c1": "contacts", "/quota": "quota",
		"/quota/abonnement/retour": "quota", "/alertes-sos": "alertes-sos", "/mot-de-passe": "compte", "/mot-de-passe-oublie": "connexion"} {
		if r := rubriqueDe(chemin); r != attendu {
			t.Errorf("%q : %q, attendu %q", chemin, r, attendu)
		}
	}
}

// TestRenduMenu : boutons du menu, celui de la page ouverte marqué
// (aria-current, bleu foncé), « Se déconnecter » au même style.
func TestRenduMenu(t *testing.T) {
	s := rendu(t, "message.html", &donneesPage{Base: "/nautilink", Connecte: true, Rubrique: "quota"})
	if !strings.Contains(s, `<a href="/nautilink/quota" aria-current="page">Quota et abonnement</a>`) || strings.Count(s, `aria-current="page"`) != 1 ||
		!strings.Contains(s, `<button class="menu" type="submit">Se déconnecter</button>`) {
		t.Fatalf("menu : %s", s)
	}
	if s := rendu(t, "message.html", &donneesPage{Base: "/nautilink", Rubrique: "connexion"}); !strings.Contains(s, `<a href="/nautilink/connexion" aria-current="page">Se connecter</a>`) {
		t.Fatal("menu hors connexion")
	}
}
