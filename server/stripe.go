package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// Abonnement par carte bancaire avec Stripe sur le Web (RG-ECO-07,
// RG-ECO-11, TODO-6.7) : page de paiement Stripe Checkout pour l'achat unique
// de 15 € pour 10 ans (RG-ECO-06) ; l'abonnement s'ouvre seulement quand
// Stripe confirme le paiement : au retour de la page de paiement (session
// relue auprès de Stripe) ou par l'avis signé que Stripe envoie au serveur.
// Comme Google Play et l'App Store (achats.go) : sans clé, l'achat est refusé
// avec le code achat_non_configure ; aucune clé dans le dépôt.

const (
	prixCentimes  = 1500 // 15 € (RG-ECO-06)
	toleranceAvis = 5 * time.Minute
)

type stripe struct {
	cle, secret string // NAUTILINK_STRIPE_CLE, NAUTILINK_STRIPE_SECRET_RAPPEL
	url         string
	client      *http.Client
}

func nouveauStripe(cfg config) *stripe {
	return &stripe{cle: cfg.StripeCle, secret: cfg.StripeSecretRappel, url: "https://api.stripe.com",
		client: &http.Client{Timeout: 20 * time.Second}}
}

type sessionStripe struct {
	ID       string `json:"id"`
	URL      string `json:"url"`
	Paiement string `json:"payment_status"`
	Client   string `json:"client_reference_id"`
	Montant  int    `json:"amount_total"`
	Devise   string `json:"currency"`
}

func (s *stripe) appel(ctx context.Context, methode, chemin string, corps url.Values, v any) (int, error) {
	var r io.Reader
	if corps != nil {
		r = strings.NewReader(corps.Encode())
	}
	req, err := http.NewRequestWithContext(ctx, methode, s.url+chemin, r)
	if err != nil {
		return 0, err
	}
	req.SetBasicAuth(s.cle, "")
	if corps != nil {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}
	rep, err := s.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer rep.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(rep.Body, 1<<20))
	if rep.StatusCode/100 == 2 && v != nil {
		if err := json.Unmarshal(b, v); err != nil {
			return rep.StatusCode, err
		}
	}
	return rep.StatusCode, nil
}

// ouvrirPaiement : session Stripe Checkout pour ce compte ; rend l'adresse
// de la page de paiement. retour : adresse de retour, qui reçoit
// ?session=<identifiant> ; annulation : adresse si la personne renonce.
func (s *stripe) ouvrirPaiement(ctx context.Context, utilisateur, email, retour, annulation string) (string, error) {
	if s.cle == "" {
		return "", errAchatNonConfigure()
	}
	sep := "?"
	if strings.Contains(retour, "?") {
		sep = "&"
	}
	v := url.Values{
		"mode":                                   {"payment"},
		"client_reference_id":                    {utilisateur},
		"customer_email":                         {email},
		"success_url":                            {retour + sep + "session={CHECKOUT_SESSION_ID}"},
		"cancel_url":                             {annulation},
		"line_items[0][quantity]":                {"1"},
		"line_items[0][price_data][currency]":    {"eur"},
		"line_items[0][price_data][unit_amount]": {strconv.Itoa(prixCentimes)},
		"line_items[0][price_data][product_data][name]": {"NautiLink — abonnement de 10 ans"},
		"metadata[utilisateur]":                         {utilisateur},
	}
	var ses sessionStripe
	code, err := s.appel(ctx, http.MethodPost, "/v1/checkout/sessions", v, &ses)
	if err != nil {
		return "", err
	}
	if code/100 != 2 || ses.URL == "" {
		log.Printf("Stripe : session refusée (%d)", code)
		return "", &erreurAPI{http.StatusBadGateway, "paiement_indisponible", "Le paiement par carte est momentanément indisponible.", 0}
	}
	return ses.URL, nil
}

// paiementConfirme : session payée de 15 € par ce compte ; rend la
// référence de l'abonnement (RG-ECO-11 : sinon rien n'est ouvert).
func paiementConfirme(ses sessionStripe, utilisateur string) (string, error) {
	if ses.ID == "" || ses.Paiement != "paid" || ses.Client != utilisateur || ses.Montant != prixCentimes || ses.Devise != "eur" {
		return "", errPaiementNonConfirme()
	}
	return "stripe:" + ses.ID, nil
}

