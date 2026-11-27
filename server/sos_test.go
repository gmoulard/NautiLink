package main

import (
	"errors"
	"slices"
	"strings"
	"testing"
	"time"
)

// recusPar : adresses qui ont reçu un e-mail dont le sujet contient motif,
// depuis le rang depuis du courrier d'essai.
func (c *courrierEssai) recusPar(depuis int, motif string) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var l []string
	for _, m := range c.recus[depuis:] {
		if strings.Contains(m.Sujet, motif) {
			l = append(l, m.A)
		}
	}
	slices.Sort(l)
	return l
}

func (c *courrierEssai) texte(depuis int, a, motif string) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, m := range c.recus[depuis:] {
		if m.A == a && strings.Contains(m.Sujet, motif) {
			return m.Texte
		}
	}
	return ""
}

func memes(t *testing.T, quoi string, obtenu []string, attendu ...string) {
	t.Helper()
	slices.Sort(attendu)
	if !slices.Equal(obtenu, attendu) {
		t.Fatalf("%s : %v, attendu %v", quoi, obtenu, attendu)
	}
}

func alerteSos(bateau string, navigation any, h time.Time, position bool) map[string]any {
	al := map[string]any{"bateauId": bateau, "navigationId": navigation, "heureDeclenchement": heure(h),
		"problemeRencontre": "Voie d'eau", "naturePosition": "actuelle"}
	if position {
		al["position"] = map[string]any{"latitude": 47.71234, "longitude": -3.36789, "heureAcquisition": heure(h)}
	}
	return al
}

