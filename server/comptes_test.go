package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestMotDePasse(t *testing.T) {
	h := hacherMotDePasse("bonjour marin")
	if !verifierMotDePasse(h, "bonjour marin") || verifierMotDePasse(h, "bonjour marine") {
		t.Fatal("vérification du mot de passe")
	}
	if verifierMotDePasse("", "factice") || verifierMotDePasse("n'importe quoi", "x") {
		t.Fatal("hachage vide ou illisible accepté")
	}
	if h == hacherMotDePasse("bonjour marin") {
		t.Fatal("même hachage sans sel")
	}
}

func TestLimiteur(t *testing.T) {
	maint := time.Date(2026, 11, 25, 10, 0, 0, 0, time.UTC)
	l := nouveauLimiteur(3, 15*time.Minute)
	l.maint = func() time.Time { return maint }
	for i := 0; i < 3; i++ {
		if l.bloque("a") > 0 {
			t.Fatalf("bloqué après %d essais", i)
		}
		l.noter("a")
	}
	if l.bloque("a") <= 0 || l.bloque("b") > 0 {
		t.Fatal("limite non appliquée, ou appliquée à une autre clé")
	}
	maint = maint.Add(16 * time.Minute)
	if l.bloque("a") > 0 {
		t.Fatal("toujours bloqué après la fenêtre")
	}
}

func TestNormaliser(t *testing.T) {
	for entree, attendu := range map[string]string{"06 12 34 56 78": "+33612345678", "+44 20 7946 0958": "+442079460958", "0033612345678": "+33612345678"} {
		if got, err := normaliserTelephone(entree); err != nil || got != attendu {
			t.Errorf("téléphone %q → %q %v", entree, got, err)
		}
	}
	if _, err := normaliserTelephone("12"); err == nil {
		t.Error("numéro trop court accepté")
	}
	if got, err := normaliserEmail(" Marin@Exemple.ORG "); err != nil || got != "marin@exemple.org" {
		t.Errorf("e-mail : %q %v", got, err)
	}
	for _, e := range []string{"pas un e-mail", "a@b\r\nBcc: c@d", "Nom <a@b.c>"} {
		if _, err := normaliserEmail(e); err == nil {
			t.Errorf("e-mail %q accepté", e)
		}
	}
}

func TestMemeOrigine(t *testing.T) {
	r := httptest.NewRequest("POST", "https://vdl.moulard.org/nautilink/connexion", nil)
	if memeOrigine(r) != nil {
		t.Error("requête sans Origin refusée")
	}
	r.Header.Set("Origin", "https://vdl.moulard.org")
	if memeOrigine(r) != nil {
		t.Error("même origine refusée")
	}
	r.Header.Set("Origin", "https://pirate.example")
	if memeOrigine(r) == nil {
		t.Error("autre origine acceptée")
	}
	r.Header.Del("Origin")
	r.Header.Set("Sec-Fetch-Site", "cross-site")
	if memeOrigine(r) == nil {
		t.Error("Sec-Fetch-Site cross-site accepté")
	}
}

