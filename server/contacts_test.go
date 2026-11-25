package main

import (
	"strings"
	"testing"
)

func TestContacts(t *testing.T) {
	e := nouvelEssai(t)
	j := e.compte("nav@exemple.org", "Navigateur")

	// Un contact demande un téléphone ou un e-mail (RG-CTC-01).
	if code, _ := e.appel("POST", "/contacts", j, map[string]any{"nom": "Vide", "suiveur": false}); code != 422 {
		t.Fatalf("sans téléphone ni e-mail : %d", code)
	}
	// « Suiveur » coché par défaut : le périmètre doit être choisi (RG-CTC-04).
	if code, _ := e.appel("POST", "/contacts", j, map[string]any{"nom": "Léa", "email": "lea@exemple.org"}); code != 422 {
		t.Fatalf("suiveur sans périmètre : %d", code)
	}
	// Par défaut suiveur et contact SOS (RG-CTC-01) ; invitation envoyée par e-mail, copie au navigateur.
	code, k := e.appel("POST", "/contacts", j, map[string]any{"nom": "Léa", "email": "lea@exemple.org",
		"telephone": "06 11 22 33 44", "perimetre": "navigateur"})
	if code != 201 || k["suiveur"] != true || k["contactSos"] != true || k["etatInvitation"] != "envoyee" || k["telephone"] != "+33611223344" {
		t.Fatalf("contact : %d %v", code, k)
	}
	lea := k["id"].(string)
	invitation := e.courrier.dernier(t, "lea@exemple.org")
	if !strings.Contains(invitation, "Navigateur vous invite") || !strings.Contains(invitation, "https://exemple.org/nautilink/invitation?jeton=") {
		t.Fatalf("e-mail d'invitation : %q", invitation)
	}
	if copie := e.courrier.dernier(t, "nav@exemple.org"); !strings.Contains(copie, "Copie de l'invitation") {
		t.Fatalf("copie au navigateur : %q", copie)
	}
	// Sans numéro : « Contact SOS » décoché, et refusé s'il est demandé (RG-CTC-05).
	_, k = e.appel("POST", "/contacts", j, map[string]any{"nom": "Max", "email": "max@exemple.org", "suiveur": false})
	if k["contactSos"] != false {
		t.Fatalf("contact SOS sans numéro : %v", k)
	}
	max := k["id"].(string)
	if code, r := e.appel("PATCH", "/contacts/"+max, j, map[string]any{"contactSos": true}); code != 422 || r["code"] != "contact_sos_sans_telephone" {
		t.Fatalf("contact SOS sans numéro demandé : %d %v", code, r)
	}
	// Ajout hors connexion : identifiant tiré par le téléphone, renvoi sans doublon.
	idHC := "44444444-4444-4444-8444-444444444444"
	corps := map[string]any{"id": idHC, "nom": "Hors connexion", "telephone": "+33600000001", "suiveur": false}
	if code, _ := e.appel("POST", "/contacts", j, corps); code != 201 {
		t.Fatalf("ajout hors connexion : %d", code)
	}
	if code, _ := e.appel("POST", "/contacts", j, corps); code != 200 {
		t.Fatalf("renvoi : %d", code)
	}

	// Synchronisation : `depuis` ne rend que les changements, suppressions comprises (RG-CTC-03).
	_, l := e.appel("GET", "/contacts", j, nil)
	if n := len(l["contacts"].([]any)); n != 3 {
		t.Fatalf("liste : %d contacts", n)
	}
	curseur := l["curseur"].(string)
	e.appel("PATCH", "/contacts/"+max, j, map[string]any{"nom": "Maxime"})
	if code, _ := e.appel("DELETE", "/contacts/"+idHC, j, nil); code != 204 {
		t.Fatalf("suppression : %d", code)
	}
	_, l = e.appel("GET", "/contacts?depuis="+curseur, j, nil)
	if c := l["contacts"].([]any); len(c) != 1 || c[0].(map[string]any)["nom"] != "Maxime" {
		t.Fatalf("changements : %v", l)
	}
	if s := l["supprimes"].([]any); len(s) != 1 || s[0] != idHC {
		t.Fatalf("suppressions : %v", l)
	}
	// Modification partielle : le téléphone reste (RG-COM-04).
	if _, k := e.appel("PATCH", "/contacts/"+lea, j, map[string]any{"nom": "Léa M."}); k["telephone"] != "+33611223344" || k["nom"] != "Léa M." {
		t.Fatalf("modification partielle : %v", k)
	}
	// Retirer le numéro décoche « Contact SOS ».
	if _, k := e.appel("PATCH", "/contacts/"+lea, j, map[string]any{"telephone": nil}); k["contactSos"] != false {
		t.Fatalf("numéro retiré : %v", k)
	}
	// Un autre compte ne voit pas ces contacts.
	autre := e.compte("autre@exemple.org", "Autre")
	if _, l := e.appel("GET", "/contacts", autre, nil); len(l["contacts"].([]any)) != 0 {
		t.Fatal("contacts d'un autre compte visibles")
	}
	if code, _ := e.appel("PATCH", "/contacts/"+lea, autre, map[string]any{"nom": "X"}); code != 404 {
		t.Fatalf("modification par un autre compte : %d", code)
	}
}