func TestAlerteSos(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	contact := func(nom, telephone, email string) string {
		corps := map[string]any{"nom": nom, "telephone": telephone, "suiveur": false}
		if email != "" {
			corps["email"] = email
		}
		code, k := e.appel("POST", "/contacts", nav, corps)
		if code != 201 {
			t.Fatalf("contact %s : %d %v", nom, code, k)
		}
		return k["id"].(string)
	}
	secours := contact("Secours", "06 11 11 11 11", "secours@exemple.org")
	sansMail := contact("Sans e-mail", "06 22 22 22 22", "")
	contact("Décoché", "06 33 33 33 33", "decoche@exemple.org")
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	zoe := e.compte("zoe@exemple.org", "Zoé")
	e.suivre(nav, zoe, "zoe@exemple.org", "navigateur", "")
	e.appel("PATCH", "/compte", zoe, map[string]any{"emailsDebut": false})
	marc := e.compte("marc@exemple.org", "Marc")
	e.suivre(nav, marc, "marc@exemple.org", "navigateur", "")

	// Démarrage : Marc et « Décoché » décochés (RG-NAV-25) ; e-mail de début
	// aux suiveurs cochés non désinscrits, copie au navigateur (RG-NOT-02,
	// RG-NOT-03).
	t0 := time.Now().Add(-2 * time.Hour).Truncate(time.Second)
	id := uuid(t)
	d := demarrage(bateau, tel, t0, 47.70, -3.36)
	d["debut"].(map[string]any)["id"] = uuid(t)
	d["personnesAlertees"] = []string{contactParEmail(e, nav, "lea@exemple.org")["id"].(string),
		contactParEmail(e, nav, "zoe@exemple.org")["id"].(string), secours, sansMail}
	n0 := e.courrier.nombre()
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d); code != 201 {
		t.Fatalf("démarrage : %d %v", code, r)
	}
	memes(t, "e-mails de début", e.courrier.recusPar(n0, "démarré une navigation"), "lea@exemple.org", "nav@exemple.org")
	if txt := e.courrier.texte(n0, "lea@exemple.org", "démarré"); !strings.Contains(txt, "Glénan") ||
		!strings.Contains(txt, "https://exemple.org/nautilink/navigations/"+id) {
		t.Fatalf("texte de l'e-mail de début : %q", txt)
	}
	// Paul suit cette navigation seulement, après le démarrage, et le contact
	// SOS « Tardif » est créé après le démarrage : prévenus (RG-SOS-21,
	// D-122). « Décoché », créé avant, reste non prévenu.
	paul := e.compte("paul@exemple.org", "Paul")
	e.suivre(nav, paul, "paul@exemple.org", "navigation", id)
	contact("Tardif", "06 44 44 44 44", "tardif@exemple.org")

	// SOS en navigation, même avec une adresse non confirmée (RG-SOS-03) :
	// e-mail aux amis qui suivent la navigation et aux autres amis avec e-mail (D-176), copie au navigateur.
	e.a.b.pool.Exec(t.Context(), "UPDATE utilisateurs SET email_verifie_le = NULL WHERE email = 'nav@exemple.org'")
	sos := uuid(t)
	al := alerteSos(bateau, id, t0.Add(time.Hour), true)
	n0 = e.courrier.nombre()
	code, r := e.appel("PUT", "/alertes-sos/"+sos, nav, al)
	if code != 201 || r["navigationId"] != id || r["naturePosition"] != "actuelle" || r["personnesABord"] != 2.0 {
		t.Fatalf("SOS : %d %v", code, r)
	}
	tous := []string{"lea@exemple.org", "zoe@exemple.org", "paul@exemple.org", "secours@exemple.org", "tardif@exemple.org"}
	memes(t, "e-mails SOS", e.courrier.recusPar(n0, "SOS — Alizé"), append(tous, "nav@exemple.org")...)
	envoyes := []string{}
	for _, x := range r["emailsEnvoyesA"].([]any) {
		envoyes = append(envoyes, x.(string))
	}
	slices.Sort(envoyes)
	memes(t, "emailsEnvoyesA", envoyes, append(tous, "nav@exemple.org")...)
	txt := e.courrier.texte(n0, "secours@exemple.org", "SOS")
	for _, attendu := range []string{"ALERTE SOS", "Voie d'eau", "Personnes à bord : 2", "47.71234, -3.36789",
		"https://www.google.com/maps?q=47.71234,-3.36789", "https://exemple.org/nautilink/navigations/" + id} {
		if !strings.Contains(txt, attendu) {
			t.Fatalf("texte de l'e-mail SOS sans %q : %q", attendu, txt)
		}
	}
	if c := e.courrier.texte(n0, "nav@exemple.org", "Copie — SOS"); !strings.Contains(c, "secours@exemple.org") {
		t.Fatalf("copie au navigateur : %q", c)
	}
	// Rejouable sans doublon ; contenu différent : 409.
	n0 = e.courrier.nombre()
	if code, _ := e.appel("PUT", "/alertes-sos/"+sos, nav, al); code != 200 || e.courrier.nombre() != n0 {
		t.Fatalf("renvoi du SOS : %d, %d e-mails", code, e.courrier.nombre()-n0)
	}
	al2 := alerteSos(bateau, id, t0.Add(time.Hour), false)
	if code, r := e.appel("PUT", "/alertes-sos/"+sos, nav, al2); code != 409 || r["code"] != "evenement_different" {
		t.Fatalf("SOS différent : %d %v", code, r)
	}
	// Un suiveur n'envoie pas de SOS pour la navigation d'un autre.
	if code, _ := e.appel("PUT", "/alertes-sos/"+uuid(t), lea, al); code != 403 {
		t.Fatalf("SOS par un suiveur : %d", code)
	}
	// Enregistré dans le journal, non modifiable (RG-JRN-02, RG-JRN-07).
	_, j := e.appel("GET", "/navigations/"+id+"/evenements", lea, nil)
	var trouve bool
	for _, ev := range j["evenements"].([]any) {
		if m := ev.(map[string]any); m["type"] == "sos" && m["alerteSosId"] == sos {
			trouve = true
		}
	}
	if !trouve {
		t.Fatalf("SOS absent du journal : %v", j)
	}
	if code, _ := e.appel("PATCH", "/navigations/"+id+"/evenements/"+sos, nav, map[string]any{"texte": "x"}); code != 403 {
		t.Fatalf("SOS modifiable : %d", code)
	}

	// Statuts des SMS SOS (RG-SOS-12) ; un statut plus ancien ne remplace pas.
	h := time.Now().Truncate(time.Second)
	statuts := []map[string]any{
		{"contactId": secours, "telephone": "06 11 11 11 11", "rang": 1, "statut": "livraison_confirmee", "essais": 1, "misAJourLe": heure(h)},
		{"contactId": nil, "telephone": "06 00 00 00 00", "rang": 1, "statut": "accepte_pour_envoi", "essais": 1, "misAJourLe": heure(h)},
	}
	if code, _ := e.appelBrut("PUT", "/alertes-sos/"+sos+"/sms", nav, statuts); code != 204 {
		t.Fatalf("statuts des SMS : %d", code)
	}
	vieux := []map[string]any{{"contactId": secours, "telephone": "06 11 11 11 11", "rang": 1, "statut": "en_attente",
		"essais": 0, "misAJourLe": heure(h.Add(-time.Minute))}}
	if code, _ := e.appelBrut("PUT", "/alertes-sos/"+sos+"/sms", nav, vieux); code != 204 {
		t.Fatalf("statut ancien : %d", code)
	}
	if code, _ := e.appelBrut("PUT", "/alertes-sos/"+sos+"/sms", nav, []map[string]any{{"telephone": "1", "rang": 3, "statut": "x"}}); code != 422 {
		t.Fatalf("statut invalide : %d", code)
	}
	if code, _ := e.appelBrut("PUT", "/alertes-sos/"+sos+"/sms", lea, statuts); code != 404 {
		t.Fatalf("statuts par un suiveur : %d", code)
	}
	_, l := e.liste("GET", "/alertes-sos?navigationId="+id, lea, nil)
	if len(l) != 1 || len(l[0]["sms"].([]any)) != 2 {
		t.Fatalf("historique vu du suiveur : %v", l)
	}
	for _, s := range l[0]["sms"].([]any) {
		if m := s.(map[string]any); m["telephone"] == "06 11 11 11 11" && m["statut"] != "livraison_confirmee" {
			t.Fatalf("statut remplacé par un plus ancien : %v", m)
		}
	}
	autre := e.compte("autre@exemple.org", "Autre")
	if _, l := e.liste("GET", "/alertes-sos?bateauId="+bateau, autre, nil); len(l) != 0 {
		t.Fatalf("historique vu sans accès : %v", l)
	}

	// Fin, puis SOS déclenché après la fin : rattaché à la navigation,
	// inscrit dans son journal, e-mails à ses destinataires (RG-SOS-19,
	// D-120).
	fin := map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(t0.Add(90 * time.Minute))}
	if code, _ := e.appel("PUT", "/navigations/"+id+"/fin", nav, fin); code != 200 {
		t.Fatalf("fin : %d", code)
	}
	tard := uuid(t)
	n0 = e.courrier.nombre()
	code, r = e.appel("PUT", "/alertes-sos/"+tard, nav, alerteSos(bateau, id, t0.Add(100*time.Minute), false))
	if code != 201 || r["navigationId"] != id || r["naturePosition"] != "aucune" {
		t.Fatalf("SOS après la fin : %d %v", code, r)
	}
	memes(t, "e-mails du SOS après la fin", e.courrier.recusPar(n0, "SOS — Alizé"), append(tous, "nav@exemple.org")...)
	if txt := e.courrier.texte(n0, "lea@exemple.org", "SOS"); !strings.Contains(txt, "aucune position connue") ||
		!strings.Contains(txt, "https://exemple.org/nautilink/navigations/"+id) {
		t.Fatalf("SOS après la fin sans position : %q", txt)
	}
	// Dans le journal, non modifiable et jamais masqué, même après un
	// changement des heures affichées qui l'exclut de la plage (RG-NAV-22).
	if code, r := e.appel("PATCH", "/navigations/"+id, nav, map[string]any{"debut": heure(t0.Add(70 * time.Minute)),
		"fin": heure(t0.Add(80 * time.Minute))}); code != 200 {
		t.Fatalf("modification des heures : %d %v", code, r)
	}
	_, j = e.appel("GET", "/navigations/"+id+"/evenements", lea, nil)
	vus := 0
	for _, ev := range j["evenements"].([]any) {
		if m := ev.(map[string]any); m["type"] == "sos" {
			vus++
			if m["masque"] != false {
				t.Fatalf("SOS masqué : %v", m)
			}
		}
	}
	if vus != 2 {
		t.Fatalf("SOS du journal : %d, attendu 2 : %v", vus, j)
	}
	if code, _ := e.appel("PATCH", "/navigations/"+id+"/evenements/"+tard, nav, map[string]any{"texte": "x"}); code != 403 {
		t.Fatalf("SOS après la fin modifiable : %d", code)
	}

	// SOS depuis l'accueil (RG-SOS-15) : tous les amis avec e-mail, Paul
	// (périmètre navigation) compris (D-176).
	n0 = e.courrier.nombre()
	code, r = e.appel("PUT", "/alertes-sos/"+uuid(t), nav, alerteSos(bateau, nil, t0.Add(110*time.Minute), false))
	if code != 201 || r["navigationId"] != nil {
		t.Fatalf("SOS depuis l'accueil : %d %v", code, r)
	}
	memes(t, "e-mails du SOS depuis l'accueil", e.courrier.recusPar(n0, "SOS — Alizé"), "lea@exemple.org", "zoe@exemple.org",
		"marc@exemple.org", "paul@exemple.org", "secours@exemple.org", "decoche@exemple.org", "tardif@exemple.org", "nav@exemple.org")
	// Historique du bateau : Marc (périmètre navigateur) voit les trois, Paul
	// (périmètre navigation) seulement ceux de sa navigation (RG-SOS-20).
	if _, l := e.liste("GET", "/alertes-sos?bateauId="+bateau, marc, nil); len(l) != 3 {
		t.Fatalf("historique de Marc : %v", l)
	}
	if _, l := e.liste("GET", "/alertes-sos?bateauId="+bateau, paul, nil); len(l) != 2 || l[0]["id"] != tard || l[1]["id"] != sos {
		t.Fatalf("historique de Paul : %v", l)
	}
	if _, l := e.liste("GET", "/alertes-sos?bateauId="+bateau, nav, nil); len(l) != 3 {
		t.Fatalf("historique du navigateur : %v", l)
	}

	// Navigation clôturée automatiquement (RG-ECO-12) : un SOS déclenché
	// après la clôture reste un SOS depuis l'accueil, absent du journal.
	id2 := uuid(t)
	t1 := t0.Add(105 * time.Minute)
	d2 := demarrage(bateau, tel, t1, 47.70, -3.36)
	d2["debut"].(map[string]any)["id"] = uuid(t)
	e.a.b.pool.Exec(t.Context(), "UPDATE utilisateurs SET email_verifie_le = now() WHERE email = 'nav@exemple.org'")
	if code, r := e.appel("PUT", "/navigations/"+id2, nav, d2); code != 201 {
		t.Fatalf("démarrage 2 : %d %v", code, r)
	}
	cl := t1.Add(5 * time.Minute)
	if _, err := e.a.b.pool.Exec(t.Context(), `UPDATE navigations SET fin_enregistree = $2, fin = $2,
		cloture_automatique_le = $2 WHERE id = $1`, id2, cl); err != nil {
		t.Fatal(err)
	}
	n0 = e.courrier.nombre()
	code, r = e.appel("PUT", "/alertes-sos/"+uuid(t), nav, alerteSos(bateau, id2, cl.Add(time.Minute), true))
	if code != 201 || r["navigationId"] != nil {
		t.Fatalf("SOS après la clôture automatique : %d %v", code, r)
	}
	if l := e.courrier.recusPar(n0, "SOS — Alizé"); !slices.Contains(l, "decoche@exemple.org") {
		t.Fatalf("e-mails du SOS après la clôture automatique : %v", l)
	}
	_, j = e.appel("GET", "/navigations/"+id2+"/evenements", nav, nil)
	for _, ev := range j["evenements"].([]any) {
		if ev.(map[string]any)["type"] == "sos" {
			t.Fatalf("SOS après la clôture automatique dans le journal : %v", j)
		}
	}
	// Déclenché avant la clôture automatique : rattaché à la navigation.
	code, r = e.appel("PUT", "/alertes-sos/"+uuid(t), nav, alerteSos(bateau, id2, cl.Add(-time.Minute), true))
	if code != 201 || r["navigationId"] != id2 {
		t.Fatalf("SOS avant la clôture automatique : %d %v", code, r)
	}
	// Bateau d'un autre : refusé.
	_, autreBateau, _ := e.marin("autre2@exemple.org", "Autre 2", "Brise")
	if code, _ := e.appel("PUT", "/alertes-sos/"+uuid(t), nav, alerteSos(autreBateau, nil, time.Now(), true)); code != 403 {
		t.Fatalf("SOS sur le bateau d'un autre : %d", code)
	}
}