func TestInscriptionVerificationConnexion(t *testing.T) {
	e := nouvelEssai(t)
	corps := map[string]string{"email": "Marin@Exemple.org", "motDePasse": "motdepasse", "nom": "Marin"}
	if code, r := e.appel("POST", "/comptes", "", corps); code != 422 || r["code"] != "avertissement_a_accepter" {
		t.Fatalf("sans avertissement : %d %v", code, r)
	}
	corps["avertissementVersion"] = versionAvertissement
	corps["motDePasse"] = "court"
	if code, _ := e.appel("POST", "/comptes", "", corps); code != 422 {
		t.Fatalf("mot de passe court : %d", code)
	}
	corps["motDePasse"] = "motdepasse"
	code, s := e.appel("POST", "/comptes", "", corps)
	if code != 201 || s["jetonAcces"] == "" || s["jetonRenouvellement"] == "" {
		t.Fatalf("création : %d %v", code, s)
	}
	if code, r := e.appel("POST", "/comptes", "", corps); code != 409 || r["code"] != "email_deja_utilise" {
		t.Fatalf("doublon : %d %v", code, r)
	}
	jeton := s["jetonAcces"].(string)
	_, p := e.appel("GET", "/compte", jeton, nil)
	if p["email"] != "marin@exemple.org" || p["emailVerifie"] != false || p["avertissementVersionAcceptee"] != versionAvertissement {
		t.Fatalf("profil : %v", p)
	}
	var hache string
	_ = e.a.b.pool.QueryRow(t.Context(), "SELECT mot_de_passe FROM utilisateurs").Scan(&hache)
	if !strings.HasPrefix(hache, "$argon2id$") || strings.Contains(hache, "motdepasse") {
		t.Fatalf("mot de passe mal gardé : %q", hache)
	}

	texte := e.courrier.dernier(t, "marin@exemple.org")
	if !strings.Contains(texte, "https://exemple.org/nautilink/verification?jeton=") {
		t.Fatalf("lien de vérification absent : %q", texte)
	}
	jv := jetonDuTexte(t, texte)
	if code, _ := e.appel("POST", "/compte/verification", "", map[string]string{"jeton": jv}); code != 204 {
		t.Fatalf("vérification : %d", code)
	}
	if code, _ := e.appel("POST", "/compte/verification", "", map[string]string{"jeton": jv}); code != 404 {
		t.Fatalf("lien réutilisé : %d", code)
	}
	if _, p := e.appel("GET", "/compte", jeton, nil); p["emailVerifie"] != true {
		t.Fatal("adresse non vérifiée")
	}
	n := e.courrier.nombre()
	if code, _ := e.appel("POST", "/compte/verification/envoi", jeton, nil); code != 204 || e.courrier.nombre() != n {
		t.Fatal("adresse déjà vérifiée : aucun e-mail attendu")
	}

	// Connexion.
	if code, r := e.appel("POST", "/sessions", "", map[string]string{"email": "marin@exemple.org", "motDePasse": "faux"}); code != 401 || r["code"] != "non_authentifie" {
		t.Fatalf("mauvais mot de passe : %d %v", code, r)
	}
	if code, _ := e.appel("POST", "/sessions", "", map[string]string{"email": "inconnu@exemple.org", "motDePasse": "motdepasse"}); code != 401 {
		t.Fatalf("compte inconnu : %d", code)
	}
	code, s2 := e.appel("POST", "/sessions", "", map[string]string{"email": "MARIN@exemple.org", "motDePasse": "motdepasse"})
	if code != 200 || s2["jetonAcces"] == jeton {
		t.Fatalf("connexion : %d %v", code, s2)
	}
}

func TestEssaisRepetes(t *testing.T) {
	e := nouvelEssai(t)
	e.compte("marin@exemple.org", "Marin")
	for i := 0; i < 5; i++ {
		e.appel("POST", "/sessions", "", map[string]string{"email": "marin@exemple.org", "motDePasse": "faux"})
	}
	code, r := e.appel("POST", "/sessions", "", map[string]string{"email": "marin@exemple.org", "motDePasse": "motdepasse"})
	if code != 429 || r["code"] != "trop_d_essais" {
		t.Fatalf("après 5 essais : %d %v", code, r)
	}
}

