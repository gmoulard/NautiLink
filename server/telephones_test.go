package main

import (
	"slices"
	"testing"
	"time"
)

// secondTelephone : deuxième téléphone du même compte, connecté par sa
// propre session et enregistré sur le compte (RG-BAT-05).
func (e *essai) secondTelephone(email string) (jeton, appareil string) {
	e.t.Helper()
	code, s := e.appel("POST", "/sessions", "", map[string]string{"email": email, "motDePasse": "motdepasse"})
	if code != 200 && code != 201 {
		e.t.Fatalf("connexion du second téléphone : %d %v", code, s)
	}
	jeton, appareil = s["jetonAcces"].(string), uuid(e.t)
	if code, r := e.appel("PUT", "/appareils/"+appareil, jeton, map[string]any{"plateforme": "ios"}); code != 200 && code != 201 {
		e.t.Fatalf("enregistrement du second téléphone : %d %v", code, r)
	}
	return
}

// TestRejoindreNavigation : avec PostgreSQL : un autre téléphone du compte
// rejoint la navigation en cours (RG-NAV-39, D-177) ; il y envoie position
// manuelle, note et SOS ; positions automatiques et fin d'un téléphone du
// compte ne sont pas refusées (D-182) ; il n'a qu'une navigation en cours
// (RG-NAV-03).
func TestRejoindreNavigation(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	tel2Jeton, tel2 := e.secondTelephone("nav@exemple.org")
	t0 := time.Now().Add(-2 * time.Hour).Truncate(time.Second)
	id := uuid(t)
	d := demarrage(bateau, tel, t0, 47.70, -3.36)
	d["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d); code != 201 {
		t.Fatalf("démarrage : %d %v", code, r)
	}

	// Le second téléphone, non associé au bateau, ne démarre pas (RG-BAT-02)
	// mais rejoint ; un renvoi rend 200.
	if code, r := e.appel("PUT", "/navigations/"+id+"/rejoindre", tel2Jeton, map[string]any{"appareilId": tel2}); code != 201 ||
		r["appareilId"] != tel || !slices.Contains(r["telephonesRejoints"].([]any), any(tel2)) {
		t.Fatalf("rejoindre : %d %v", code, r)
	}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/rejoindre", tel2Jeton, map[string]any{"appareilId": tel2}); code != 200 {
		t.Fatalf("rejoindre de nouveau : %d", code)
	}
	// Le téléphone qui l'a démarrée : 200, rien de plus.
	if code, r := e.appel("PUT", "/navigations/"+id+"/rejoindre", nav, map[string]any{"appareilId": tel}); code != 200 ||
		len(r["telephonesRejoints"].([]any)) != 1 {
		t.Fatalf("rejoindre par le téléphone du démarrage : %d %v", code, r)
	}
	// Téléphone d'un autre compte, ou inconnu : refusé.
	if code, r := e.appel("PUT", "/navigations/"+id+"/rejoindre", tel2Jeton, map[string]any{"appareilId": uuid(t)}); code != 403 || r["code"] != "telephone_inconnu" {
		t.Fatalf("téléphone inconnu : %d %v", code, r)
	}
	autre := e.compte("autre@exemple.org", "Autre")
	autreTel := uuid(t)
	e.appel("PUT", "/appareils/"+autreTel, autre, map[string]any{"plateforme": "android"})
	if code, _ := e.appel("PUT", "/navigations/"+id+"/rejoindre", autre, map[string]any{"appareilId": autreTel}); code != 403 && code != 404 {
		t.Fatalf("téléphone d'un autre compte : %d", code)
	}

	// Positions manuelles, notes et SOS du second téléphone : au même journal.
	manuelle := position(uuid(t), t0.Add(10*time.Minute), 1, 47.71, -3.37)
	manuelle["type"], manuelle["origine"] = "position_manuelle", "ios"
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+manuelle["id"].(string), tel2Jeton, manuelle); code != 201 {
		t.Fatalf("position manuelle du second téléphone : %d %v", code, r)
	}
	note := map[string]any{"id": uuid(t), "type": "note", "heureAcquisition": heure(t0.Add(12 * time.Minute)), "numeroOrdre": 2, "texte": "Grain au loin"}
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+note["id"].(string), tel2Jeton, note); code != 201 {
		t.Fatalf("note du second téléphone : %d %v", code, r)
	}
	al := alerteSos(bateau, id, t0.Add(15*time.Minute), true)
	al["appareilId"] = tel2
	if code, r := e.appel("PUT", "/alertes-sos/"+uuid(t), tel2Jeton, al); code != 201 || r["navigationId"] != id {
		t.Fatalf("SOS du second téléphone : %d %v", code, r)
	}

	// La navigation appartient au compte (D-182) : une position automatique
	// d'un téléphone du compte est acceptée, quel qu'il soit (réinstallation).
	auto := position(uuid(t), t0.Add(30*time.Minute), 3, 47.72, -3.38)
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+auto["id"].(string), tel2Jeton, auto); code != 201 {
		t.Fatalf("position automatique du second téléphone : %d %v", code, r)
	}
	fin := map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(t0.Add(time.Hour)), "numeroOrdre": 9}
	_, j := e.appel("GET", "/navigations/"+id+"/evenements", nav, nil)
	var types []string
	for _, ev := range j["evenements"].([]any) {
		types = append(types, ev.(map[string]any)["type"].(string))
	}
	for _, ty := range []string{"debut", "position_manuelle", "note", "sos", "position_automatique"} {
		if !slices.Contains(types, ty) {
			t.Fatalf("journal de bord : %v, %s absent", types, ty)
		}
	}

	// Un téléphone, une navigation : le second téléphone, qui a rejoint, ne
	// démarre ni ne rejoint une autre navigation (RG-NAV-03).
	_, b2 := e.appel("POST", "/bateaux", nav, map[string]any{"nom": "Brise", "type": "voilier"})
	bateau2 := b2["id"].(string)
	if code, _ := e.appel("PUT", "/bateaux/"+bateau2+"/telephone", nav, map[string]any{"appareilId": tel2}); code != 200 {
		t.Fatalf("association du second bateau : %d", code)
	}
	d2 := demarrage(bateau2, tel2, t0.Add(20*time.Minute), 43.1, 5.9)
	d2["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+uuid(t), tel2Jeton, d2); code != 409 || r["code"] != "navigation_en_cours" {
		t.Fatalf("démarrage par un téléphone qui a rejoint : %d %v", code, r)
	}

	// Fin par le second téléphone, acceptée (D-182) : il est libre.
	if code, r := e.appel("PUT", "/navigations/"+id+"/fin", tel2Jeton, fin); code != 200 {
		t.Fatalf("fin : %d %v", code, r)
	}
	if code, r := e.appel("PUT", "/navigations/"+id+"/rejoindre", tel2Jeton, map[string]any{"appareilId": tel2}); code != 409 || r["code"] != "navigation_terminee" {
		t.Fatalf("rejoindre une navigation terminée : %d %v", code, r)
	}
	if code, r := e.appel("PUT", "/navigations/"+uuid(t), tel2Jeton, d2); code != 201 {
		t.Fatalf("démarrage après la fin : %d %v", code, r)
	}
}

