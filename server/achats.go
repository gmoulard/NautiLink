package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Achats intégrés de l'abonnement (RG-ECO-06, RG-ECO-07, RG-ECO-11,
// RG-IOS-07 ; TODO-5.8, TODO-10.6) : achat unique de 10 ans, vérifié auprès
// de Google (Google Play Developer API) ou d'Apple (App Store Server API)
// avant d'ouvrir l'abonnement ; un paiement non confirmé n'ouvre rien.
// Sans identifiants, l'achat est refusé avec le code achat_non_configure.

type achatsIntegres struct {
	produit string

	play     *compteService
	paquet   string
	urlPlay  string
	cleStore *ecdsa.PrivateKey
	cleID    string
	emetteur string
	bundle   string
	urlStore string

	client *http.Client
}

func nouveauxAchats(cfg config) *achatsIntegres {
	a := &achatsIntegres{
		produit:  cfg.Produit,
		paquet:   cfg.GooglePlayPaquet,
		urlPlay:  "https://androidpublisher.googleapis.com",
		cleID:    cfg.AppStoreCleID,
		emetteur: cfg.AppStoreEmetteur,
		bundle:   cfg.AppleBundle,
		urlStore: "https://api.storekit.itunes.apple.com",
		client:   &http.Client{Timeout: 20 * time.Second},
	}
	if cfg.AppStoreSandbox {
		a.urlStore = "https://api.storekit-sandbox.itunes.apple.com"
	}
	var err error
	if a.play, err = lireCompteService(cfg.GooglePlayCompte); err != nil {
		log.Printf("achats Google Play désactivés : %v", err)
	}
	if a.cleStore, err = lireCleP8(cfg.AppStoreCle); err != nil {
		log.Printf("achats App Store désactivés : %v", err)
	}
	return a
}

func errAchatNonConfigure() error {
	return &erreurAPI{http.StatusServiceUnavailable, "achat_non_configure",
		"L'achat de l'abonnement n'est pas encore ouvert sur ce serveur.", 0}
}

func errPaiementNonConfirme() error {
	return &erreurAPI{http.StatusPaymentRequired, "paiement_non_confirme",
		"Paiement non confirmé : l'abonnement n'est pas ouvert.", 0}
}

func (a *achatsIntegres) appel(ctx context.Context, methode, adresse, jeton string, v any) (int, error) {
	req, err := http.NewRequestWithContext(ctx, methode, adresse, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("Authorization", "Bearer "+jeton)
	rep, err := a.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer rep.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(rep.Body, 1<<20))
	if rep.StatusCode/100 == 2 && v != nil && len(b) > 0 {
		if err := json.Unmarshal(b, v); err != nil {
			return rep.StatusCode, err
		}
	}
	return rep.StatusCode, nil
}

// verifierGooglePlay : achat du produit confirmé par Google, puis acquitté
// (sans acquittement, Google rembourse l'achat après 3 jours). Rend la
// référence de la commande.
func (a *achatsIntegres) verifierGooglePlay(ctx context.Context, jetonAchat string) (string, error) {
	if a.play == nil {
		return "", errAchatNonConfigure()
	}
	if jetonAchat == "" || len(jetonAchat) > 4096 {
		return "", errInvalide("Jeton d'achat manquant.")
	}
	jeton, err := a.play.jeton(ctx, "https://www.googleapis.com/auth/androidpublisher")
	if err != nil {
		return "", err
	}
	base := fmt.Sprintf("%s/androidpublisher/v3/applications/%s/purchases/products/%s/tokens/%s",
		a.urlPlay, url.PathEscape(a.paquet), url.PathEscape(a.produit), url.PathEscape(jetonAchat))
	var achat struct {
		EtatAchat     int    `json:"purchaseState"`
		Commande      string `json:"orderId"`
		Acquittement  int    `json:"acknowledgementState"`
		ProduitAchete string `json:"productId"`
	}
	code, err := a.appel(ctx, http.MethodGet, base, jeton, &achat)
	if err != nil {
		return "", err
	}
	// 0 : acheté ; 1 : annulé ; 2 : en attente (paiement différé).
	if code != http.StatusOK || achat.EtatAchat != 0 {
		return "", errPaiementNonConfirme()
	}
	if achat.Acquittement == 0 {
		if c, err := a.appel(ctx, http.MethodPost, base+":acknowledge", jeton, nil); err != nil || c/100 != 2 {
			log.Printf("achat Google Play %s non acquitté : %d %v", achat.Commande, c, err)
		}
	}
	ref := achat.Commande
	if ref == "" {
		ref = jetonAchat
	}
	return "google_play:" + ref, nil
}