func TestSessions(t *testing.T) {
	e := nouvelEssai(t)
	code, s := e.appel("POST", "/comptes", "", map[string]string{"email": "a@exemple.org", "motDePasse": "motdepasse",
		"nom": "A", "avertissementVersion": versionAvertissement})
	if code != 201 {
		t.Fatal(code)
	}
	acces, renouv := s["jetonAcces"].(string), s["jetonRenouvellement"].(string)
	if code, _ := e.appel("GET", "/compte", "", nil); code != 401 {
		t.Fatalf("sans session : %d", code)
	}
	if code, _ := e.appel("GET", "/compte", "faux", nil); code != 401 {
		t.Fatalf("jeton faux : %d", code)
	}
	// Renouvellement : nouveaux jetons, les anciens ne servent plus.
	code, s2 := e.appel("POST", "/sessions/renouvellement", "", map[string]string{"jetonRenouvellement": renouv})
	if code != 200 {
		t.Fatalf("renouvellement : %d", code)
	}
	if code, _ := e.appel("GET", "/compte", acces, nil); code != 401 {
		t.Fatalf("ancien jeton : %d", code)
	}
	acces = s2["jetonAcces"].(string)
	if code, _ := e.appel("GET", "/compte", acces, nil); code != 200 {
		t.Fatalf("nouveau jeton : %d", code)
	}
	// 89 jours sans usage : la session tient ; 91 jours : elle a expiré (RG-CPT-08).
	e.a.b.pool.Exec(t.Context(), "UPDATE sessions SET derniere_utilisation = now() - interval '89 days'")
	if code, _ := e.appel("GET", "/compte", acces, nil); code != 200 {
		t.Fatalf("89 jours : %d", code)
	}
	e.a.b.pool.Exec(t.Context(), "UPDATE sessions SET derniere_utilisation = now() - interval '91 days'")
	if code, _ := e.appel("GET", "/compte", acces, nil); code != 401 {
		t.Fatalf("91 jours : %d", code)
	}
	if code, _ := e.appel("POST", "/sessions/renouvellement", "", map[string]string{"jetonRenouvellement": s2["jetonRenouvellement"].(string)}); code != 401 {
		t.Fatalf("renouvellement d'une session expirée : %d", code)
	}
	// Déconnexion.
	_, s3 := e.appel("POST", "/sessions", "", map[string]string{"email": "a@exemple.org", "motDePasse": "motdepasse"})
	acces = s3["jetonAcces"].(string)
	if code, _ := e.appel("DELETE", "/sessions/courante", acces, nil); code != 204 {
		t.Fatalf("déconnexion : %d", code)
	}
	if code, _ := e.appel("GET", "/compte", acces, nil); code != 401 {
		t.Fatalf("après déconnexion : %d", code)
	}
}

func TestProfil(t *testing.T) {
	e := nouvelEssai(t)
	j := e.compte("a@exemple.org", "Anne")
	_, p := e.appel("GET", "/compte", j, nil)
	if p["recevoirSms"] != false || p["telephone"] != nil || p["emailsDebut"] != true {
		t.Fatalf("profil initial : %v", p)
	}
	if code, _ := e.appel("PATCH", "/compte", j, map[string]any{"telephone": "12"}); code != 422 {
		t.Fatalf("téléphone invalide : %d", code)
	}
	// Premier numéro : « Recevoir les SMS » s'active (RG-SMS-01) ; les autres champs ne bougent pas.
	_, p = e.appel("PATCH", "/compte", j, map[string]any{"telephone": "06 12 34 56 78"})
	if p["telephone"] != "+33612345678" || p["recevoirSms"] != true || p["nom"] != "Anne" {
		t.Fatalf("après téléphone : %v", p)
	}
	_, p = e.appel("PATCH", "/compte", j, map[string]any{"recevoirSms": false, "emailsDebut": false,
		"push": map[string]bool{"photo": false}, "langue": "en"})
	push := p["push"].(map[string]any)
	if p["recevoirSms"] != false || p["emailsDebut"] != false || push["photo"] != false || push["debut"] != true || p["langue"] != "en" {
		t.Fatalf("désinscriptions : %v", p)
	}
	if code, _ := e.appel("PATCH", "/compte", j, map[string]any{"langue": "de"}); code != 422 {
		t.Fatalf("langue inconnue : %d", code)
	}
}

