package main

import (
	"bytes"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// marin : compte vérifié avec un bateau associé à un téléphone ; rend le
// jeton, l'identifiant du bateau et celui du téléphone.
func (e *essai) marin(email, nom, bateau string) (jeton, bateauID, appareil string) {
	e.t.Helper()
	jeton = e.compte(email, nom)
	e.verifier(email)
	_, b := e.appel("POST", "/bateaux", jeton, map[string]any{"nom": bateau, "type": "voilier"})
	bateauID = b["id"].(string)
	appareil = uuid(e.t)
	e.appel("PUT", "/appareils/"+appareil, jeton, map[string]any{"plateforme": "android"})
	if code, _ := e.appel("PUT", "/bateaux/"+bateauID+"/telephone", jeton, map[string]any{"appareilId": appareil}); code != 200 {
		e.t.Fatalf("association du téléphone : %d", code)
	}
	return
}

func (e *essai) verifier(email string) {
	e.t.Helper()
	if _, err := e.a.b.pool.Exec(e.t.Context(), "UPDATE utilisateurs SET email_verifie_le = now() WHERE email = $1", email); err != nil {
		e.t.Fatal(err)
	}
}

var compteurUUID int

func uuid(t *testing.T) string {
	compteurUUID++
	return fmt.Sprintf("%08x-0000-4000-8000-%012x", time.Now().UnixNano()&0xffffffff, compteurUUID)
}

func heure(h time.Time) string { return h.Format(time.RFC3339) }

func demarrage(bateau, appareil string, debut time.Time, lat, lon float64) map[string]any {
	return map[string]any{"bateauId": bateau, "appareilId": appareil, "frequenceMinutes": 30, "personnesABord": 2,
		"destination": map[string]any{"texte": "Glénan"},
		"debut": map[string]any{"id": "", "type": "debut", "heureAcquisition": heure(debut), "numeroOrdre": 1,
			"position": map[string]any{"latitude": lat, "longitude": lon, "heureAcquisition": heure(debut)}}}
}

func position(id string, h time.Time, ordre int, lat, lon float64) map[string]any {
	return map[string]any{"id": id, "type": "position_automatique", "heureAcquisition": heure(h), "numeroOrdre": ordre,
		"origine": "android", "position": map[string]any{"latitude": lat, "longitude": lon, "heureAcquisition": heure(h)}}
}

func TestNavigationComplete(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().Add(-3 * time.Hour).Truncate(time.Second)
	id := uuid(t)
	d := demarrage(bateau, tel, t0, 47.70, -3.36)
	d["debut"].(map[string]any)["id"] = uuid(t)

	// Compte non vérifié : démarrage refusé (RG-CPT-09, D-105).
	autre, autreBateau, autreTel := e.marin("autre@exemple.org", "Autre", "Brise")
	e.a.b.pool.Exec(t.Context(), "UPDATE utilisateurs SET email_verifie_le = NULL WHERE email = 'autre@exemple.org'")
	da := demarrage(autreBateau, autreTel, t0, 47, -3)
	da["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+uuid(t), autre, da); code != 403 || r["code"] != "email_non_verifie" {
		t.Fatalf("compte non vérifié : %d %v", code, r)
	}
	// Seul le propriétaire démarre (RG-CPT-05) ; téléphone associé exigé.
	if code, r := e.appel("PUT", "/navigations/"+uuid(t), autre, d); code != 403 || r["code"] != "pas_proprietaire" {
		t.Fatalf("pas propriétaire : %d %v", code, r)
	}
	mauvais := demarrage(bateau, uuid(t), t0, 47, -3)
	mauvais["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+uuid(t), nav, mauvais); code != 403 || r["code"] != "telephone_non_associe" {
		t.Fatalf("téléphone non associé : %d %v", code, r)
	}

	code, n := e.appel("PUT", "/navigations/"+id, nav, d)
	if code != 201 || n["nom"] != "Alizé — Glénan" || n["etat"] != "en_cours" || n["personnesABord"] != 2.0 {
		t.Fatalf("démarrage : %d %v", code, n)
	}
	// Renvoi du même démarrage : 200, aucun doublon ; contenu différent : 409.
	if code, _ := e.appel("PUT", "/navigations/"+id, nav, d); code != 200 {
		t.Fatalf("renvoi du démarrage : %d", code)
	}
	d2 := demarrage(bateau, tel, t0, 47.70, -3.36)
	d2["debut"] = d["debut"]
	d2["personnesABord"] = 3
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d2); code != 409 || r["code"] != "evenement_different" {
		t.Fatalf("démarrage différent : %d %v", code, r)
	}
	// Une seule navigation en cours par bateau et par téléphone (RG-NAV-03).
	d3 := demarrage(bateau, tel, t0, 47, -3)
	d3["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+uuid(t), nav, d3); code != 409 || r["code"] != "navigation_en_cours" {
		t.Fatalf("deuxième navigation : %d %v", code, r)
	}

	// Positions envoyées dans le désordre et en double, une par lot.
	p1, p2, p3 := uuid(t), uuid(t), uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+p2, nav, position(p2, t0.Add(time.Hour), 3, 47.72, -3.38)); code != 201 {
		t.Fatalf("position : %d", code)
	}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+p2, nav, position(p2, t0.Add(time.Hour), 3, 47.72, -3.38)); code != 200 {
		t.Fatalf("position en double : %d", code)
	}
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+p2, nav, position(p2, t0.Add(time.Hour), 3, 47.0, -3.38)); code != 409 || r["code"] != "evenement_different" {
		t.Fatalf("position différente sous le même identifiant : %d %v", code, r)
	}
	note := uuid(t)
	_, res := e.appel("POST", "/synchronisation", nav, map[string]any{"elements": []map[string]any{
		{"operation": "evenement", "id": p1, "navigationId": id, "contenu": position(p1, t0.Add(30*time.Minute), 2, 47.71, -3.37)},
		{"operation": "evenement", "id": p2, "navigationId": id, "contenu": position(p2, t0.Add(time.Hour), 3, 47.72, -3.38)},
		{"operation": "evenement", "id": note, "navigationId": id, "contenu": map[string]any{"type": "note", "texte": "Grain au large",
			"heureAcquisition": heure(t0.Add(45 * time.Minute)), "numeroOrdre": 4}},
		{"operation": "inconnue", "id": uuid(t)},
		{"operation": "evenement", "id": p3, "navigationId": id, "contenu": position(p3, t0.Add(90*time.Minute), 5, 47.73, -3.39)},
	}})
	rs := res["resultats"].([]any)
	attendus := []float64{201, 200, 201, 422, 201}
	for i, r := range rs {
		if r.(map[string]any)["statut"] != attendus[i] {
			t.Fatalf("lot : résultat %d : %v", i, r)
		}
	}

	// Ami de périmètre navigateur : lecture seule.
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	code, page := e.appel("GET", "/navigations/"+id, lea, nil)
	if code != 200 {
		t.Fatalf("lecture par l'ami : %d", code)
	}
	// Une seule liste « amis » (RG-PAR-08, D-186) : l'ami qui suit, avec
	// l'identifiant de son compte.
	if amis, _ := page["amis"].([]any); len(amis) != 1 || amis[0].(map[string]any)["suit"] != true ||
		amis[0].(map[string]any)["id"] != e.id(lea) {
		t.Fatalf("amis de la navigation : %v", page)
	}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+uuid(t), lea, position(uuid(t), t0, 9, 1, 1)); code != 403 {
		t.Fatalf("écriture par l'ami : %d", code)
	}
	if code, _ := e.appel("GET", "/navigations/"+id, autre, nil); code != 404 {
		t.Fatalf("lecture sans accès : %d", code)
	}

	// Fin envoyée en retard, avec son heure réelle ; rejouable.
	fin := map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(t0.Add(2 * time.Hour)), "numeroOrdre": 6,
		"position": map[string]any{"latitude": 47.74, "longitude": -3.40, "heureAcquisition": heure(t0.Add(2 * time.Hour))}}
	code, n = e.appel("PUT", "/navigations/"+id+"/fin", nav, fin)
	if code != 200 || n["etat"] != "terminee" || n["dureeMinutes"] != 120.0 || n["adressePage"] != "https://exemple.org/nautilink/navigations/"+id {
		t.Fatalf("fin : %d %v", code, n)
	}
	if n["distanceMetres"].(float64) < 4000 || n["lieuArrivee"] == nil {
		t.Fatalf("distance ou lieu d'arrivée : %v", n)
	}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/fin", nav, fin); code != 200 {
		t.Fatalf("renvoi de la fin : %d", code)
	}

	// Journal dans l'ordre d'acquisition (RG-JRN-03).
	_, j := e.appel("GET", "/navigations/"+id+"/evenements", lea, nil)
	evts := j["evenements"].([]any)
	types := ""
	for _, ev := range evts {
		types += ev.(map[string]any)["type"].(string)[:3] + " "
	}
	if types != "deb pos not pos pos fin " {
		t.Fatalf("ordre du journal : %q", types)
	}
	// Début, fin et positions non modifiables (RG-JRN-07) ; note modifiable.
	for _, ev := range []string{p1, fin["id"].(string), d["debut"].(map[string]any)["id"].(string)} {
		if code, r := e.appel("PATCH", "/navigations/"+id+"/evenements/"+ev, nav, map[string]any{"texte": "x"}); code != 403 || r["code"] != "evenement_non_modifiable" {
			t.Fatalf("modification de %s : %d %v", ev, code, r)
		}
		if code, _ := e.appel("DELETE", "/navigations/"+id+"/evenements/"+ev, nav, nil); code != 403 {
			t.Fatalf("suppression de %s : %d", ev, code)
		}
	}
	curseur := j["curseur"].(string)
	if code, r := e.appel("PATCH", "/navigations/"+id+"/evenements/"+note, nav, map[string]any{"texte": "Grain"}); code != 200 || r["texte"] != "Grain" {
		t.Fatalf("modification de la note : %d %v", code, r)
	}
	_, j = e.appel("GET", "/navigations/"+id+"/evenements?depuis="+curseur, lea, nil)
	if l := j["evenements"].([]any); len(l) != 1 || l[0].(map[string]any)["id"] != note {
		t.Fatalf("depuis : %v", j)
	}

	// Heures modifiées après la navigation : événements hors plage masqués
	// (RG-NAV-22), heures enregistrées inchangées (RG-ECO-02).
	code, n = e.appel("PATCH", "/navigations/"+id, nav, map[string]any{"debut": heure(t0.Add(40 * time.Minute)), "nom": "Sortie"})
	if code != 200 || n["nom"] != "Sortie" || n["debutEnregistre"] != t0.UTC().Format(time.RFC3339) {
		t.Fatalf("modification des heures : %d %v", code, n)
	}
	_, j = e.appel("GET", "/navigations/"+id+"/evenements", nav, nil)
	if ev := j["evenements"].([]any)[1].(map[string]any); ev["id"] != p1 || ev["masque"] != true {
		t.Fatalf("position masquée : %v", ev)
	}
	// Ajout depuis le Web, navigation terminée (RG-JRN-05).
	ajout := uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+ajout, nav, map[string]any{"type": "ajout", "origine": "web",
		"texte": "Mouillage calme", "heureAcquisition": heure(t0.Add(100 * time.Minute))}); code != 201 {
		t.Fatalf("ajout : %d", code)
	}

	// Listes : comme navigateur et comme ami.
	_, l := e.appel("GET", "/navigations?role=ami", lea, nil)
	if ns := l["navigations"].([]any); len(ns) != 1 || ns[0].(map[string]any)["role"] != "ami" {
		t.Fatalf("liste de l'ami : %v", l)
	}
	// Retrait de cette navigation seulement (RG-PAR-06).
	leaID := e.id(lea)
	if code, _ := e.appel("DELETE", "/navigations/"+id+"/amis/"+leaID, nav, nil); code != 204 {
		t.Fatalf("retrait d'une navigation : %d", code)
	}
	if code, _ := e.appel("GET", "/navigations/"+id, lea, nil); code != 404 {
		t.Fatalf("lecture après retrait : %d", code)
	}
	_ = autreBateau
}

