package main

import (
	"bytes"
	"encoding/csv"
	"strings"
	"testing"
	"time"
)

// TestExportCSV : D-180, RG-WEB-09 : une ligne par événement du journal,
// relue par un lecteur CSV.
func TestExportCSV(t *testing.T) {
	d := donneesNavEssai(false, false).D.(donneesNavigation)
	doc := exportCSV(d)
	if !bytes.HasPrefix(doc, []byte("\xEF\xBB\xBF")) {
		t.Fatal("marque UTF-8 absente")
	}
	r := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(doc, []byte("\xEF\xBB\xBF"))))
	r.Comma = ';'
	lignes, err := r.ReadAll()
	if err != nil {
		t.Fatal(err)
	}
	if len(lignes) != 1+len(d.Journal) || lignes[0][0] != "Heure" || lignes[0][2] != "Type" {
		t.Fatalf("%d lignes : %q", len(lignes), lignes[0])
	}
	note := lignes[3]
	if note[1] != "2026-11-20T09:40:00Z" || note[2] != "Note écrite" || note[3] != "47.660000" || note[4] != "-3.430000" || note[6] != "Dauphins par le travers" {
		t.Fatalf("note : %q", note)
	}
	if lignes[4][7] != "photo" || lignes[5][7] != "note vocale" || lignes[7][8] != "oui" || lignes[8][2] != "Alerte SOS" {
		t.Fatalf("lignes : %q", lignes[4:])
	}
}

// TestExportYAML : fiche de la navigation et journal ; textes échappés.
func TestExportYAML(t *testing.T) {
	d := donneesNavEssai(false, false).D.(donneesNavigation)
	piege := "Ligne 1\nLigne 2 : « guillemets \" » # pas un commentaire"
	d.Journal[2].E.Texte = &piege
	doc := string(exportYAML(d))
	for _, attendu := range []string{"navigation:\n  nom: \"Alizé — Glénan\"\n", "  navigateur: \"Paul\"\n", "  destination: \"Glénan\"\n",
		"  personnesABord: 3\n", "  bateau:\n    nom: ", "    portAttache: \"Lorient\"\n", "  suiveurs:\n    - \"Léa\"\n",
		"  contactsSos:\n    - \"Secours\"\n", "alertesSos:\n  - heure: ", "    probleme: \"Voie d'eau\"\n", "    horsNavigation: true\n",
		"journal:\n  - heure: 2026-11-20T09:00:00Z\n    type: debut\n", `    texte: "Ligne 1\nLigne 2 : « guillemets \" » # pas un commentaire"` + "\n",
		"    fichier: \"photo\"\n", "    horsHeuresAffichees: true\n"} {
		if !strings.Contains(doc, attendu) {
			t.Errorf("%q absent du YAML :\n%s", attendu, doc)
		}
	}
	if n := strings.Count(doc, "\n  - heure: "); n != len(d.Journal)+len(d.Alertes) {
		t.Fatalf("%d éléments", n)
	}
}

// TestExportsWeb : avec PostgreSQL : mêmes droits que le PDF (RG-NAV-19,
// RG-PAR-08) ; boutons sur la page de la navigation.
func TestExportsWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().Add(-5 * time.Hour).Truncate(time.Second)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, nil)
	e.appel("PUT", "/navigations/"+id+"/fin", nav, map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(t0.Add(2 * time.Hour))})
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	page := e.webConnecte("nav@exemple.org").envoyer("GET", "/nautilink/navigations/"+id, nil).Body.String()
	for _, b := range []string{"Exporter en PDF", `/navigations/` + id + `/csv" download>Exporter en CSV`, `/navigations/` + id + `/yaml" download>Exporter en YAML`} {
		if !strings.Contains(page, b) {
			t.Fatalf("%q absent de la page", b)
		}
	}
	for _, email := range []string{"nav@exemple.org", "lea@exemple.org"} {
		web := e.webConnecte(email)
		rec := web.envoyer("GET", "/nautilink/navigations/"+id+"/csv", nil)
		if rec.Code != 200 || rec.Header().Get("Content-Type") != "text/csv; charset=utf-8" || !strings.Contains(rec.Header().Get("Content-Disposition"), `.csv"`) ||
			!strings.Contains(rec.Body.String(), "Début de navigation") || !strings.Contains(rec.Body.String(), "Fin de navigation") {
			t.Fatalf("CSV pour %s : %d %s", email, rec.Code, rec.Body.String())
		}
		rec = web.envoyer("GET", "/nautilink/navigations/"+id+"/yaml", nil)
		if rec.Code != 200 || !strings.HasPrefix(rec.Header().Get("Content-Type"), "application/yaml") || !strings.Contains(rec.Body.String(), "journal:\n  - heure: ") {
			t.Fatalf("YAML pour %s : %d %s", email, rec.Code, rec.Body.String())
		}
	}
	e.compte("eve@exemple.org", "Ève")
	for _, f := range []string{"csv", "yaml"} {
		if rec := e.webConnecte("eve@exemple.org").envoyer("GET", "/nautilink/navigations/"+id+"/"+f, nil); rec.Code != 404 {
			t.Fatalf("%s sans accès : %d", f, rec.Code)
		}
	}
}