func TestPagesWebComptes(t *testing.T) {
	e := nouvelEssai(t)
	n := e.navigateur()
	if rec := n.envoyer("GET", "/nautilink/compte", nil); rec.Code != 303 || !strings.Contains(rec.Header().Get("Location"), "/nautilink/connexion?retour=") {
		t.Fatalf("page protégée : %d %q", rec.Code, rec.Header().Get("Location"))
	}
	rec := n.envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Paul", "email": "paul@exemple.org",
		"motdepasse": "motdepasse"})
	if rec.Code != 422 || !strings.Contains(rec.Body.String(), "avertissement") {
		t.Fatalf("inscription sans avertissement : %d", rec.Code)
	}
	rec = n.envoyer("POST", "/nautilink/inscription", map[string]string{"nom": "Paul", "email": "paul@exemple.org",
		"motdepasse": "motdepasse", "avertissement": versionAvertissement})
	if rec.Code != 303 || n.cookies[nomCookie] == nil || !n.cookies[nomCookie].HttpOnly || !n.cookies[nomCookie].Secure {
		t.Fatalf("inscription : %d %v", rec.Code, n.cookies)
	}
	if rec := n.envoyer("GET", "/nautilink/", nil); !strings.Contains(rec.Body.String(), "Bonjour Paul") || !strings.Contains(rec.Body.String(), "Version bêta") {
		t.Fatalf("accueil connecté : %s", rec.Body.String())
	}
	// Formulaire venu d'un autre site : refusé.
	if rec := n.envoyer("POST", "/nautilink/compte", map[string]string{"nom": "Pirate"}, "Origin", "https://pirate.example"); rec.Code != 403 {
		t.Fatalf("autre site : %d", rec.Code)
	}
	rec = n.envoyer("POST", "/nautilink/compte", map[string]string{"nom": "Paul B", "telephone": "+33612345678", "langue": "fr", "emailsDebut": "on"})
	if rec.Code != 303 {
		t.Fatalf("compte : %d %s", rec.Code, rec.Body.String())
	}
	if rec := n.envoyer("GET", "/nautilink/compte", nil); !strings.Contains(rec.Body.String(), "33612345678") {
		t.Fatalf("téléphone non enregistré : %s", rec.Body.String())
	}
	// Lien de vérification ouvert dans le navigateur.
	jv := jetonDuTexte(t, e.courrier.dernier(t, "paul@exemple.org"))
	if rec := n.envoyer("GET", "/nautilink/verification?jeton="+jv, nil); rec.Code != 303 {
		t.Fatalf("vérification : %d", rec.Code)
	}
	if rec := n.envoyer("POST", "/nautilink/deconnexion", map[string]string{}); rec.Code != 303 || n.cookies[nomCookie] != nil {
		t.Fatalf("déconnexion : %d", rec.Code)
	}
	if rec := n.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "paul@exemple.org", "motdepasse": "faux"}); rec.Code != 401 {
		t.Fatalf("connexion refusée : %d", rec.Code)
	}
	rec = n.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "paul@exemple.org", "motdepasse": "motdepasse",
		"retour": "/nautilink/compte"})
	if rec.Code != 303 || rec.Header().Get("Location") != "/nautilink/compte" {
		t.Fatalf("connexion : %d %q", rec.Code, rec.Header().Get("Location"))
	}
	rec = n.envoyer("POST", "/nautilink/connexion", map[string]string{"email": "paul@exemple.org", "motdepasse": "motdepasse",
		"retour": "//pirate.example/"})
	if rec.Header().Get("Location") != "/nautilink/" {
		t.Fatalf("retour vers un autre site : %q", rec.Header().Get("Location"))
	}
}

// ------------------------------------------------------------------ Google et Apple

type fournisseurEssai struct {
	cle *rsa.PrivateKey
	srv *httptest.Server
}