func TestAlerteSosRelanceEtLot(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, _ := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	e.appel("PATCH", "/compte", nav, map[string]any{"langue": "en"})
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")

	// Relais en panne pour Léa : l'adresse n'est pas comptée envoyée, puis
	// la relance de la minute suivante la rattrape (RG-SOS-18).
	envoyer := e.a.envoyer
	e.a.envoyer = func(dest, sujet, texte string) error {
		if dest == "lea@exemple.org" {
			return errors.New("relais indisponible")
		}
		return envoyer(dest, sujet, texte)
	}
	sos := uuid(t)
	_, res := e.appel("POST", "/synchronisation", nav, map[string]any{"elements": []map[string]any{
		{"operation": "alerte_sos", "id": sos, "contenu": alerteSos(bateau, nil, time.Now(), true)},
		{"operation": "statuts_sms", "id": sos, "contenu": []map[string]any{{"telephone": "06 11", "rang": 1, "statut": "echec", "essais": 3}}},
	}})
	rs := res["resultats"].([]any)
	if rs[0].(map[string]any)["statut"] != 201.0 || rs[1].(map[string]any)["statut"] != 204.0 {
		t.Fatalf("lot : %v", rs)
	}
	_, l := e.liste("GET", "/alertes-sos", nav, nil)
	if len(l) != 1 || len(l[0]["emailsEnvoyesA"].([]any)) != 1 || len(l[0]["sms"].([]any)) != 1 {
		t.Fatalf("après l'échec : %v", l)
	}
	// Moins d'une minute après la réception : pas de relance.
	e.a.envoyer = envoyer
	n0 := e.courrier.nombre()
	if err := e.a.relancerEmailsSos(t.Context()); err != nil || e.courrier.nombre() != n0 {
		t.Fatalf("relance trop tôt : %v, %d e-mails", err, e.courrier.nombre()-n0)
	}
	horloge(e, time.Now().Add(2*time.Minute))
	if err := e.a.relancerEmailsSos(t.Context()); err != nil {
		t.Fatal(err)
	}
	memes(t, "relance", e.courrier.recusPar(n0, "SOS"), "lea@exemple.org")
	// E-mail dans la langue du navigateur (RG-PRM-04).
	if txt := e.courrier.texte(n0, "lea@exemple.org", "SOS"); !strings.Contains(txt, "SOS ALERT sent by Navigateur") {
		t.Fatalf("e-mail en anglais : %q", txt)
	}
	n0 = e.courrier.nombre()
	if err := e.a.relancerEmailsSos(t.Context()); err != nil || e.courrier.nombre() != n0 {
		t.Fatalf("seconde relance : %v, %d e-mails", err, e.courrier.nombre()-n0)
	}
	// Au-delà de 24 heures, plus de relance.
	horloge(e, time.Now().Add(25*time.Hour))
	e.a.b.pool.Exec(t.Context(), "UPDATE alertes_sos SET emails_envoyes_a = '{}'")
	if err := e.a.relancerEmailsSos(t.Context()); err != nil || e.courrier.nombre() != n0 {
		t.Fatalf("relance après 24 heures : %v, %d e-mails", err, e.courrier.nombre()-n0)
	}
}
