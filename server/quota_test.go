package main

import (
	"testing"
	"time"
)

// naviguer : navigation de debut à fin (fin nulle : laissée en cours).
func (e *essai) naviguer(jeton, bateau, tel string, debut time.Time, fin *time.Time) (string, int, map[string]any) {
	e.t.Helper()
	id := uuid(e.t)
	d := demarrage(bateau, tel, debut, 47, -3)
	d["debut"].(map[string]any)["id"] = uuid(e.t)
	code, r := e.appel("PUT", "/navigations/"+id, jeton, d)
	if code == 201 && fin != nil {
		if c, x := e.appel("PUT", "/navigations/"+id+"/fin", jeton, map[string]any{"id": uuid(e.t), "type": "fin",
			"heureAcquisition": heure(*fin)}); c != 200 {
			e.t.Fatalf("fin : %d %v", c, x)
		}
	}
	return id, code, r
}

func horloge(e *essai, t time.Time) { e.a.maintenant = func() time.Time { return t } }

// Exemple du modèle économique : 10 h le lundi à partir de 9 h, 14 h le
// mercredi ; quota épuisé le mercredi soir ; les minutes du lundi
// redeviennent disponibles le lundi suivant à partir de 9 h.
func TestQuotaGlissant(t *testing.T) {
	e := nouvelEssai(t)
	paris := time.FixedZone("Paris", 3600)
	lundi := time.Date(2026, 11, 16, 9, 0, 0, 0, paris)
	mercredi := time.Date(2026, 11, 18, 8, 0, 0, 0, paris)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	horloge(e, lundi)
	f1 := lundi.Add(10 * time.Hour)
	e.naviguer(nav, bateau, tel, lundi, &f1)
	horloge(e, mercredi)
	f2 := mercredi.Add(14 * time.Hour)
	e.naviguer(nav, bateau, tel, mercredi, &f2)

	horloge(e, mercredi.Add(14*time.Hour+30*time.Minute))
	_, q := e.appel("GET", "/quota", nav, nil)
	prochaines := q["prochainesMinutes"].([]any)
	if q["consommeMinutes"] != 1440.0 || q["disponibleMinutes"] != 0.0 || q["epuise"] != true || len(prochaines) != 2 ||
		prochaines[0].(map[string]any)["minutes"] != 600.0 || prochaines[0].(map[string]any)["disponiblesLe"] != "2026-11-23T08:00:00Z" {
		t.Fatalf("quota épuisé : %v", q)
	}
	// Démarrage refusé, avec l'heure du retour des minutes (RG-ECO-04).
	_, code, r := e.naviguer(nav, bateau, tel, mercredi.Add(15*time.Hour), nil)
	if code != 409 || r["code"] != "quota_epuise" || r["disponibleLe"] != "2026-11-23T08:00:00Z" {
		t.Fatalf("démarrage, quota épuisé : %d %v", code, r)
	}
	// Lundi suivant 9 h 30 : minutes de 9 h à 9 h 30 revenues, minute par minute.
	horloge(e, lundi.Add(7*24*time.Hour+30*time.Minute))
	if _, q = e.appel("GET", "/quota", nav, nil); q["disponibleMinutes"] != 31.0 || q["epuise"] != false {
		t.Fatalf("minutes revenues : %v", q)
	}
	// Changer les heures ne change pas le quota (RG-ECO-02).
	horloge(e, mercredi.Add(15*time.Hour))
	_, l := e.appel("GET", "/navigations", nav, nil)
	id := l["navigations"].([]any)[0].(map[string]any)["id"].(string)
	e.appel("PATCH", "/navigations/"+id, nav, map[string]any{"debut": heure(mercredi.Add(10 * time.Hour))})
	if _, q = e.appel("GET", "/quota", nav, nil); q["consommeMinutes"] != 1440.0 {
		t.Fatalf("quota après changement d'heures : %v", q)
	}
	// Un abonnement actif lève la limite (RG-ECO-06).
	e.abonner("nav@exemple.org")
	if _, code, r := e.naviguer(nav, bateau, tel, mercredi.Add(15*time.Hour), nil); code != 201 {
		t.Fatalf("démarrage avec abonnement : %d %v", code, r)
	}
}