// suivre : invitation par e-mail acceptée par l'ami.
func (e *essai) suivre(nav, ami, email, perimetre, navigation string) {
	e.t.Helper()
	corps := map[string]any{"canal": "email", "email": email, "perimetre": perimetre}
	if navigation != "" {
		corps["navigationId"] = navigation
	}
	if code, r := e.appel("POST", "/invitations", nav, corps); code != 201 {
		e.t.Fatalf("invitation : %d %v", code, r)
	}
	jeton := jetonDuTexte(e.t, e.courrier.dernier(e.t, email))
	if code, r := e.appel("POST", "/invitations/acceptation", ami, map[string]any{"jetonInvitation": jeton}); code != 200 && code != 201 {
		e.t.Fatalf("acceptation : %d %v", code, r)
	}
}

func TestNavigationPerimetreEtFichiers(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	id := uuid(t)
	d := demarrage(bateau, tel, time.Now().Add(-time.Hour), 47, -3)
	d["debut"].(map[string]any)["id"] = uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id, nav, d); code != 201 {
		t.Fatal("démarrage")
	}
	// Périmètre navigation : cette navigation seulement, fiche du bateau comprise.
	tom := e.compte("tom@exemple.org", "Tom")
	e.suivre(nav, tom, "tom@exemple.org", "navigation", id)
	if code, n := e.appel("GET", "/navigations/"+id, tom, nil); code != 200 || n["fiche"] == nil {
		t.Fatalf("navigation suivie : %d %v", code, n)
	}
	if code, _ := e.appel("GET", "/bateaux/"+bateau, tom, nil); code != 404 {
		t.Fatalf("fiche hors navigation, périmètre navigation : %d", code)
	}
	_, l := e.liste("GET", "/navigations/"+id+"/amis", nav, nil)
	if len(l) != 1 || l[0]["nom"] != "Tom" {
		t.Fatalf("amis : %v", l)
	}

	// Photo : événement, puis fichier ; lu par l'ami.
	photo := uuid(t)
	ev := map[string]any{"id": photo, "type": "photo", "heureAcquisition": heure(time.Now()), "fichier": map[string]any{"typeMedia": "image/jpeg"}}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+photo, nav, ev); code != 201 {
		t.Fatal("photo")
	}
	jpeg := append([]byte{0xFF, 0xD8, 0xFF, 0xE0}, bytes.Repeat([]byte{1}, 100)...)
	if code := e.fichier("PUT", photo, nav, "image/jpeg", jpeg); code != 204 {
		t.Fatalf("dépôt du fichier : %d", code)
	}
	if code := e.fichier("PUT", photo, nav, "audio/mp4", jpeg); code != 422 {
		t.Fatalf("mauvais type : %d", code)
	}
	if code := e.fichier("GET", photo, tom, "", nil); code != 200 {
		t.Fatalf("lecture du fichier : %d", code)
	}
	// Note vocale de plus d'une minute refusée (RG-JRN-04).
	vocale := uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+vocale, nav, map[string]any{"type": "note_vocale",
		"heureAcquisition": heure(time.Now()), "fichier": map[string]any{"typeMedia": "audio/mp4", "dureeSecondes": 61}}); code != 422 || r["code"] != "note_vocale_trop_longue" {
		t.Fatalf("note vocale trop longue : %d %v", code, r)
	}
	// 20 photos au plus (RG-JRN-08).
	for i := 1; i < 20; i++ {
		p := uuid(t)
		ev["id"] = p
		if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+p, nav, ev); code != 201 {
			t.Fatalf("photo %d : %d", i+1, code)
		}
	}
	p := uuid(t)
	ev["id"] = p
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+p, nav, ev); code != 409 || r["code"] != "limite_photos" {
		t.Fatalf("21e photo : %d %v", code, r)
	}
	// Ajout refusé pendant la navigation (RG-JRN-05).
	a := uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+a, nav, map[string]any{"type": "ajout", "texte": "x",
		"heureAcquisition": heure(time.Now())}); code != 409 {
		t.Fatalf("ajout en cours : %d", code)
	}
}