// TestDeuxNavigationsEnParallele : avec PostgreSQL : un même compte a deux
// navigations en cours en même temps, sur deux bateaux et deux téléphones
// (RG-NAV-03, D-177) ; chacune reçoit les positions automatiques de son
// téléphone ; un téléphone qui a une navigation n'en rejoint pas une autre.
func TestDeuxNavigationsEnParallele(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	tel2Jeton, tel2 := e.secondTelephone("nav@exemple.org")
	_, b2 := e.appel("POST", "/bateaux", nav, map[string]any{"nom": "Brise", "type": "voilier"})
	bateau2 := b2["id"].(string)
	if code, _ := e.appel("PUT", "/bateaux/"+bateau2+"/telephone", nav, map[string]any{"appareilId": tel2}); code != 200 {
		t.Fatalf("association du second bateau : %d", code)
	}
	t0 := time.Now().Add(-2 * time.Hour).Truncate(time.Second)
	id1, id2 := uuid(t), uuid(t)
	d1 := demarrage(bateau, tel, t0, 47.70, -3.36)
	d1["debut"].(map[string]any)["id"] = uuid(t)
	d2 := demarrage(bateau2, tel2, t0.Add(5*time.Minute), 43.10, 5.90)
	d2["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+id1, nav, d1); code != 201 {
		t.Fatalf("démarrage 1 : %d %v", code, r)
	}
	if code, r := e.appel("PUT", "/navigations/"+id2, tel2Jeton, d2); code != 201 {
		t.Fatalf("démarrage 2 en parallèle : %d %v", code, r)
	}
	p1 := position(uuid(t), t0.Add(30*time.Minute), 2, 47.71, -3.37)
	p2 := position(uuid(t), t0.Add(35*time.Minute), 2, 43.11, 5.91)
	if code, _ := e.appel("PUT", "/navigations/"+id1+"/evenements/"+p1["id"].(string), nav, p1); code != 201 {
		t.Fatalf("position de la navigation 1 : %d", code)
	}
	if code, _ := e.appel("PUT", "/navigations/"+id2+"/evenements/"+p2["id"].(string), tel2Jeton, p2); code != 201 {
		t.Fatalf("position de la navigation 2 : %d", code)
	}
	if code, r := e.appel("PUT", "/navigations/"+id1+"/rejoindre", tel2Jeton, map[string]any{"appareilId": tel2}); code != 409 || r["code"] != "navigation_en_cours" {
		t.Fatalf("rejoindre avec une navigation en cours : %d %v", code, r)
	}
	code, l := e.appel("GET", "/navigations?etat=en_cours", nav, nil)
	if n, _ := l["navigations"].([]any); code != 200 || len(n) != 2 {
		t.Fatalf("navigations en cours du compte : %d %v", code, l)
	}
}
