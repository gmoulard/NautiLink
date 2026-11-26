package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

func signer(corps []byte, secret string, t time.Time) string {
	ts := strconv.FormatInt(t.Unix(), 10)
	m := hmac.New(sha256.New, []byte(secret))
	m.Write([]byte(ts + "."))
	m.Write(corps)
	return "t=" + ts + ",v1=" + hex.EncodeToString(m.Sum(nil))
}

// TestSignatureStripe : avis de Stripe signé et récent seulement.
func TestSignatureStripe(t *testing.T) {
	corps, maintenant := []byte(`{"type":"checkout.session.completed"}`), time.Now()
	if !signatureValide(signer(corps, "whsec_essai", maintenant), corps, "whsec_essai", maintenant) {
		t.Error("signature valide refusée")
	}
	for nom, entete := range map[string]string{
		"autre secret": signer(corps, "autre", maintenant),
		"trop ancien":  signer(corps, "whsec_essai", maintenant.Add(-10*time.Minute)),
		"vide":         "",
	} {
		if signatureValide(entete, corps, "whsec_essai", maintenant) {
			t.Errorf("%s : signature acceptée", nom)
		}
	}
	if signatureValide(signer(corps, "", maintenant), corps, "", maintenant) {
		t.Error("sans secret : signature acceptée")
	}
}

// TestPaiementConfirme : seule une session payée de 15 € par ce compte
// ouvre l'abonnement (RG-ECO-06, RG-ECO-11).
func TestPaiementConfirme(t *testing.T) {
	ok := sessionStripe{ID: "cs_1", Paiement: "paid", Client: "u1", Montant: 1500, Devise: "eur"}
	if ref, err := paiementConfirme(ok, "u1"); err != nil || ref != "stripe:cs_1" {
		t.Fatalf("session payée : %q %v", ref, err)
	}
	for nom, s := range map[string]sessionStripe{
		"non payée":    {ID: "cs_1", Paiement: "unpaid", Client: "u1", Montant: 1500, Devise: "eur"},
		"autre compte": {ID: "cs_1", Paiement: "paid", Client: "u2", Montant: 1500, Devise: "eur"},
		"autre prix":   {ID: "cs_1", Paiement: "paid", Client: "u1", Montant: 100, Devise: "eur"},
	} {
		if _, err := paiementConfirme(s, "u1"); err == nil {
			t.Errorf("%s : abonnement ouvert", nom)
		}
	}
}

// fauxStripe : sessions Checkout créées et relues.
type fauxStripe struct {
	mu       sync.Mutex
	client   string // client_reference_id de la dernière session
	paiement string
	cle      string
}

func (f *fauxStripe) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if u, _, _ := r.BasicAuth(); u != f.cle {
		w.WriteHeader(401)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	switch {
	case r.Method == "POST" && r.URL.Path == "/v1/checkout/sessions":
		b, _ := io.ReadAll(r.Body)
		v, _ := url.ParseQuery(string(b))
		if v.Get("line_items[0][price_data][unit_amount]") != "1500" || v.Get("mode") != "payment" || !strings.Contains(v.Get("success_url"), "{CHECKOUT_SESSION_ID}") {
			w.WriteHeader(400)
			return
		}
		f.client = v.Get("client_reference_id")
		_, _ = w.Write([]byte(`{"id":"cs_essai","url":"https://checkout.stripe.com/c/pay/cs_essai"}`))
	case r.Method == "GET" && r.URL.Path == "/v1/checkout/sessions/cs_essai":
		_ = json.NewEncoder(w).Encode(map[string]any{"id": "cs_essai", "payment_status": f.paiement, "client_reference_id": f.client,
			"amount_total": 1500, "currency": "eur"})
	default:
		w.WriteHeader(404)
	}
}

