package main

import (
	"context"
	"crypto"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// Jetons d'accès aux API de Google (Google Play Developer API pour les achats
// intégrés, TODO-5.8 ; Firebase Cloud Messaging pour les notifications push
// Android, RG-AND-08) par un compte de service : fichier JSON téléchargé de la
// console Google Cloud, JWT signé RS256 échangé contre un jeton d'accès
// (OAuth 2.0, « JWT bearer »). Les jetons sont gardés jusqu'à leur expiration.

type compteService struct {
	Email     string `json:"client_email"`
	Cle       string `json:"private_key"`
	Projet    string `json:"project_id"`
	AdresseTk string `json:"token_uri"`

	cle      *rsa.PrivateKey
	mu       sync.Mutex
	jetons   map[string]jetonGoogle
	client   *http.Client
	maintien func() time.Time
}

type jetonGoogle struct {
	valeur string
	expire time.Time
}

// lireCompteService : fichier JSON d'un compte de service Google ; vide :
// fonction désactivée.
func lireCompteService(chemin string) (*compteService, error) {
	if chemin == "" {
		return nil, nil
	}
	b, err := os.ReadFile(chemin)
	if err != nil {
		return nil, err
	}
	var c compteService
	if err := json.Unmarshal(b, &c); err != nil {
		return nil, err
	}
	bloc, _ := pem.Decode([]byte(c.Cle))
	if bloc == nil {
		return nil, errors.New("compte de service : clé privée illisible")
	}
	k, err := x509.ParsePKCS8PrivateKey(bloc.Bytes)
	if err != nil {
		return nil, err
	}
	rk, ok := k.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("compte de service : clé RSA attendue")
	}
	c.cle = rk
	if c.AdresseTk == "" {
		c.AdresseTk = "https://oauth2.googleapis.com/token"
	}
	return &c, nil
}

func b64url(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

// jwtSigne : en-tête et charge encodés puis signés (RS256 ou ES256).
func jwtSigne(entete, charge map[string]any, cle crypto.Signer) (string, error) {
	e, _ := json.Marshal(entete)
	c, _ := json.Marshal(charge)
	corps := b64url(e) + "." + b64url(c)
	h := sha256.Sum256([]byte(corps))
	var sig []byte
	switch k := cle.(type) {
	case *rsa.PrivateKey:
		s, err := rsa.SignPKCS1v15(rand.Reader, k, crypto.SHA256, h[:])
		if err != nil {
			return "", err
		}
		sig = s
	case *ecdsa.PrivateKey:
		// ES256 : r et s sur 32 octets chacun (RFC 7518 §3.4).
		r, s, err := ecdsa.Sign(rand.Reader, k, h[:])
		if err != nil {
			return "", err
		}
		sig = append(octets32(r), octets32(s)...)
	default:
		return "", errors.New("clé de signature non prise en charge")
	}
	return corps + "." + b64url(sig), nil
}

func octets32(n *big.Int) []byte {
	b := n.Bytes()
	out := make([]byte, 32)
	copy(out[32-len(b):], b)
	return out
}

func (c *compteService) maintenant() time.Time {
	if c.maintien != nil {
		return c.maintien()
	}
	return time.Now()
}

// jeton : jeton d'accès pour [portee], gardé jusqu'à 1 minute avant son expiration.
func (c *compteService) jeton(ctx context.Context, portee string) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if j, ok := c.jetons[portee]; ok && c.maintenant().Before(j.expire.Add(-time.Minute)) {
		return j.valeur, nil
	}
	t := c.maintenant()
	assertion, err := jwtSigne(map[string]any{"alg": "RS256", "typ": "JWT"}, map[string]any{
		"iss":   c.Email,
		"scope": portee,
		"aud":   c.AdresseTk,
		"iat":   t.Unix(),
		"exp":   t.Add(time.Hour).Unix(),
	}, c.cle)
	if err != nil {
		return "", err
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {assertion}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.AdresseTk, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	client := c.client
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	rep, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer rep.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(rep.Body, 1<<20))
	if rep.StatusCode != http.StatusOK {
		return "", fmt.Errorf("jeton Google refusé : %d %s", rep.StatusCode, b)
	}
	var r struct {
		Jeton  string `json:"access_token"`
		Expire int    `json:"expires_in"`
	}
	if err := json.Unmarshal(b, &r); err != nil || r.Jeton == "" {
		return "", fmt.Errorf("jeton Google illisible : %s", b)
	}
	if c.jetons == nil {
		c.jetons = map[string]jetonGoogle{}
	}
	c.jetons[portee] = jetonGoogle{r.Jeton, t.Add(time.Duration(r.Expire) * time.Second)}
	return r.Jeton, nil
}

// lireCleP8 : clé privée ES256 au format PKCS #8 (fichier .p8 d'Apple :
// APNs, App Store Server API) ; vide : fonction désactivée.
func lireCleP8(chemin string) (*ecdsa.PrivateKey, error) {
	if chemin == "" {
		return nil, nil
	}
	b, err := os.ReadFile(chemin)
	if err != nil {
		return nil, err
	}
	bloc, _ := pem.Decode(b)
	if bloc == nil {
		return nil, errors.New("clé .p8 illisible")
	}
	k, err := x509.ParsePKCS8PrivateKey(bloc.Bytes)
	if err != nil {
		return nil, err
	}
	ek, ok := k.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("clé .p8 : clé ECDSA attendue")
	}
	return ek, nil
}
