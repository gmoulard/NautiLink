package main

import (
	"strings"
	"testing"
	"time"
)

// TestIncidentPresente : incident ou avarie mis en évidence sur la carte et
// dans le journal, modifiable comme une note (RG-JRN-11, RG-JRN-06).
func TestIncidentPresente(t *testing.T) {
	t0 := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	texte := "Safran endommagé"
	inc := evenementEssai("i1", "incident", t0.Add(time.Hour), 47.66, -3.43)
	inc.Texte = &texte
	evts := []evenementJSON{evenementEssai("e1", "debut", t0, 47.70, -3.40), inc}
	c := carteDe(evts, true, nil, 800, 500, false)
	trouve := false
	for _, p := range c.Points {
		trouve = trouve || p.Sorte == "incident"
	}
	if !trouve {
		t.Error("incident absent de la carte")
	}
	j := journalPresente(evts, nil, true)
	if j[1].Libelle != "Incident - avarie" || !j[1].Modifiable {
		t.Errorf("journal : %+v", j[1])
	}
	d := donneesNavEssai(true, false)
	nav := d.D.(donneesNavigation)
	nav.Journal = j
	d.D = nav
	if s := rendu(t, "navigation.html", d); !strings.Contains(s, `class="evenement incident"`) || !strings.Contains(s, "Safran endommagé") {
		t.Error("journal : incident non mis en évidence")
	}
}

// TestIncidentAPI : avec PostgreSQL : TS-JRN-11 côté serveur : texte
// obligatoire, photo facultative, modification sans texte refusée, journal
// et page Web, type de SMS « Incidents - avaries » dans les paramètres.
func TestIncidentAPI(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().Add(-time.Hour).Truncate(time.Second)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, nil)
	sans := uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+sans, nav, map[string]any{"type": "incident",
		"heureAcquisition": heure(t0.Add(10 * time.Minute)), "origine": "android"}); code != 422 {
		t.Fatalf("incident sans texte : %d", code)
	}
	inc := uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+inc, nav, map[string]any{"type": "incident", "texte": "Safran endommagé",
		"heureAcquisition": heure(t0.Add(10 * time.Minute)), "origine": "android",
		"position": map[string]any{"latitude": 47.6, "longitude": -3.4, "heureAcquisition": heure(t0.Add(10 * time.Minute))},
		"fichier":  map[string]any{"typeMedia": "image/jpeg", "tailleOctets": len(jpegEssai)}}); code != 201 || r["type"] != "incident" {
		t.Fatalf("incident : %d %v", code, r)
	}
	if code := e.fichier("PUT", inc, nav, "image/jpeg", jpegEssai); code != 204 && code != 201 && code != 200 {
		t.Fatalf("photo de l'incident : %d", code)
	}
	if code, _ := e.appel("PATCH", "/navigations/"+id+"/evenements/"+inc, nav, map[string]any{"texte": ""}); code != 422 {
		t.Fatalf("incident vidé de son texte : %d", code)
	}
	web := e.webConnecte("nav@exemple.org")
	page := web.envoyer("GET", "/nautilink/navigations/"+id, nil).Body.String()
	if !strings.Contains(page, "Incident - avarie") || !strings.Contains(page, "point incident") || !strings.Contains(page, `class="evenement incident"`) {
		t.Fatalf("page de la navigation : %s", page)
	}
	if rec := web.envoyer("POST", "/nautilink/parametres", map[string]string{"smsActifs": "on", "incidents": "on"}); rec.Code != 303 {
		t.Fatalf("paramètres : %d", rec.Code)
	}
	if _, p := e.appel("GET", "/parametres", nav, nil); p["smsParType"].(map[string]any)["incidents"] != true {
		t.Fatalf("type « Incidents - avaries » : %v", p)
	}
}
