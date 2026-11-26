package main

import (
	"net/http"
	"strings"
	"testing"
)

// TestRenduMenuAdministration : menu « Administration » pour un
// administrateur seulement (RG-WEB-03).
func TestRenduMenuAdministration(t *testing.T) {
	if s := rendu(t, "message.html", &donneesPage{Base: "/nautilink", Connecte: true, Admin: true}); !strings.Contains(s, `href="/nautilink/admin/">Administration</a>`) {
		t.Error("administrateur : menu absent")
	}
	if s := rendu(t, "message.html", &donneesPage{Base: "/nautilink", Connecte: true}); strings.Contains(s, "Administration") {
		t.Error("utilisateur : menu affiché")
	}
}

// TestMenuAdministrationWeb : avec PostgreSQL : TS-WEB-03 : lien pour un
// compte de NAUTILINK_ADMINS dont l'adresse est confirmée, absent sinon ;
// l'espace administrateur demande toujours sa propre connexion.
func TestMenuAdministrationWeb(t *testing.T) {
	e := nouvelEssai(t)
	e.a.cfg.Admins = []string{"admin@exemple.org", "pasconfirme@exemple.org"}
	e.h = e.a.routeur()
	e.compte("admin@exemple.org", "Admin")
	e.confirmerEmail("admin@exemple.org")
	e.compte("pasconfirme@exemple.org", "Pas confirmé")
	e.compte("marin@exemple.org", "Marin")
	e.confirmerEmail("marin@exemple.org")

	admin := e.webConnecte("admin@exemple.org")
	if page := admin.envoyer("GET", "/nautilink/", nil).Body.String(); !strings.Contains(page, `href="/nautilink/admin/">Administration</a>`) {
		t.Fatalf("administrateur sans menu : %s", page)
	}
	for _, email := range []string{"marin@exemple.org", "pasconfirme@exemple.org"} {
		if page := e.webConnecte(email).envoyer("GET", "/nautilink/", nil).Body.String(); strings.Contains(page, "/admin/") {
			t.Fatalf("%s : menu « Administration » affiché", email)
		}
	}
	if rec := admin.envoyer("GET", "/nautilink/admin/", nil); rec.Code != http.StatusSeeOther || rec.Header().Get("Location") != "/nautilink/admin/connexion" {
		t.Fatalf("espace administrateur sans sa connexion : %d %q", rec.Code, rec.Header().Get("Location"))
	}
}