func (e *essai) fichier(methode, id, jeton, typ string, corps []byte) int {
	e.t.Helper()
	req := httptest.NewRequest(methode, "/nautilink/api/v1/fichiers/"+id, bytes.NewReader(corps))
	req.Header.Set("Authorization", "Bearer "+jeton)
	if typ != "" {
		req.Header.Set("Content-Type", typ)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec.Code
}

// Noms de lieux (RG-JRN-10) par un faux service Nominatim, avec cache.
func TestNomsDeLieux(t *testing.T) {
	e := nouvelEssai(t)
	appels := 0
	faux := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		appels++
		w.Write([]byte(`{"name":"","display_name":"Concarneau, Finistère, France"}`))
	}))
	defer faux.Close()
	e.a.cfg.Nominatim = faux.URL
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	id := uuid(t)
	d := demarrage(bateau, tel, time.Now().Add(-time.Hour), 47.8731, -3.9187)
	d["debut"].(map[string]any)["id"] = uuid(t)
	e.appel("PUT", "/navigations/"+id, nav, d)
	p := uuid(t)
	e.appel("PUT", "/navigations/"+id+"/evenements/"+p, nav, position(p, time.Now(), 2, 47.8732, -3.9188))
	if n, err := e.a.nommerUnLot(t.Context(), faux.Client()); err != nil || n != 2 || appels != 1 {
		t.Fatalf("noms : %d %v, %d appels", n, err, appels)
	}
	_, nv := e.appel("GET", "/navigations/"+id, nav, nil)
	if l := nv["lieuDepart"].(map[string]any); l["nom"] != "Concarneau" {
		t.Fatalf("lieu de départ : %v", l)
	}
}
