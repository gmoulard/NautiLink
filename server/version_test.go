package main

import (
	"strings"
	"testing"
)

func TestConstruction(t *testing.T) {
	c := construction{Numero: "0.0.1", Build: "12", Commit: "93b0f974518eacd5a3357763ed9eae4e437f1d33"}
	if c.CommitCourt() != "93b0f97" || c.String() != "0.0.1 (build 12, commit 93b0f97)" {
		t.Fatalf("construction : %q %q", c.CommitCourt(), c.String())
	}
	if (construction{}).CommitCourt() != "local" {
		t.Fatal("sans commit : « local » attendu")
	}
}

// Pied de page de toutes les pages Web : licence, dépôt, version, build, commit (D-128).
func TestPiedDePage(t *testing.T) {
	ancienV, ancienB, ancienC := version, build, commit
	version, build, commit = "0.0.1", "12", "93b0f974518eacd5a3357763ed9eae4e437f1d33"
	t.Cleanup(func() { version, build, commit = ancienV, ancienB, ancienC })

	h := nouveauRouteur(config{Chemin: "/nautilink"}, &base{})
	for _, chemin := range []string{"/nautilink/", "/nautilink/admin/"} {
		corps := requete(t, h, chemin).Body.String()
		for _, attendu := range []string{
			"Tous droits réservés", `<a href="https://github.com/gmoulard/NautiLink">https://github.com/gmoulard/NautiLink</a>`,
			"V0.0.1", "build 12", `commit <a href="https://github.com/gmoulard/NautiLink/commit/93b0f974518eacd5a3357763ed9eae4e437f1d33">93b0f97</a>`,
		} {
			if !strings.Contains(corps, attendu) {
				t.Errorf("%s : %q absent du pied de page", chemin, attendu)
			}
		}
	}
}