func nouveauFournisseurEssai(t *testing.T) *fournisseurEssai {
	cle, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	f := &fournisseurEssai{cle: cle}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"keys": []map[string]string{{"kty": "RSA", "kid": "k1",
			"n": base64.RawURLEncoding.EncodeToString(cle.N.Bytes()),
			"e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(cle.E)).Bytes())}}})
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fournisseurEssai) jeton(revendications map[string]any) string {
	entete, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": "k1"})
	corps, _ := json.Marshal(revendications)
	signe := base64.RawURLEncoding.EncodeToString(entete) + "." + base64.RawURLEncoding.EncodeToString(corps)
	h := sha256.Sum256([]byte(signe))
	sig, _ := rsa.SignPKCS1v15(rand.Reader, f.cle, crypto.SHA256, h[:])
	return signe + "." + base64.RawURLEncoding.EncodeToString(sig)
}

func TestConnexionGoogle(t *testing.T) {
	e := nouvelEssai(t)
	corps := map[string]string{"fournisseur": "google", "jetonIdentite": "x"}
	if code, r := e.appel("POST", "/sessions", "", corps); code != 501 || r["code"] != "fournisseur_indisponible" {
		t.Fatalf("Google non configuré : %d %v", code, r)
	}
	f := nouveauFournisseurEssai(t)
	e.a.verificateurs["google"] = &verificateurIdentite{nom: "google", emetteurs: []string{"https://accounts.google.com"},
		adresseCles: f.srv.URL, clients: []string{"client-nautilink"}}
	rev := map[string]any{"iss": "https://accounts.google.com", "aud": "client-nautilink", "sub": "g-123",
		"email": "Voile@Exemple.org", "email_verified": true, "name": "Voile", "exp": time.Now().Add(time.Hour).Unix()}
	corps["jetonIdentite"] = f.jeton(rev)
	if code, r := e.appel("POST", "/sessions", "", corps); code != 428 || r["code"] != "avertissement_a_accepter" {
		t.Fatalf("premier compte sans avertissement : %d %v", code, r)
	}
	corps["avertissementVersion"] = versionAvertissement
	code, s := e.appel("POST", "/sessions", "", corps)
	if code != 200 {
		t.Fatalf("première connexion Google : %d %v", code, s)
	}
	_, p := e.appel("GET", "/compte", s["jetonAcces"].(string), nil)
	if p["email"] != "voile@exemple.org" || p["emailVerifie"] != true || p["nom"] != "Voile" {
		t.Fatalf("compte Google : %v", p)
	}
	delete(corps, "avertissementVersion")
	if code, s2 := e.appel("POST", "/sessions", "", corps); code != 200 || e.id(s2["jetonAcces"].(string)) != p["id"] {
		t.Fatalf("seconde connexion Google : %d", code)
	}
	// Mauvais destinataire, jeton expiré, signature fausse : refusés.
	for _, modif := range []func(map[string]any){
		func(m map[string]any) { m["aud"] = "autre" },
		func(m map[string]any) { m["exp"] = time.Now().Add(-time.Hour).Unix() },
		func(m map[string]any) { m["iss"] = "https://pirate.example" },
	} {
		r := map[string]any{}
		for k, v := range rev {
			r[k] = v
		}
		modif(r)
		corps["jetonIdentite"] = f.jeton(r)
		if code, _ := e.appel("POST", "/sessions", "", corps); code != 401 {
			t.Fatalf("jeton refusable accepté : %d (%v)", code, r)
		}
	}
	corps["jetonIdentite"] = f.jeton(rev)[:len(f.jeton(rev))-4] + "AAAA"
	if code, _ := e.appel("POST", "/sessions", "", corps); code != 401 {
		t.Fatalf("signature fausse : %d", code)
	}
	// Adresse d'un compte NautiLink existant : refus tant que Q-51 n'est pas tranchée.
	e.compte("pris@exemple.org", "Pris")
	rev["sub"], rev["email"] = "g-456", "pris@exemple.org"
	corps["jetonIdentite"], corps["avertissementVersion"] = f.jeton(rev), versionAvertissement
	if code, r := e.appel("POST", "/sessions", "", corps); code != 409 || r["code"] != "email_deja_utilise" {
		t.Fatalf("adresse déjà prise : %d %v", code, r)
	}
}
