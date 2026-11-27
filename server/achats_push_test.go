package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// Faux services de Google (jetons OAuth, Google Play, FCM) et d'Apple
// (App Store Server API, APNs).
type fauxServices struct {
	mu       sync.Mutex
	requetes []string
	corps    map[string]string
	etatPlay int    // purchaseState rendu par Google Play
	produit  string // productId rendu par l'App Store
	perime   string // jeton push refusé (application désinstallée)
}

func (f *fauxServices) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	b, _ := io.ReadAll(r.Body)
	f.mu.Lock()
	f.requetes = append(f.requetes, r.Method+" "+r.URL.Path)
	f.corps[r.Method+" "+r.URL.Path] = string(b)
	f.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	switch {
	case r.URL.Path == "/token":
		_, _ = w.Write([]byte(`{"access_token":"acces-essai","expires_in":3600}`))
	case strings.HasSuffix(r.URL.Path, ":acknowledge"):
		w.WriteHeader(204)
	case strings.Contains(r.URL.Path, "/purchases/products/"):
		_, _ = w.Write([]byte(`{"purchaseState":` + string(rune('0'+f.etatPlay)) + `,"orderId":"GPA.1234","acknowledgementState":0}`))
	case strings.HasPrefix(r.URL.Path, "/inApps/v1/transactions/"):
		charge, _ := json.Marshal(map[string]any{"transactionId": "t1", "originalTransactionId": "o1",
			"productId": f.produit, "bundleId": "fr.nautilink.nautilink"})
		_, _ = w.Write([]byte(`{"signedTransactionInfo":"e30.` + base64.RawURLEncoding.EncodeToString(charge) + `.c2ln"}`))
	case strings.Contains(r.URL.Path, "/messages:send"):
		if strings.Contains(string(b), f.perime) && f.perime != "" {
			w.WriteHeader(404)
			return
		}
		_, _ = w.Write([]byte(`{"name":"m1"}`))
	case strings.HasPrefix(r.URL.Path, "/3/device/"):
		if strings.HasSuffix(r.URL.Path, f.perime) && f.perime != "" {
			w.WriteHeader(410)
			return
		}
		w.WriteHeader(200)
	default:
		w.WriteHeader(404)
	}
}

func (f *fauxServices) nombre(prefixe string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, r := range f.requetes {
		if strings.HasPrefix(r, prefixe) {
			n++
		}
	}
	return n
}

// brancherServices : achats et push de l'essai dirigés vers les faux services.
func brancherServices(t *testing.T, e *essai) *fauxServices {
	f := &fauxServices{corps: map[string]string{}, produit: "nautilink_abonnement_10_ans"}
	srv := httptest.NewServer(f)
	t.Cleanup(srv.Close)
	dir := t.TempDir()
	rk, _ := rsa.GenerateKey(rand.Reader, 2048)
	der, _ := x509.MarshalPKCS8PrivateKey(rk)
	cs, _ := json.Marshal(map[string]string{"client_email": "nautilink@essai.iam.gserviceaccount.com",
		"private_key": string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})),
		"project_id":  "nautilink-essai", "token_uri": srv.URL + "/token"})
	chemin := filepath.Join(dir, "compte.json")
	if err := os.WriteFile(chemin, cs, 0o600); err != nil {
		t.Fatal(err)
	}
	ek, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	der, _ = x509.MarshalPKCS8PrivateKey(ek)
	p8 := filepath.Join(dir, "cle.p8")
	if err := os.WriteFile(p8, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0o600); err != nil {
		t.Fatal(err)
	}
	cfg := config{Produit: "nautilink_abonnement_10_ans", GooglePlayCompte: chemin, GooglePlayPaquet: "fr.nautilink.nautilink",
		AppStoreCle: p8, AppStoreCleID: "CLE1", AppStoreEmetteur: "emetteur", AppleBundle: "fr.nautilink.nautilink",
		FCMCompte: chemin, APNsCle: p8, APNsCleID: "CLE2", APNsEquipe: "EQUIPE"}
	e.a.achats = nouveauxAchats(cfg)
	e.a.achats.urlPlay, e.a.achats.urlStore, e.a.achats.client = srv.URL, srv.URL, srv.Client()
	e.a.push = nouvelEnvoiPush(cfg)
	e.a.push.urlFCM, e.a.push.urlAPNs, e.a.push.client, e.a.push.synchrone = srv.URL, srv.URL, srv.Client(), true
	return f
}

