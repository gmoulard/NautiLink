package main

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/argon2"
)

// Mots de passe : argon2id, paramètres minimaux recommandés par l'OWASP
// (19 Mio, 2 passes), choisis pour le Raspberry Pi (conteneur limité à
// 128 Mo) : au plus deux calculs à la fois.
const (
	argonMemoire  = 19 * 1024
	argonPasses   = 2
	argonFils     = 1
	argonLongueur = 32
)

var calculsMotDePasse = make(chan struct{}, 2)

func hacherMotDePasse(mdp string) string {
	sel := octetsAleatoires(16)
	calculsMotDePasse <- struct{}{}
	h := argon2.IDKey([]byte(mdp), sel, argonPasses, argonMemoire, argonFils, argonLongueur)
	<-calculsMotDePasse
	return fmt.Sprintf("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s", argonMemoire, argonPasses, argonFils,
		base64.RawStdEncoding.EncodeToString(sel), base64.RawStdEncoding.EncodeToString(h))
}

// verifierMotDePasse : vrai si mdp correspond au hachage. Un hachage vide
// (compte Google ou Apple seulement) est comparé à un hachage factice, pour
// que la durée de la réponse ne dise pas si le compte existe.
func verifierMotDePasse(hache, mdp string) bool {
	if hache == "" {
		hache = hachageFactice
	}
	var m, t uint32
	var p uint8
	parties := strings.Split(hache, "$")
	if len(parties) != 6 || parties[1] != "argon2id" {
		return false
	}
	if _, err := fmt.Sscanf(parties[3], "m=%d,t=%d,p=%d", &m, &t, &p); err != nil {
		return false
	}
	sel, err1 := base64.RawStdEncoding.DecodeString(parties[4])
	attendu, err2 := base64.RawStdEncoding.DecodeString(parties[5])
	if err1 != nil || err2 != nil {
		return false
	}
	calculsMotDePasse <- struct{}{}
	h := argon2.IDKey([]byte(mdp), sel, t, m, p, uint32(len(attendu)))
	<-calculsMotDePasse
	return subtle.ConstantTimeCompare(h, attendu) == 1 && parties[2] == "v=19" && hache != hachageFactice
}

var hachageFactice = hacherMotDePasse("factice")

func octetsAleatoires(n int) []byte {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return b
}

// nouveauJeton : jeton aléatoire de 256 bits, lisible dans une adresse.
func nouveauJeton() string {
	return base64.RawURLEncoding.EncodeToString(octetsAleatoires(32))
}

// empreinte : seule l'empreinte SHA-256 d'un jeton est gardée en base.
func empreinte(jeton string) []byte {
	h := sha256.Sum256([]byte(jeton))
	return h[:]
}

// limiteur : protection contre les essais répétés (connexion, inscription,
// renvoi d'e-mails), en mémoire : au plus max essais par clé sur la fenêtre.
type limiteur struct {
	mu      sync.Mutex
	max     int
	fenetre time.Duration
	essais  map[string][]time.Time
	maint   func() time.Time
}

func nouveauLimiteur(max int, fenetre time.Duration) *limiteur {
	return &limiteur{max: max, fenetre: fenetre, essais: map[string][]time.Time{}, maint: time.Now}
}

func (l *limiteur) recents(cle string) []time.Time {
	limite := l.maint().Add(-l.fenetre)
	garde := l.essais[cle][:0]
	for _, t := range l.essais[cle] {
		if t.After(limite) {
			garde = append(garde, t)
		}
	}
	if len(garde) == 0 {
		delete(l.essais, cle)
		return nil
	}
	l.essais[cle] = garde
	return garde
}

// bloque : durée d'attente restante si la clé a atteint la limite, 0 sinon.
func (l *limiteur) bloque(cle string) time.Duration {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.recents(cle)
	if len(r) < l.max {
		return 0
	}
	return r[len(r)-l.max].Add(l.fenetre).Sub(l.maint())
}

func (l *limiteur) noter(cle string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.recents(cle)
	l.essais[cle] = append(l.essais[cle], l.maint())
	if len(l.essais) > 100000 { // garde-fou mémoire
		l.essais = map[string][]time.Time{}
	}
}

func (l *limiteur) oublier(cle string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	delete(l.essais, cle)
}

// adresseClient : adresse IP du client. Derrière Traefik (pi-appliance), la
// dernière adresse de X-Forwarded-For est celle que Traefik a vue ; le
// conteneur n'est pas joignable autrement.
func adresseClient(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parties := strings.Split(xff, ",")
		if ip := strings.TrimSpace(parties[len(parties)-1]); net.ParseIP(ip) != nil {
			return ip
		}
	}
	hote, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return hote
}

var errOrigine = errors.New("requête venue d'un autre site")

// memeOrigine : refuse un envoi de formulaire ou un appel par cookie venu
// d'un autre site (en plus du cookie SameSite=Lax).
func memeOrigine(r *http.Request) error {
	switch r.Header.Get("Sec-Fetch-Site") {
	case "", "same-origin", "none":
	default:
		return errOrigine
	}
	if o := r.Header.Get("Origin"); o != "" && o != "null" {
		hote := o
		if i := strings.Index(o, "://"); i >= 0 {
			hote = o[i+3:]
		}
		if !strings.EqualFold(hote, r.Host) && !strings.EqualFold(hote, r.Header.Get("X-Forwarded-Host")) {
			return errOrigine
		}
	}
	return nil
}
