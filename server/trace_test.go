package main

import (
	"strings"
	"testing"
	"time"
)

// Trace au navigateur (RG-NOT-06, D-158) : un e-mail par élément reçu, et
// un récapitulatif du journal à la fin de la navigation.
func TestTraceNavigateur(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Yann", "Mistral")
	id := uuid(t)
	t0 := time.Now().Add(-time.Hour).Truncate(time.Second)
	d := demarrage(bateau, tel, t0, 47.8, -3.9)
	d["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d); code != 201 {
		t.Fatalf("démarrage : %d %v", code, r)
	}
	avant := e.courrier.nombre()
	p := position(uuid(t), t0.Add(30*time.Minute), 2, 47.75, -3.95)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+p["id"].(string), nav, p); code != 201 {
		t.Fatalf("position : %d", code)
	}
	// Renvoi du même élément : pas de nouvel e-mail.
	e.appel("PUT", "/navigations/"+id+"/evenements/"+p["id"].(string), nav, p)
	if e.courrier.nombre() != avant+1 {
		t.Fatalf("e-mails de trace : %d", e.courrier.nombre()-avant)
	}
	trace := e.courrier.dernier(t, "nav@exemple.org")
	if !strings.Contains(trace, "Position automatique") || !strings.Contains(trace, "47.75000, -3.95000") ||
		!strings.Contains(trace, "/navigations/"+id) {
		t.Fatalf("e-mail de trace : %s", trace)
	}
	note := map[string]any{"id": uuid(t), "type": "note", "heureAcquisition": heure(t0.Add(40 * time.Minute)),
		"numeroOrdre": 3, "origine": "android", "texte": "Cap au 270"}
	e.appel("PUT", "/navigations/"+id+"/evenements/"+note["id"].(string), nav, note)
	fin := map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(time.Now()), "numeroOrdre": 4, "origine": "android"}
	if code, r := e.appel("PUT", "/navigations/"+id+"/fin", nav, fin); code != 200 {
		t.Fatalf("fin : %d %v", code, r)
	}
	recap := e.courrier.dernier(t, "nav@exemple.org")
	for _, attendu := range []string{"Journal de bord", "Début de navigation", "Position automatique", "Cap au 270", "Fin de navigation"} {
		if !strings.Contains(recap, attendu) {
			t.Fatalf("récapitulatif sans « %s » : %s", attendu, recap)
		}
	}
}