func TestInvitationsEtAcces(t *testing.T) {
	e := nouvelEssai(t)
	nav := e.compte("nav@exemple.org", "Navigateur")
	_, b := e.appel("POST", "/bateaux", nav, map[string]any{"nom": "Alizé", "type": "voilier"})
	bateau := b["id"].(string)

	// Invitation par e-mail sans contact : l'invité est ajouté aux contacts (RG-PAR-03).
	code, inv := e.appel("POST", "/invitations", nav, map[string]any{"canal": "email", "email": "lea@exemple.org", "perimetre": "navigateur"})
	if code != 201 || inv["etat"] != "envoyee" {
		t.Fatalf("invitation : %d %v", code, inv)
	}
	_, l := e.appel("GET", "/contacts", nav, nil)
	contacts := l["contacts"].([]any)
	if len(contacts) != 1 || contacts[0].(map[string]any)["suiveur"] != true {
		t.Fatalf("invité absent des contacts : %v", l)
	}
	jetonLea := jetonDuTexte(t, e.courrier.dernier(t, "lea@exemple.org"))

	// Invitation par téléphone : pas d'e-mail, le lien est rendu (RG-PAR-04).
	n := e.courrier.nombre()
	code, invTel := e.appel("POST", "/invitations", nav, map[string]any{"canal": "telephone", "telephone": "+33612345678", "perimetre": "navigateur"})
	if code != 201 || !strings.HasPrefix(invTel["lien"].(string), "https://exemple.org/nautilink/invitation?jeton=") || e.courrier.nombre() != n {
		t.Fatalf("invitation par téléphone : %d %v", code, invTel)
	}
	if code, _ := e.appel("POST", "/invitations", nav, map[string]any{"canal": "email", "email": "x@exemple.org", "perimetre": "navigation"}); code != 422 {
		t.Fatalf("périmètre navigation sans navigation : %d", code)
	}

	// Aucun accès sans compte (RG-PAR-01) ; acceptation une fois connecté (RG-PAR-05).
	if code, _ := e.appel("POST", "/invitations/acceptation", "", map[string]string{"jetonInvitation": jetonLea}); code != 401 {
		t.Fatalf("acceptation sans compte : %d", code)
	}
	if code, _ := e.appel("POST", "/invitations/acceptation", nav, map[string]string{"jetonInvitation": jetonLea}); code != 422 {
		t.Fatalf("propre invitation : %d", code)
	}
	lea := e.compte("lea.perso@exemple.org", "Léa")
	if code, _ := e.appel("GET", "/bateaux/"+bateau, lea, nil); code != 404 {
		t.Fatalf("fiche vue avant l'accès : %d", code)
	}
	code, ac := e.appel("POST", "/invitations/acceptation", lea, map[string]string{"jetonInvitation": jetonLea})
	if code != 200 || ac["perimetre"] != "navigateur" || ac["suiveur"].(map[string]any)["nom"] != "Léa" {
		t.Fatalf("acceptation : %d %v", code, ac)
	}
	if !strings.Contains(e.courrier.dernier(t, "lea.perso@exemple.org"), "vous a donné accès") ||
		!strings.Contains(e.courrier.dernier(t, "nav@exemple.org"), "a accepté votre invitation") {
		t.Fatal("e-mails « nouvel accès » et copie absents")
	}
	if code, _ := e.appel("POST", "/invitations/acceptation", lea, map[string]string{"jetonInvitation": jetonLea}); code != 200 {
		t.Fatalf("acceptation rejouée : %d", code)
	}
	autre := e.compte("autre@exemple.org", "Autre")
	if code, r := e.appel("POST", "/invitations/acceptation", autre, map[string]string{"jetonInvitation": jetonLea}); code != 409 || r["code"] != "invitation_deja_acceptee" {
		t.Fatalf("invitation déjà acceptée : %d %v", code, r)
	}
	// Le suiveur voit la fiche du bateau (RG-PAR-08), sans pouvoir la modifier.
	if code, _ := e.appel("GET", "/bateaux/"+bateau, lea, nil); code != 200 {
		t.Fatalf("fiche vue par le suiveur : %d", code)
	}
	if code, _ := e.appel("PATCH", "/bateaux/"+bateau, lea, map[string]any{"nom": "X"}); code != 403 {
		t.Fatalf("fiche modifiée par le suiveur : %d", code)
	}
	if c := contactParEmail(e, nav, "lea@exemple.org"); c["etatInvitation"] != "acceptee" || c["utilisateurId"] != e.id(lea) {
		t.Fatalf("contact après acceptation : %v", c)
	}
	_, donnes := e.liste("GET", "/acces?role=navigateur", nav, nil)
	_, recus := e.liste("GET", "/acces?role=suiveur", lea, nil)
	if len(donnes) != 1 || len(recus) != 1 || donnes[0]["id"] != recus[0]["id"] {
		t.Fatalf("accès : %v %v", donnes, recus)
	}
	accesID := donnes[0]["id"].(string)
	// Le périmètre se change à tout moment (RG-PAR-02) ; un suiveur ne touche pas aux accès.
	nav1 := "55555555-5555-4555-8555-555555555555"
	// Une navigation qui n'est pas au navigateur est refusée ; le périmètre
	// navigation sur une vraie navigation est essayé dans navigations_test.go.
	if code, ac := e.appel("PATCH", "/acces/"+accesID, nav, map[string]any{"perimetre": "navigation", "navigationId": nav1}); code != 422 {
		t.Fatalf("périmètre sur une navigation inconnue : %d %v", code, ac)
	}
	e.appel("PATCH", "/acces/"+accesID, nav, map[string]any{"perimetre": "navigateur"})
	if code, _ := e.appel("DELETE", "/acces/"+accesID, lea, nil); code != 404 {
		t.Fatalf("retrait par le suiveur : %d", code)
	}
	// Retrait immédiat (RG-PAR-06) ; le contact n'est plus suiveur (RG-CTC-04).
	if code, _ := e.appel("DELETE", "/acces/"+accesID, nav, nil); code != 204 {
		t.Fatalf("retrait : %d", code)
	}
	if _, recus := e.liste("GET", "/acces?role=suiveur", lea, nil); len(recus) != 0 {
		t.Fatal("accès toujours présent")
	}
	if code, _ := e.appel("GET", "/bateaux/"+bateau, lea, nil); code != 404 {
		t.Fatalf("fiche vue après retrait : %d", code)
	}
	leaContact := contactParEmail(e, nav, "lea@exemple.org")
	if leaContact["suiveur"] != false {
		t.Fatalf("contact toujours suiveur : %v", leaContact)
	}
	// Recocher « Suiveur » renvoie une invitation ; la décocher l'annule.
	_, k := e.appel("PATCH", "/contacts/"+leaContact["id"].(string), nav, map[string]any{"suiveur": true, "perimetre": "navigateur"})
	if k["etatInvitation"] != "envoyee" {
		t.Fatalf("nouvelle invitation : %v", k)
	}
	_, k = e.appel("PATCH", "/contacts/"+leaContact["id"].(string), nav, map[string]any{"suiveur": false})
	if k["etatInvitation"] != "annulee" {
		t.Fatalf("invitation annulée en décochant : %v", k)
	}
	// Annulation d'une invitation en attente ; elle ne s'accepte plus.
	if code, _ := e.appel("DELETE", "/invitations/"+invTel["id"].(string), nav, nil); code != 204 {
		t.Fatalf("annulation : %d", code)
	}
	jetonTel := jetonDuTexte(t, invTel["lien"].(string))
	if code, _ := e.appel("POST", "/invitations/acceptation", autre, map[string]string{"jetonInvitation": jetonTel}); code != 404 {
		t.Fatalf("invitation annulée acceptée : %d", code)
	}
	if _, l := e.liste("GET", "/invitations", nav, nil); len(l) < 3 {
		t.Fatalf("invitations : %v", l)
	}
}

