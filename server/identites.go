package main

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"slices"
	"strings"
	"sync"
	"time"
)

// Connexion par Google ou par Apple (RG-CPT-02) : l'application mobile obtient
// un jeton d'identité (OpenID Connect, signé RS256) et l'envoie au serveur,
// qui en vérifie la signature avec les clés publiques du fournisseur, l'émetteur,
// le destinataire (identifiants clients de la configuration) et l'expiration.
// Sans identifiant client configuré, le fournisseur est désactivé.

type identiteExterne struct {
	Sujet        string
	Email        string
	EmailVerifie bool
	Nom          string
}

type verificateurIdentite struct {
	nom         string
	emetteurs   []string
	adresseCles string
	clients     []string
	client      *http.Client

	mu       sync.Mutex
	cles     map[string]*rsa.PublicKey
	chargeLe time.Time
	maint    func() time.Time
}

func nouveauxVerificateurs(cfg config) map[string]*verificateurIdentite {
	v := map[string]*verificateurIdentite{}
	if len(cfg.GoogleClients) > 0 {
		v["google"] = &verificateurIdentite{nom: "google",
			emetteurs:   []string{"https://accounts.google.com", "accounts.google.com"},
			adresseCles: "https://www.googleapis.com/oauth2/v3/certs", clients: cfg.GoogleClients}
	}
	if len(cfg.AppleClients) > 0 {
		v["apple"] = &verificateurIdentite{nom: "apple",
			emetteurs:   []string{"https://appleid.apple.com"},
			adresseCles: "https://appleid.apple.com/auth/keys", clients: cfg.AppleClients}
	}
	return v
}

var errJetonIdentite = errors.New("jeton d'identité refusé")

func (v *verificateurIdentite) verifier(ctx context.Context, jeton string) (identiteExterne, error) {
	var id identiteExterne
	parties := strings.Split(jeton, ".")
	if len(parties) != 3 {
		return id, errJetonIdentite
	}
	var entete struct{ Alg, Kid string }
	if err := decoderPartie(parties[0], &entete); err != nil || entete.Alg != "RS256" {
		return id, errJetonIdentite
	}
	cle, err := v.cle(ctx, entete.Kid)
	if err != nil {
		return id, err
	}
	signature, err := base64.RawURLEncoding.DecodeString(parties[2])
	if err != nil {
		return id, errJetonIdentite
	}
	h := sha256.Sum256([]byte(parties[0] + "." + parties[1]))
	if rsa.VerifyPKCS1v15(cle, crypto.SHA256, h[:], signature) != nil {
		return id, errJetonIdentite
	}
	var r struct {
		Iss           string          `json:"iss"`
		Aud           json.RawMessage `json:"aud"`
		Exp           int64           `json:"exp"`
		Sub           string          `json:"sub"`
		Email         string          `json:"email"`
		EmailVerified any             `json:"email_verified"`
		Name          string          `json:"name"`
	}
	if err := decoderPartie(parties[1], &r); err != nil {
		return id, errJetonIdentite
	}
	var aud []string
	if json.Unmarshal(r.Aud, &aud) != nil {
		var un string
		if json.Unmarshal(r.Aud, &un) != nil {
			return id, errJetonIdentite
		}
		aud = []string{un}
	}
	accepte := false
	for _, a := range aud {
		accepte = accepte || slices.Contains(v.clients, a)
	}
	maint := time.Now
	if v.maint != nil {
		maint = v.maint
	}
	if !accepte || !slices.Contains(v.emetteurs, r.Iss) || r.Sub == "" || maint().Unix() > r.Exp {
		return id, errJetonIdentite
	}
	// Apple écrit email_verified en texte ("true"), Google en booléen.
	verifie := r.EmailVerified == true || r.EmailVerified == "true"
	return identiteExterne{Sujet: r.Sub, Email: strings.ToLower(r.Email), EmailVerifie: verifie, Nom: r.Name}, nil
}

func decoderPartie(p string, v any) error {
	b, err := base64.RawURLEncoding.DecodeString(p)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}

// cle : clé publique du fournisseur, rechargée au plus une fois par heure, ou
// tout de suite si l'identifiant de clé est inconnu (rotation des clés).
func (v *verificateurIdentite) cle(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	v.mu.Lock()
	defer v.mu.Unlock()
	if c, ok := v.cles[kid]; ok && time.Since(v.chargeLe) < 24*time.Hour {
		return c, nil
	}
	if time.Since(v.chargeLe) > time.Minute || v.cles == nil {
		if err := v.chargerCles(ctx); err != nil {
			return nil, err
		}
	}
	if c, ok := v.cles[kid]; ok {
		return c, nil
	}
	return nil, errJetonIdentite
}

func (v *verificateurIdentite) chargerCles(ctx context.Context) error {
	client := v.client
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, v.adresseCles, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("clés %s : %w", v.nom, err)
	}
	defer resp.Body.Close()
	var jeu struct {
		Keys []struct{ Kty, Kid, N, E string }
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(resp.Body).Decode(&jeu) != nil {
		return fmt.Errorf("clés %s : réponse %d", v.nom, resp.StatusCode)
	}
	cles := map[string]*rsa.PublicKey{}
	for _, k := range jeu.Keys {
		n, err1 := base64.RawURLEncoding.DecodeString(k.N)
		e, err2 := base64.RawURLEncoding.DecodeString(k.E)
		if k.Kty != "RSA" || err1 != nil || err2 != nil {
			continue
		}
		cles[k.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(n), E: int(new(big.Int).SetBytes(e).Int64())}
	}
	v.cles, v.chargeLe = cles, time.Now()
	return nil
}