// Achat unique de 10 ans vérifié auprès de Google Play et de l'App Store
// (RG-ECO-06, RG-ECO-07, RG-ECO-11, RG-IOS-07).
func TestAchatsIntegres(t *testing.T) {
	e := nouvelEssai(t)
	j := e.compte("marin@exemple.org", "Marin")
	// Sans identifiants : achat refusé, rien n'est ouvert.
	if code, r := e.appel("POST", "/abonnement/google-play", j, map[string]string{"jetonAchat": "j1"}); code != 503 || r["code"] != "achat_non_configure" {
		t.Fatalf("sans identifiants : %d %v", code, r)
	}
	f := brancherServices(t, e)
	// Paiement en attente : pas d'abonnement (RG-ECO-11).
	f.etatPlay = 2
	if code, _ := e.appel("POST", "/abonnement/google-play", j, map[string]string{"jetonAchat": "j1"}); code != 402 {
		t.Fatalf("paiement en attente : %d", code)
	}
	f.etatPlay = 0
	code, q := e.appel("POST", "/abonnement/google-play", j, map[string]string{"jetonAchat": "j1"})
	ab, _ := q["abonnement"].(map[string]any)
	if code != 200 || ab["actif"] != true || ab["canal"] != "google_play" {
		t.Fatalf("achat Google Play : %d %v", code, q)
	}
	if f.nombre("POST /androidpublisher/") != 1 {
		t.Fatal("achat non acquitté")
	}
	fin, _ := time.Parse(time.RFC3339, ab["fin"].(string))
	if d := time.Until(fin); d < 9*365*24*time.Hour || d > 11*365*24*time.Hour {
		t.Fatalf("abonnement de 10 ans attendu : %v", fin)
	}
	// Le même achat ne sert pas à un autre compte.
	autre := e.compte("autre@exemple.org", "Autre")
	if code, r := e.appel("POST", "/abonnement/google-play", autre, map[string]string{"jetonAchat": "j1"}); code != 409 || r["code"] != "achat_deja_utilise" {
		t.Fatalf("achat réutilisé : %d %v", code, r)
	}
	// App Store : produit vérifié auprès d'Apple.
	charge := base64.RawURLEncoding.EncodeToString([]byte(`{"transactionId":"t1"}`))
	f.produit = "autre_produit"
	if code, _ := e.appel("POST", "/abonnement/app-store", autre, map[string]string{"transactionSignee": "e30." + charge + ".c2ln"}); code != 402 {
		t.Fatalf("produit inattendu : %d", code)
	}
	f.produit = "nautilink_abonnement_10_ans"
	code, q = e.appel("POST", "/abonnement/app-store", autre, map[string]string{"transactionSignee": "e30." + charge + ".c2ln"})
	if ab, _ := q["abonnement"].(map[string]any); code != 200 || ab["canal"] != "app_store" {
		t.Fatalf("achat App Store : %d %v", code, q)
	}
	if code, _ := e.appel("POST", "/abonnement/app-store", autre, map[string]string{"transactionSignee": "pas un jws"}); code != 422 {
		t.Fatalf("transaction illisible : %d", code)
	}
}