func TestPagesWebContacts(t *testing.T) {
	e := nouvelEssai(t)
	nav := e.navigateur()
	nav.envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Navigateur", "email": "nav@exemple.org",
		"motdepasse": "motdepasse", "avertissement": versionAvertissement})
	rec := nav.envoyer("POST", "/nautilink/contacts", map[string]string{"nom": "Paul", "telephone": "+33612345678",
		"suiveur": "on", "contactSos": "on", "perimetre": "navigateur"})
	if rec.Code != 303 {
		t.Fatalf("ajout : %d %s", rec.Code, rec.Body.String())
	}
	fiche := strings.Split(rec.Header().Get("Location"), "?")[0]
	page := nav.envoyer("GET", fiche, nil).Body.String()
	if !strings.Contains(page, "Transmettez ce lien") {
		t.Fatalf("lien d'invitation par téléphone non affiché : %s", page)
	}
	jeton := jetonDuTexte(t, page)

	// L'invité ouvre le lien sans compte, crée son compte, puis accepte.
	paul := e.navigateur()
	if rec := paul.envoyer("GET", "/nautilink/invitation?jeton="+jeton, nil); !strings.Contains(rec.Body.String(), "Navigateur</strong> vous invite") || !strings.Contains(rec.Body.String(), "Créer un compte") {
		t.Fatalf("page d'invitation : %s", rec.Body.String())
	}
	rec = paul.envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Paul", "email": "paul@exemple.org",
		"motdepasse": "motdepasse", "avertissement": versionAvertissement, "retour": "/nautilink/invitation?jeton=" + jeton})
	if loc := rec.Header().Get("Location"); !strings.HasPrefix(loc, "/nautilink/invitation?jeton=") {
		t.Fatalf("retour vers l'invitation : %q", loc)
	}
	if rec := paul.envoyer("POST", "/nautilink/invitation", map[string]string{"jeton": jeton}); rec.Code != 303 {
		t.Fatalf("acceptation : %d", rec.Code)
	}
	if rec := paul.envoyer("GET", "/nautilink/contacts", nil); !strings.Contains(rec.Body.String(), "Navigateur — toutes ses navigations") {
		t.Fatal("navigateur suivi absent")
	}
	page = nav.envoyer("GET", "/nautilink/contacts", nil).Body.String()
	if !strings.Contains(page, "Retirer") {
		t.Fatal("suiveur absent")
	}
	// Erreur de saisie réaffichée.
	if rec := nav.envoyer("POST", "/nautilink/contacts", map[string]string{"nom": "Sans moyen", "perimetre": "navigateur"}); rec.Code != 422 || !strings.Contains(rec.Body.String(), "Indiquez un numéro") {
		t.Fatalf("saisie invalide : %d", rec.Code)
	}
	if rec := nav.envoyer("POST", fiche+"/suppression", map[string]string{}); rec.Code != 303 {
		t.Fatalf("suppression : %d", rec.Code)
	}
	if rec := paul.envoyer("GET", "/nautilink/contacts", nil); strings.Contains(rec.Body.String(), "Navigateur — toutes ses navigations") {
		t.Fatal("accès gardé après suppression du contact")
	}
}

func contactParEmail(e *essai, jeton, email string) map[string]any {
	e.t.Helper()
	_, l := e.appel("GET", "/contacts", jeton, nil)
	for _, c := range l["contacts"].([]any) {
		if c.(map[string]any)["email"] == email {
			return c.(map[string]any)
		}
	}
	e.t.Fatalf("contact %s absent", email)
	return nil
}
