package main

import (
	"io/fs"
	"regexp"
	"strings"
	"testing"
)

// TestAucunRoleAffiche : un seul type de contact, l'ami (D-176, TODO-4.13) :
// aucune page de l'Application web ni de l'espace administrateur n'affiche
// « Suiveur » ou « Contact SOS » ; les noms de champs et d'adresses
// (`.Suiveur`, `/suiveurs/`, `role=suiveur`) ne sont pas du texte affiché.
func TestAucunRoleAffiche(t *testing.T) {
	code := regexp.MustCompile(`(?s)\{\{.*?\}\}|<[^>]*>|<!--.*?-->`)
	interdit := regexp.MustCompile(`(?i)suiveur|contacts? sos`)
	err := fs.WalkDir(fichiersWeb, "web", func(chemin string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(chemin, ".html") {
			return err
		}
		b, err := fs.ReadFile(fichiersWeb, chemin)
		if err != nil {
			return err
		}
		texte := code.ReplaceAllString(string(b), " ")
		if m := interdit.FindString(texte); m != "" {
			t.Errorf("%s : « %s » affiché", chemin, m)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
