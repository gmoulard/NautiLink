package main

import "fmt"

// Version, numéro de build et commit du serveur (D-128, docs/09-versions.md),
// posés à la construction par l'image Docker :
//
//	-ldflags "-X main.version=0.0.1 -X main.build=12 -X main.commit=<sha>"
//
// version vient de server/VERSION ; build est le numéro d'exécution du
// workflow « Serveur » ; commit est le SHA complet construit.
var (
	version = "dev"
	build   = "local"
	commit  = ""
)

// depot : adresse du dépôt affichée dans les pieds de page.
const depot = "https://github.com/gmoulard/NautiLink"

// construction : ce qui identifie le binaire en cours, pour les pieds de page
// et la supervision.
type construction struct {
	Numero, Build, Commit string
}

func constructionServeur() construction {
	return construction{Numero: version, Build: build, Commit: commit}
}

// CommitCourt : les 7 premiers caractères du commit, « local » sans commit.
func (c construction) CommitCourt() string {
	if c.Commit == "" {
		return "local"
	}
	if len(c.Commit) > 7 {
		return c.Commit[:7]
	}
	return c.Commit
}

// Depot : adresse du dépôt, pour les gabarits.
func (construction) Depot() string { return depot }

// Site : site de présentation, lien « NautiLink » du pied de page de
// l'Application web (D-149) ; l'espace administrateur garde le dépôt (D-128).
func (construction) Site() string { return "https://gmoulard.github.io/NautiLink/" }

// String : « 0.0.1 (build 12, commit 93b0f97) ».
func (c construction) String() string {
	return fmt.Sprintf("%s (build %s, commit %s)", c.Numero, c.Build, c.CommitCourt())
}