// Notifications push des amis (RG-IOS-06, RG-AND-08, D-84) : SOS, début,
// fin, photo, position en retard ; préférence respectée sauf pour le SOS ;
// jeton périmé oublié.
func TestNotificationsPush(t *testing.T) {
	e := nouvelEssai(t)
	f := brancherServices(t, e)
	nav, bateau, tel := e.marin("nav@exemple.org", "Yann", "Mistral")
	s1 := e.compte("s1@exemple.org", "Ami Android")
	s2 := e.compte("s2@exemple.org", "Suiveuse iPhone")
	e.suivre(nav, s1, "s1@exemple.org", "navigateur", "")
	e.suivre(nav, s2, "s2@exemple.org", "navigateur", "")
	e.appel("PUT", "/appareils/"+uuid(t), s1, map[string]any{"plateforme": "android", "jetonPush": "fcm-s1"})
	e.appel("PUT", "/appareils/"+uuid(t), s2, map[string]any{"plateforme": "ios", "jetonPush": "apns-s2"})
	// La suiveuse iPhone ne veut pas des notifications de photo.
	e.appel("PATCH", "/compte", s2, map[string]any{"push": map[string]any{"photo": false}})

	id := uuid(t)
	// Téléphone à UTC+1 : heure locale puis UTC dans les notifications et
	// l'e-mail de début (RG-PRM-07).
	plusUn := time.FixedZone("", 3600)
	soixante := 60
	t0 := time.Now().Add(-2 * time.Hour).Truncate(time.Second).In(plusUn)
	n0 := e.courrier.nombre()
	d := demarrage(bateau, tel, t0, 47.8, -3.9)
	d["debut"].(map[string]any)["id"] = uuid(t)
	if code, r := e.appel("PUT", "/navigations/"+id, nav, d); code != 201 {
		t.Fatalf("démarrage : %d %v", code, r)
	}
	if f.nombre("POST /v1/projects/nautilink-essai/messages:send") != 1 || f.nombre("POST /3/device/apns-s2") != 1 {
		t.Fatalf("notification de début : %v", f.requetes)
	}
	if c := f.corps["POST /3/device/apns-s2"]; !strings.Contains(c, "Yann a démarré une navigation") ||
		!strings.Contains(c, heureEnvoyee(t0, &soixante, false)) {
		t.Fatalf("texte iPhone : %s", c)
	}
	if txt := e.courrier.texte(n0, "s1@exemple.org", "démarré"); !strings.Contains(txt, heureEnvoyee(t0, &soixante, true)) {
		t.Fatalf("heure de l'e-mail de début : %q", txt)
	}
	// Photo : seulement l'ami Android.
	photo := map[string]any{"id": uuid(t), "type": "photo", "heureAcquisition": heure(t0.Add(time.Minute)), "numeroOrdre": 2,
		"origine": "android", "fichier": map[string]any{"typeMedia": "image/jpeg", "tailleOctets": 1000}}
	if code, r := e.appel("PUT", "/navigations/"+id+"/evenements/"+photo["id"].(string), nav, photo); code != 201 {
		t.Fatalf("photo : %d %v", code, r)
	}
	if f.nombre("POST /v1/projects/") != 2 || f.nombre("POST /3/device/") != 1 {
		t.Fatalf("notification de photo : %v", f.requetes)
	}
	// Position en retard : aucune position reçue depuis 1 h 05, fréquence 30 minutes ; une seule fois.
	horloge(e, time.Now().Add(65*time.Minute))
	if err := e.a.positionsEnRetard(t.Context()); err != nil {
		t.Fatal(err)
	}
	if err := e.a.positionsEnRetard(t.Context()); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(f.corps["POST /3/device/apns-s2"], "Position en retard") || f.nombre("POST /3/device/") != 2 {
		t.Fatalf("position en retard : %v", f.requetes)
	}
	e.a.maintenant = time.Now
	// SOS : toujours, jeton iPhone périmé oublié.
	f.perime = "apns-s2"
	al := map[string]any{"id": uuid(t), "bateauId": bateau, "navigationId": id, "appareilId": tel,
		"heureDeclenchement": heure(time.Now().In(plusUn)), "naturePosition": "aucune", "problemeRencontre": "Voie d'eau"}
	if code, r := e.appel("PUT", "/alertes-sos/"+al["id"].(string), nav, al); code != 201 {
		t.Fatalf("SOS : %d %v", code, r)
	}
	if c := f.corps["POST /v1/projects/nautilink-essai/messages:send"]; !strings.Contains(c, "SOS — Mistral") || !strings.Contains(c, " UTC).") {
		t.Fatalf("notification SOS : %s", f.corps["POST /v1/projects/nautilink-essai/messages:send"])
	}
	if e.compter("SELECT count(*) FROM appareils WHERE jeton_push = 'apns-s2'") != 0 {
		t.Fatal("jeton périmé gardé")
	}
	// Fin de navigation.
	avant := f.nombre("POST /v1/projects/")
	fin := map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(time.Now()), "numeroOrdre": 3, "origine": "android"}
	if code, r := e.appel("PUT", "/navigations/"+id+"/fin", nav, fin); code != 200 {
		t.Fatalf("fin : %d %v", code, r)
	}
	if f.nombre("POST /v1/projects/") != avant+1 {
		t.Fatal("notification de fin absente")
	}
}
