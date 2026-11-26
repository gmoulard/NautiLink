package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// app : état partagé par l'API (/api/v1/…) et la plateforme Web.
type app struct {
	cfg           config
	b             *base
	envoyer       func(a, sujet, texte string) error
	mailSynchrone bool // tests : e-mails envoyés avant la réponse

	limConnexionEmail *limiteur
	limConnexionIP    *limiteur
	limInscription    *limiteur
	limEnvoi          *limiteur

	verificateurs map[string]*verificateurIdentite

	// maintenant : horloge du serveur (quota, clôture automatique, corbeille) ;
	// remplacée dans les essais.
	maintenant func() time.Time

	// Achats intégrés et notifications push (achats.go, push.go) : services
	// externes, adresses remplacées dans les essais.
	achats *achatsIntegres
	push   *envoiPush
}

func nouvelleApp(cfg config, b *base) *app {
	a := &app{
		cfg: cfg, b: b,
		// Protection contre les essais répétés : 5 mots de passe faux par
		// compte ou 20 par adresse IP en 15 minutes ; 10 inscriptions par
		// adresse IP par heure ; 5 e-mails de vérification par compte par heure.
		limConnexionEmail: nouveauLimiteur(5, 15*time.Minute),
		limConnexionIP:    nouveauLimiteur(20, 15*time.Minute),
		limInscription:    nouveauLimiteur(10, time.Hour),
		limEnvoi:          nouveauLimiteur(5, time.Hour),
		verificateurs:     nouveauxVerificateurs(cfg),
		maintenant:        time.Now,
	}
	a.envoyer = func(dest, sujet, texte string) error { return envoyerMail(cfg, dest, sujet, texte) }
	a.achats = nouveauxAchats(cfg)
	a.push = nouvelEnvoiPush(cfg)
	return a
}

// courriel : envoie un e-mail sans faire attendre la réponse ; un échec est
// inscrit dans les journaux techniques.
func (a *app) courriel(dest, sujet, texte string) {
	envoi := func() {
		if err := a.envoyer(dest, sujet, texte); err != nil {
			log.Printf("e-mail « %s » non envoyé : %v", sujet, err)
		}
	}
	if a.mailSynchrone {
		envoi()
	} else {
		go envoi()
	}
}

// adressePublique : base des liens envoyés par e-mail (chemin compris).
func (a *app) adressePublique(r *http.Request) string {
	if a.cfg.AdressePublique != "" {
		return a.cfg.AdressePublique
	}
	schema := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		schema = "https"
	}
	return schema + "://" + r.Host + a.cfg.Chemin
}

// ------------------------------------------------------------------ erreurs

// erreurAPI : erreur rendue au client, avec un code stable (schéma Erreur
// de docs/api/openapi.yaml).
type erreurAPI struct {
	statut  int
	code    string
	message string
	attente time.Duration
}

func (e *erreurAPI) Error() string { return e.message }

func errInvalide(msg string) error {
	return &erreurAPI{http.StatusUnprocessableEntity, "invalide", msg, 0}
}
func errIntrouvable() error {
	return &erreurAPI{http.StatusNotFound, "introuvable", "Introuvable.", 0}
}
func errInterdit(code, msg string) error { return &erreurAPI{http.StatusForbidden, code, msg, 0} }
func errNonAuthentifie() error {
	return &erreurAPI{http.StatusUnauthorized, "non_authentifie", "Connectez-vous pour continuer.", 0}
}
func errTropDEssais(attente time.Duration) error {
	return &erreurAPI{http.StatusTooManyRequests, "trop_d_essais",
		fmt.Sprintf("Trop d'essais. Réessayez dans %d minutes.", int(attente.Minutes())+1), attente}
}

var errIndisponible = &erreurAPI{http.StatusServiceUnavailable, "service_indisponible",
	"Le service est momentanément indisponible. Réessayez dans quelques minutes.", 0}

// enErreurAPI : toute autre erreur devient une erreur interne, inscrite
// dans les journaux techniques sans être montrée.
func enErreurAPI(err error) *erreurAPI {
	var e *erreurAPI
	if errors.As(err, &e) {
		return e
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return errIntrouvable().(*erreurAPI)
	}
	log.Printf("erreur interne : %v", err)
	return &erreurAPI{http.StatusInternalServerError, "erreur_interne", "Erreur interne. Réessayez plus tard.", 0}
}

// ------------------------------------------------------------------ JSON

func ecrireJSON(w http.ResponseWriter, statut int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(statut)
	if v != nil {
		_ = json.NewEncoder(w).Encode(v)
	}
}

func ecrireErreurJSON(w http.ResponseWriter, err error) {
	e := enErreurAPI(err)
	if e.attente > 0 {
		w.Header().Set("Retry-After", strconv.Itoa(int(e.attente.Seconds())+1))
	}
	corps := map[string]string{"code": e.code, "message": e.message}
	var q *erreurQuota
	if errors.As(err, &q) {
		corps["disponibleLe"] = q.disponibleLe.UTC().Format(time.RFC3339)
	}
	ecrireJSON(w, e.statut, corps)
}

func lireJSON(r *http.Request, v any) error {
	dec := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 1<<20))
	if err := dec.Decode(v); err != nil {
		return errInvalide("Corps de la requête illisible.")
	}
	return nil
}

// champs : corps d'une modification partielle (PATCH) ; seuls les champs
// présents sont modifiés, la dernière modification reçue l'emporte, champ
// par champ (RG-COM-04).
type champs map[string]json.RawMessage

func (c champs) a(nom string) bool { _, ok := c[nom]; return ok }

