package main

import (
	"strings"
	"testing"
)

// TestRenduTelephone : Application web sur l'écran d'un téléphone
// (RG-WEB-04, TS-WEB-04) : fenêtre à la largeur de l'écran, bouton « Menu »
// (caché sans JavaScript, menu alors affiché en entier), tableaux empilés
// avec l'intitulé de chaque colonne, règles de la feuille de style.
func TestRenduTelephone(t *testing.T) {
	page := rendu(t, "corbeille.html", &donneesPage{Base: "/nautilink", Connecte: true,
		D: []ligneCorbeille{{N: navEssai("Alizé — Glénan", "corbeille", "navigateur"), Debut: "2026-11-20 09:00 UTC", Definitive: "20 décembre 2026"}}})
	for _, attendu := range []string{`name="viewport" content="width=device-width, initial-scale=1"`,
		`class="menu-bouton secondaire" type="button" aria-expanded="false" aria-controls="menu" hidden>Menu</button>`,
		`<nav id="menu" aria-label="Menu principal">`, `src="/nautilink/static/menu.js"`, `<table class="empilable">`,
		`<td data-label="Navigation">`, `<td data-label="Suppression définitive">`} {
		if !strings.Contains(page, attendu) {
			t.Errorf("%q absent", attendu)
		}
	}
	feuille, err := fichiersWeb.ReadFile("web/static/style.css")
	if err != nil {
		t.Fatal(err)
	}
	for _, attendu := range []string{"@media (max-width: 720px)", "header.menu-js.ouvert nav { display: flex; }",
		`table.empilable td[data-label]::before`, "min-height: 44px", "[hidden] { display: none !important; }"} {
		if !strings.Contains(string(feuille), attendu) {
			t.Errorf("feuille de style sans %q", attendu)
		}
	}
	if _, err := fichiersWeb.ReadFile("web/static/menu.js"); err != nil {
		t.Error("menu.js absent")
	}
}