// chargeJWS : charge d'un JWS compact, décodée sans vérifier la signature
// (la transaction est relue auprès d'Apple, par HTTPS, avant d'être crue).
func chargeJWS(jws string, v any) error {
	p := strings.Split(jws, ".")
	if len(p) != 3 {
		return errors.New("JWS invalide")
	}
	b, err := base64.RawURLEncoding.DecodeString(p[1])
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}

type transactionApple struct {
	ID          string `json:"transactionId"`
	Originale   string `json:"originalTransactionId"`
	Produit     string `json:"productId"`
	Bundle      string `json:"bundleId"`
	Revocation  int64  `json:"revocationDate"`
	Environment string `json:"environment"`
}

// verifierAppStore : transaction signée remise par StoreKit 2 sur l'iPhone,
// relue auprès de l'App Store Server API ; produit et application vérifiés,
// achat remboursé refusé. Rend la référence de la transaction d'origine.
func (a *achatsIntegres) verifierAppStore(ctx context.Context, transactionSignee string) (string, error) {
	if a.cleStore == nil || a.cleID == "" || a.emetteur == "" {
		return "", errAchatNonConfigure()
	}
	var t transactionApple
	if err := chargeJWS(transactionSignee, &t); err != nil || t.ID == "" {
		return "", errInvalide("Transaction illisible.")
	}
	maintenant := time.Now()
	jeton, err := jwtSigne(map[string]any{"alg": "ES256", "kid": a.cleID, "typ": "JWT"}, map[string]any{
		"iss": a.emetteur,
		"iat": maintenant.Unix(),
		"exp": maintenant.Add(20 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": a.bundle,
	}, a.cleStore)
	if err != nil {
		return "", err
	}
	var r struct {
		Signee string `json:"signedTransactionInfo"`
	}
	code, err := a.appel(ctx, http.MethodGet, a.urlStore+"/inApps/v1/transactions/"+url.PathEscape(t.ID), jeton, &r)
	if err != nil {
		return "", err
	}
	if code != http.StatusOK {
		return "", errPaiementNonConfirme()
	}
	var v transactionApple
	if err := chargeJWS(r.Signee, &v); err != nil {
		return "", errPaiementNonConfirme()
	}
	if v.Produit != a.produit || v.Bundle != a.bundle || v.Revocation != 0 {
		return "", errPaiementNonConfirme()
	}
	ref := v.Originale
	if ref == "" {
		ref = v.ID
	}
	return "app_store:" + ref, nil
}

// ouvrirAbonnement : abonnement de 10 ans ouvert à l'heure de l'achat
// (RG-ECO-06), un seul par compte quel que soit le canal (RG-ECO-07). Un
// abonnement encore actif est gardé ; un achat déjà reconnu pour un autre
// compte est refusé.
func (a *app) ouvrirAbonnement(ctx context.Context, utilisateur, canal, reference string) error {
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var autre string
	err = tx.QueryRow(ctx, "SELECT utilisateur_id FROM abonnements WHERE reference = $1 AND utilisateur_id <> $2",
		reference, utilisateur).Scan(&autre)
	if err == nil {
		return &erreurAPI{http.StatusConflict, "achat_deja_utilise", "Cet achat a déjà ouvert l'abonnement d'un autre compte.", 0}
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	t := a.maintenant()
	if _, err := tx.Exec(ctx, `INSERT INTO abonnements (utilisateur_id, canal, debut, fin, reference)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (utilisateur_id) DO UPDATE SET canal = EXCLUDED.canal, debut = EXCLUDED.debut,
			fin = EXCLUDED.fin, reference = EXCLUDED.reference
		WHERE abonnements.fin <= $3`,
		utilisateur, canal, t, t.AddDate(10, 0, 0), reference); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (a *app) routesAchats(mux *http.ServeMux, v string) {
	achat := func(canal string, verifier func(ctx context.Context, c map[string]string) (string, error)) http.HandlerFunc {
		return a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
			var c map[string]string
			if err := lireJSON(r, &c); err != nil {
				return err
			}
			ref, err := verifier(r.Context(), c)
			if err != nil {
				return err
			}
			if err := a.ouvrirAbonnement(r.Context(), s.utilisateur, canal, ref); err != nil {
				return err
			}
			q, err := a.quota(r.Context(), s.utilisateur)
			if err != nil {
				return err
			}
			ecrireJSON(w, http.StatusOK, q)
			return nil
		})
	}
	mux.HandleFunc("POST "+v+"/abonnement/google-play", achat("google_play", func(ctx context.Context, c map[string]string) (string, error) {
		return a.achats.verifierGooglePlay(ctx, c["jetonAchat"])
	}))
	mux.HandleFunc("POST "+v+"/abonnement/app-store", achat("app_store", func(ctx context.Context, c map[string]string) (string, error) {
		return a.achats.verifierAppStore(ctx, c["transactionSignee"])
	}))
}