func (c champs) lire(nom string, v any) error {
	if err := json.Unmarshal(c[nom], v); err != nil {
		return errInvalide("Champ « " + nom + " » invalide.")
	}
	return nil
}

// ------------------------------------------------------------------ sessions

// session : session ouverte, avec son utilisateur.
type session struct {
	id          string
	utilisateur string
	support     string // "mobile" ou "web"
	parCookie   bool
}

const (
	nomCookie      = "nautilink_session"
	dureeSansUsage = 90 * 24 * time.Hour // RG-CPT-08
)

// jetonDe : jeton porteur (applications mobiles) ou cookie (plateforme Web).
func jetonDe(r *http.Request) (string, bool) {
	if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
		return strings.TrimSpace(h[7:]), false
	}
	if c, err := r.Cookie(nomCookie); err == nil && c.Value != "" {
		return c.Value, true
	}
	return "", false
}

// sessionDe : session de la requête, ou nil. Une session expire après 90 jours
// sans usage, jamais sur le téléphone associé pendant une navigation en cours
// (RG-CPT-08) ; chaque usage repousse l'expiration.
func (a *app) sessionDe(ctx context.Context, r *http.Request) (*session, error) {
	jeton, parCookie := jetonDe(r)
	if jeton == "" || !a.b.prete() {
		return nil, nil
	}
	s := &session{parCookie: parCookie}
	var derniere time.Time
	var appareil *string
	err := a.b.pool.QueryRow(ctx, `SELECT id, utilisateur_id, support, appareil_id, derniere_utilisation
		FROM sessions WHERE jeton_acces = $1`, empreinte(jeton)).Scan(&s.id, &s.utilisateur, &s.support, &appareil, &derniere)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if time.Since(derniere) > dureeSansUsage && !(appareil != nil && a.navigationEnCoursSurAppareil(ctx, *appareil)) {
		_, err := a.b.pool.Exec(ctx, "DELETE FROM sessions WHERE id = $1", s.id)
		return nil, err
	}
	if time.Since(derniere) > time.Minute {
		if _, err := a.b.pool.Exec(ctx, "UPDATE sessions SET derniere_utilisation = now() WHERE id = $1", s.id); err != nil {
			return nil, err
		}
	}
	return s, nil
}

// navigationEnCoursSurAppareil : vrai si une navigation est en cours sur ce
// téléphone (RG-CPT-08).
func (a *app) navigationEnCoursSurAppareil(ctx context.Context, appareil string) bool {
	var ok bool
	_ = a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM navigations WHERE appareil_id = $1 AND fin_enregistree IS NULL)",
		appareil).Scan(&ok)
	return ok
}

// ouvrirSession : crée une session et rend le jeton d'accès et celui de
// renouvellement (ce dernier pour les applications mobiles seulement).
func (a *app) ouvrirSession(ctx context.Context, utilisateur, support string) (acces, renouvellement string, err error) {
	acces = nouveauJeton()
	var empRenouv []byte
	if support == "mobile" {
		renouvellement = nouveauJeton()
		empRenouv = empreinte(renouvellement)
	}
	_, err = a.b.pool.Exec(ctx, `INSERT INTO sessions (utilisateur_id, jeton_acces, jeton_renouvellement, support)
		VALUES ($1, $2, $3, $4)`, utilisateur, empreinte(acces), empRenouv, support)
	return acces, renouvellement, err
}

type sessionJSON struct {
	JetonAcces          string    `json:"jetonAcces"`
	JetonRenouvellement string    `json:"jetonRenouvellement,omitempty"`
	ExpireLe            time.Time `json:"expireLe"`
}

func nouvelleSessionJSON(acces, renouvellement string) sessionJSON {
	return sessionJSON{acces, renouvellement, time.Now().Add(dureeSansUsage).UTC().Truncate(time.Second)}
}

// poserCookie : cookie de session de la plateforme Web, prolongé à chaque page.
func (a *app) poserCookie(w http.ResponseWriter, jeton string) {
	http.SetCookie(w, &http.Cookie{Name: nomCookie, Value: jeton, Path: a.cfg.Chemin + "/",
		MaxAge: int(dureeSansUsage.Seconds()), HttpOnly: true, Secure: true, SameSite: http.SameSiteLaxMode})
}

func (a *app) effacerCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{Name: nomCookie, Value: "", Path: a.cfg.Chemin + "/",
		MaxAge: -1, HttpOnly: true, Secure: true, SameSite: http.SameSiteLaxMode})
}

// ------------------------------------------------------------------ API

// gestionnaire : opération de l'API ; s est nil pour une opération publique.
type gestionnaire func(w http.ResponseWriter, r *http.Request, s *session) error

// api : enveloppe commune des opérations : base prête, session exigée si
// connecte, refus des envois par cookie venus d'un autre site, erreurs en JSON.
func (a *app) api(connecte bool, g gestionnaire) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !a.b.prete() {
			ecrireErreurJSON(w, errIndisponible)
			return
		}
		s, err := a.sessionDe(r.Context(), r)
		if err != nil {
			ecrireErreurJSON(w, err)
			return
		}
		if connecte && s == nil {
			ecrireErreurJSON(w, errNonAuthentifie())
			return
		}
		if s != nil && s.parCookie && r.Method != http.MethodGet && memeOrigine(r) != nil {
			ecrireErreurJSON(w, errInterdit("interdit", "Requête refusée."))
			return
		}
		if err := g(w, r, s); err != nil {
			ecrireErreurJSON(w, err)
		}
	}
}