func (e *essai) abonner(email string) {
	e.t.Helper()
	if _, err := e.a.b.pool.Exec(e.t.Context(), `INSERT INTO abonnements (utilisateur_id, canal, debut, fin)
		SELECT id, 'web', '2026-01-01T00:00:00Z', '2036-01-01T00:00:00Z' FROM utilisateurs WHERE email = $1`, email); err != nil {
		e.t.Fatal(err)
	}
}

// Clôture automatique 24 heures après l'épuisement (RG-ECO-05) ; envois
// acquis après la clôture refusés (RG-ECO-12) ; annulée par un abonnement.
func TestClotureAutomatique(t *testing.T) {
	e := nouvelEssai(t)
	utc := time.UTC
	lundi := time.Date(2026, 11, 16, 8, 0, 0, 0, utc)
	mercredi := time.Date(2026, 11, 18, 7, 0, 0, 0, utc)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	horloge(e, lundi)
	f1 := lundi.Add(10 * time.Hour)
	e.naviguer(nav, bateau, tel, lundi, &f1)
	horloge(e, mercredi)
	id, _, _ := e.naviguer(nav, bateau, tel, mercredi, nil)

	horloge(e, mercredi.Add(14*time.Hour+30*time.Minute))
	if err := e.a.cloturesAutomatiques(t.Context()); err != nil {
		t.Fatal(err)
	}
	epuise := mercredi.Add(14 * time.Hour)
	if _, q := e.appel("GET", "/quota", nav, nil); q["clotureAutomatiqueLe"] != heure(epuise.Add(24*time.Hour)) {
		t.Fatalf("heure de clôture annoncée : %v", q)
	}
	// La navigation continue jusqu'à 24 heures après l'épuisement.
	horloge(e, epuise.Add(23*time.Hour))
	e.a.cloturesAutomatiques(t.Context())
	if _, n := e.appel("GET", "/navigations/"+id, nav, nil); n["etat"] != "en_cours" {
		t.Fatalf("navigation avant la clôture : %v", n)
	}
	horloge(e, epuise.Add(24*time.Hour+5*time.Minute))
	e.a.cloturesAutomatiques(t.Context())
	cloture := epuise.Add(24 * time.Hour)
	if _, n := e.appel("GET", "/navigations/"+id, nav, nil); n["etat"] != "terminee" || n["clotureAutomatiqueLe"] != heure(cloture) || n["fin"] != heure(cloture) {
		t.Fatalf("navigation clôturée : %v", n)
	}
	avant, apres := uuid(t), uuid(t)
	if code, _ := e.appel("PUT", "/navigations/"+id+"/evenements/"+avant, nav, position(avant, cloture.Add(-time.Hour), 7, 47, -3)); code != 201 {
		t.Fatalf("position acquise avant la clôture : %d", code)
	}
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+apres, nav, position(apres, cloture.Add(time.Minute), 8, 47, -3)); code != 409 || r["code"] != "navigation_cloturee" {
		t.Fatalf("position acquise après la clôture : %d %v", code, r)
	}
	if code, r := e.appel("PUT", "/navigations/"+id+"/fin", nav, map[string]any{"id": uuid(t), "type": "fin",
		"heureAcquisition": heure(cloture.Add(2 * time.Minute))}); code != 409 || r["code"] != "navigation_cloturee" {
		t.Fatalf("fin acquise après la clôture : %d %v", code, r)
	}

	// Abonnement souscrit pendant les 24 heures : clôture annulée.
	nav2, bateau2, tel2 := e.marin("nav2@exemple.org", "Navigateur 2", "Brise")
	horloge(e, lundi)
	e.naviguer(nav2, bateau2, tel2, lundi, &f1)
	horloge(e, mercredi)
	id2, _, _ := e.naviguer(nav2, bateau2, tel2, mercredi, nil)
	horloge(e, mercredi.Add(15*time.Hour))
	e.a.cloturesAutomatiques(t.Context())
	e.abonner("nav2@exemple.org")
	horloge(e, mercredi.Add(40*time.Hour))
	e.a.cloturesAutomatiques(t.Context())
	if _, n := e.appel("GET", "/navigations/"+id2, nav2, nil); n["etat"] != "en_cours" {
		t.Fatalf("clôture annulée par l'abonnement : %v", n)
	}
}