// verifierSession : session relue auprès de Stripe au retour de la page de
// paiement.
func (s *stripe) verifierSession(ctx context.Context, id, utilisateur string) (string, error) {
	if s.cle == "" {
		return "", errAchatNonConfigure()
	}
	if id == "" || len(id) > 255 || strings.ContainsAny(id, "/?#") {
		return "", errPaiementNonConfirme()
	}
	var ses sessionStripe
	code, err := s.appel(ctx, http.MethodGet, "/v1/checkout/sessions/"+url.PathEscape(id), nil, &ses)
	if err != nil {
		return "", err
	}
	if code != http.StatusOK {
		return "", errPaiementNonConfirme()
	}
	return paiementConfirme(ses, utilisateur)
}

// signatureValide : en-tête Stripe-Signature (t=<horodatage>,v1=<HMAC-SHA256
// de « t.corps »>), récent de 5 minutes au plus.
func signatureValide(entete string, corps []byte, secret string, maintenant time.Time) bool {
	var t string
	var signatures []string
	for _, p := range strings.Split(entete, ",") {
		k, v, _ := strings.Cut(strings.TrimSpace(p), "=")
		switch k {
		case "t":
			t = v
		case "v1":
			signatures = append(signatures, v)
		}
	}
	sec, err := strconv.ParseInt(t, 10, 64)
	if err != nil || secret == "" {
		return false
	}
	if d := maintenant.Sub(time.Unix(sec, 0)); d > toleranceAvis || d < -toleranceAvis {
		return false
	}
	m := hmac.New(sha256.New, []byte(secret))
	m.Write([]byte(t + "."))
	m.Write(corps)
	attendu := hex.EncodeToString(m.Sum(nil))
	for _, s := range signatures {
		if hmac.Equal([]byte(s), []byte(attendu)) {
			return true
		}
	}
	return false
}

func (a *app) routesStripe(mux *http.ServeMux, v string) {
	mux.HandleFunc("POST "+v+"/abonnement/stripe", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		p, err := a.profil(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		base := a.adressePublique(r)
		adresse, err := a.stripe.ouvrirPaiement(r.Context(), s.utilisateur, p.Email, base+"/quota/abonnement/retour", base+"/quota")
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusCreated, map[string]string{"adressePaiement": adresse})
		return nil
	}))
	// Avis de Stripe (sans session, signature vérifiée) : paiement confirmé
	// d'une session Checkout, même si la personne n'est pas revenue sur la
	// page de retour.
	mux.HandleFunc("POST "+v+"/rappels/stripe", func(w http.ResponseWriter, r *http.Request) {
		if !a.b.prete() {
			ecrireErreurJSON(w, errIndisponible)
			return
		}
		if a.stripe.secret == "" {
			ecrireErreurJSON(w, errAchatNonConfigure())
			return
		}
		corps, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
		if err != nil || !signatureValide(r.Header.Get("Stripe-Signature"), corps, a.stripe.secret, time.Now()) {
			ecrireErreurJSON(w, errInvalide("Signature de l'avis invalide."))
			return
		}
		var avis struct {
			Type string `json:"type"`
			Data struct {
				Object sessionStripe `json:"object"`
			} `json:"data"`
		}
		if err := json.Unmarshal(corps, &avis); err != nil {
			ecrireErreurJSON(w, errInvalide("Avis illisible."))
			return
		}
		ses := avis.Data.Object
		if avis.Type == "checkout.session.completed" || avis.Type == "checkout.session.async_payment_succeeded" {
			if ref, err := paiementConfirme(ses, ses.Client); err == nil && estUUID(ses.Client) {
				if err := a.ouvrirAbonnement(r.Context(), ses.Client, "stripe", ref); err != nil {
					ecrireErreurJSON(w, err)
					return
				}
			}
		}
		w.WriteHeader(http.StatusNoContent)
	})
}