// TestAbonnementStripe : avec PostgreSQL : TS-ECO-13 sur le Web avec un faux
// Stripe : sans clé, achat refusé ; paiement non confirmé, rien d'ouvert ;
// paiement confirmé au retour ou par l'avis signé, abonnement reconnu
// partout (RG-ECO-07, GET /v1/quota lu par l'application mobile).
func TestAbonnementStripe(t *testing.T) {
	e := nouvelEssai(t)
	j := e.compte("marin@exemple.org", "Marin")
	web := e.webConnecte("marin@exemple.org")
	if code, r := e.appel("POST", "/abonnement/stripe", j, nil); code != 503 || r["code"] != "achat_non_configure" {
		t.Fatalf("sans clé : %d %v", code, r)
	}
	if page := web.envoyer("GET", "/nautilink/quota", nil).Body.String(); !strings.Contains(page, "pas encore ouvert") || !strings.Contains(page, "Version gratuite") {
		t.Fatalf("page sans clé : %s", page)
	}

	f := &fauxStripe{cle: "sk_test_essai", paiement: "unpaid"}
	srv := httptest.NewServer(f)
	t.Cleanup(srv.Close)
	e.a.stripe = &stripe{cle: "sk_test_essai", secret: "whsec_essai", url: srv.URL, client: srv.Client()}

	rec := web.envoyer("GET", "/nautilink/quota", nil)
	if !strings.Contains(rec.Header().Get("Content-Security-Policy"), "form-action 'self' https://checkout.stripe.com") ||
		!strings.Contains(rec.Body.String(), "Souscrire l&#39;abonnement") && !strings.Contains(rec.Body.String(), "Souscrire l'abonnement") {
		t.Fatalf("page avec Stripe : %s", rec.Body.String())
	}
	rec = web.envoyer("POST", "/nautilink/quota/abonnement", map[string]string{})
	if rec.Code != 303 || rec.Header().Get("Location") != "https://checkout.stripe.com/c/pay/cs_essai" {
		t.Fatalf("vers la page de paiement : %d %q %s", rec.Code, rec.Header().Get("Location"), rec.Body.String())
	}
	if rec := web.envoyer("GET", "/nautilink/quota/abonnement/retour?session=cs_essai", nil); rec.Code != 402 {
		t.Fatalf("paiement non confirmé : %d", rec.Code)
	}
	if _, q := e.appel("GET", "/quota", j, nil); q["abonnement"].(map[string]any)["actif"] != false {
		t.Fatalf("abonnement ouvert sans paiement : %v", q)
	}
	f.mu.Lock()
	f.paiement = "paid"
	f.mu.Unlock()
	if rec := web.envoyer("GET", "/nautilink/quota/abonnement/retour?session=cs_essai", nil); rec.Code != 303 ||
		rec.Header().Get("Location") != "/nautilink/quota?ok=abonne" {
		t.Fatalf("retour payé : %d %s", rec.Code, rec.Body.String())
	}
	_, q := e.appel("GET", "/quota", j, nil)
	if ab := q["abonnement"].(map[string]any); ab["actif"] != true || ab["canal"] != "stripe" {
		t.Fatalf("abonnement Web lu par le téléphone : %v", q)
	}
	if page := web.envoyer("GET", "/nautilink/", nil).Body.String(); !strings.Contains(page, "Version abonné") {
		t.Fatalf("tableau de bord : %s", page)
	}

	// Avis de Stripe pour un autre compte : signature vérifiée.
	autre := e.compte("autre@exemple.org", "Autre")
	avis, _ := json.Marshal(map[string]any{"type": "checkout.session.completed", "data": map[string]any{"object": map[string]any{
		"id": "cs_avis", "payment_status": "paid", "client_reference_id": e.id(autre), "amount_total": 1500, "currency": "eur"}}})
	envoyerAvis := func(signature string) int {
		req := httptest.NewRequest("POST", "/nautilink/api/v1/rappels/stripe", bytes.NewReader(avis))
		req.Header.Set("Stripe-Signature", signature)
		rec := httptest.NewRecorder()
		e.h.ServeHTTP(rec, req)
		return rec.Code
	}
	if code := envoyerAvis(signer(avis, "faux", time.Now())); code != 422 {
		t.Fatalf("avis mal signé : %d", code)
	}
	if code := envoyerAvis(signer(avis, "whsec_essai", time.Now())); code != 204 {
		t.Fatalf("avis : %d", code)
	}
	if _, q := e.appel("GET", "/quota", autre, nil); q["abonnement"].(map[string]any)["canal"] != "stripe" {
		t.Fatalf("abonnement ouvert par l'avis : %v", q)
	}
}
