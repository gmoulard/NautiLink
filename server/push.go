package main

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

// Notifications push des amis (RG-IOS-06, RG-AND-08, D-44, D-84, D-86,
// D-92) : alerte SOS (en plus de l'e-mail), début et fin de navigation,
// nouvelle photo, position en retard. Firebase Cloud Messaging pour Android,
// APNs pour l'iPhone. L'ami peut désactiver chaque type, sauf le SOS
// (préférences `push` du profil). Sans identifiants, rien n'est envoyé.

type envoiPush struct {
	fcm     *compteService
	urlFCM  string
	cle     *ecdsa.PrivateKey
	cleID   string
	equipe  string
	bundle  string
	urlAPNs string
	client  *http.Client

	mu        sync.Mutex
	jetonAPNs string
	jetonLe   time.Time

	// synchrone : essais, envoi avant la réponse.
	synchrone bool
}

func nouvelEnvoiPush(cfg config) *envoiPush {
	p := &envoiPush{
		urlFCM:  "https://fcm.googleapis.com",
		cleID:   cfg.APNsCleID,
		equipe:  cfg.APNsEquipe,
		bundle:  cfg.AppleBundle,
		urlAPNs: "https://api.push.apple.com",
		client:  &http.Client{Timeout: 15 * time.Second},
	}
	if cfg.APNsSandbox {
		p.urlAPNs = "https://api.sandbox.push.apple.com"
	}
	var err error
	if p.fcm, err = lireCompteService(cfg.FCMCompte); err != nil {
		log.Printf("notifications push Android désactivées : %v", err)
	}
	if p.cle, err = lireCleP8(cfg.APNsCle); err != nil {
		log.Printf("notifications push iPhone désactivées : %v", err)
	}
	return p
}

func (p *envoiPush) actif() bool {
	return p != nil && (p.fcm != nil || (p.cle != nil && p.cleID != "" && p.equipe != ""))
}

// messagePush : contenu d'une notification ; type et navigation servent à
// ouvrir la navigation dans l'application (RG-AND-09).
type messagePush struct {
	Titre, Texte, Type, NavigationID string
}

// errJetonPerime : jeton refusé par FCM ou APNs (application désinstallée) ;
// il est oublié.
var errJetonPerime = fmt.Errorf("jeton push périmé")

func (p *envoiPush) envoyer(ctx context.Context, plateforme, jeton string, m messagePush) error {
	switch plateforme {
	case "android":
		return p.envoyerFCM(ctx, jeton, m)
	case "ios":
		return p.envoyerAPNs(ctx, jeton, m)
	}
	return nil
}

func (p *envoiPush) poster(req *http.Request) (int, []byte, error) {
	rep, err := p.client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer rep.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(rep.Body, 1<<16))
	return rep.StatusCode, b, nil
}

func (p *envoiPush) envoyerFCM(ctx context.Context, jeton string, m messagePush) error {
	if p.fcm == nil {
		return nil
	}
	acces, err := p.fcm.jeton(ctx, "https://www.googleapis.com/auth/firebase.messaging")
	if err != nil {
		return err
	}
	priorite := "normal"
	if m.Type == "sos" {
		priorite = "high"
	}
	corps, _ := json.Marshal(map[string]any{"message": map[string]any{
		"token":        jeton,
		"notification": map[string]string{"title": m.Titre, "body": m.Texte},
		"data":         map[string]string{"type": m.Type, "navigationId": m.NavigationID},
		"android":      map[string]any{"priority": priorite},
	}})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		p.urlFCM+"/v1/projects/"+url.PathEscape(p.fcm.Projet)+"/messages:send", bytes.NewReader(corps))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+acces)
	req.Header.Set("Content-Type", "application/json")
	code, b, err := p.poster(req)
	if err != nil {
		return err
	}
	if code == http.StatusNotFound || (code == http.StatusBadRequest && bytes.Contains(b, []byte("UNREGISTERED"))) {
		return errJetonPerime
	}
	if code/100 != 2 {
		return fmt.Errorf("FCM : %d %s", code, b)
	}
	return nil
}

// jetonFournisseur : JWT ES256 d'APNs, renouvelé toutes les 50 minutes
// (Apple le refuse au-delà d'une heure).
func (p *envoiPush) jetonFournisseur() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.jetonAPNs != "" && time.Since(p.jetonLe) < 50*time.Minute {
		return p.jetonAPNs, nil
	}
	t := time.Now()
	j, err := jwtSigne(map[string]any{"alg": "ES256", "kid": p.cleID}, map[string]any{"iss": p.equipe, "iat": t.Unix()}, p.cle)
	if err != nil {
		return "", err
	}
	p.jetonAPNs, p.jetonLe = j, t
	return j, nil
}

func (p *envoiPush) envoyerAPNs(ctx context.Context, jeton string, m messagePush) error {
	if p.cle == nil || p.cleID == "" || p.equipe == "" {
		return nil
	}
	fournisseur, err := p.jetonFournisseur()
	if err != nil {
		return err
	}
	aps := map[string]any{"alert": map[string]string{"title": m.Titre, "body": m.Texte}, "sound": "default"}
	if m.Type == "sos" {
		aps["interruption-level"] = "time-sensitive"
	}
	corps, _ := json.Marshal(map[string]any{"aps": aps, "type": m.Type, "navigationId": m.NavigationID})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.urlAPNs+"/3/device/"+url.PathEscape(jeton), bytes.NewReader(corps))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "bearer "+fournisseur)
	req.Header.Set("apns-topic", p.bundle)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")
	code, b, err := p.poster(req)
	if err != nil {
		return err
	}
	if code == http.StatusGone || (code == http.StatusBadRequest && bytes.Contains(b, []byte("BadDeviceToken"))) {
		return errJetonPerime
	}
	if code/100 != 2 {
		return fmt.Errorf("APNs : %d %s", code, b)
	}
	return nil
}

// colonnePush : préférence du profil pour chaque type ; le SOS ne se
// désactive pas (RG-IOS-06).
var colonnePush = map[string]string{
	"debut":              "u.push_debut",
	"fin":                "u.push_fin",
	"photo":              "u.push_photo",
	"position_en_retard": "u.push_position_en_retard",
	"sos":                "true",
}

// notifier : notification [typ] aux amis d'une navigation (ou, hors
// navigation, aux amis de périmètre navigateur, RG-SOS-15), sur chacun
// de leurs téléphones, sans les personnes décochées au démarrage
// (RG-NAV-25). Lancé sans faire attendre l'appelant.
func (a *app) notifier(navigateur string, navigation *string, typ string, texte func(langue string) (string, string)) {
	if !a.push.actif() {
		return
	}
	envoi := func() {
		ctx, fin := context.WithTimeout(context.Background(), time.Minute)
		defer fin()
		if err := a.notifierMaintenant(ctx, navigateur, navigation, typ, texte); err != nil {
			log.Printf("notifications push %s : %v", typ, err)
		}
	}
	if a.push.synchrone {
		envoi()
	} else {
		go envoi()
	}
}

func (a *app) notifierMaintenant(ctx context.Context, navigateur string, navigation *string, typ string,
	texte func(langue string) (string, string)) error {
	col, ok := colonnePush[typ]
	if !ok {
		return fmt.Errorf("type inconnu %q", typ)
	}
	lignes, err := a.b.pool.Query(ctx, `SELECT DISTINCT ap.id, ap.plateforme, ap.jeton_push, u.langue
		FROM acces ac JOIN utilisateurs u ON u.id = ac.ami_id JOIN appareils ap ON ap.utilisateur_id = u.id
		WHERE ac.navigateur_id = $1 AND u.id <> $1 AND coalesce(ap.jeton_push, '') <> '' AND `+col+`
		AND (ac.perimetre = 'navigateur' OR ($2::uuid IS NOT NULL AND ac.navigation_id = $2::uuid))
		AND NOT EXISTS (SELECT 1 FROM retraits_navigation r WHERE r.navigation_id = $2::uuid AND r.ami_id = u.id)
		AND ($2::uuid IS NULL OR ac.contact_id IS NULL OR NOT EXISTS (SELECT 1 FROM navigations n
			WHERE n.id = $2::uuid AND n.personnes_alertees IS NOT NULL AND NOT ac.contact_id = ANY(n.personnes_alertees)
			AND ac.accorde_le <= n.creee_le))`, navigateur, navigation)
	if err != nil {
		return err
	}
	type dest struct{ id, plateforme, jeton, langue string }
	dests, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (dest, error) {
		var d dest
		err := l.Scan(&d.id, &d.plateforme, &d.jeton, &d.langue)
		return d, err
	})
	if err != nil {
		return err
	}
	nav := ""
	if navigation != nil {
		nav = *navigation
	}
	for _, d := range dests {
		titre, corps := texte(d.langue)
		err := a.push.envoyer(ctx, d.plateforme, d.jeton, messagePush{titre, corps, typ, nav})
		if err == errJetonPerime {
			_, _ = a.b.pool.Exec(ctx, "UPDATE appareils SET jeton_push = NULL WHERE id = $1 AND jeton_push = $2", d.id, d.jeton)
		} else if err != nil {
			log.Printf("notification push %s vers %s : %v", typ, d.id, err)
		}
	}
	return nil
}

// infosPush : nom du navigateur, du bateau et de la navigation, et décalage
// horaire du téléphone (RG-PRM-07), pour les textes.
func (a *app) infosPush(ctx context.Context, navigation string) (navigateur, nomNav, bateau, nomNavigateur string, decalage *int, err error) {
	err = a.b.pool.QueryRow(ctx, `SELECT n.navigateur_id, n.nom, b.nom, u.nom, n.decalage_minutes FROM navigations n
		JOIN bateaux b ON b.id = n.bateau_id JOIN utilisateurs u ON u.id = n.navigateur_id WHERE n.id = $1`, navigation).
		Scan(&navigateur, &nomNav, &bateau, &nomNavigateur, &decalage)
	return
}

// notifierNavigation : début, fin ou nouvelle photo d'une navigation, avec
// l'heure de l'événement (RG-PRM-07).
func (a *app) notifierNavigation(ctx context.Context, navigation, typ string, heure time.Time) {
	if !a.push.actif() {
		return
	}
	navigateur, nomNav, bateau, qui, decalage, err := a.infosPush(ctx, navigation)
	if err != nil {
		log.Printf("notification push %s : %v", typ, err)
		return
	}
	h := heureEnvoyee(heure, decalage, false)
	a.notifier(navigateur, &navigation, typ, func(l string) (string, string) {
		switch typ {
		case "debut":
			return enLangue(l, qui+" a démarré une navigation", qui+" has started a trip"), nomNav + " · " + bateau + " · " + h
		case "fin":
			return enLangue(l, qui+" a terminé sa navigation", qui+" has ended the trip"), nomNav + " · " + bateau + " · " + h
		case "photo":
			return enLangue(l, "Nouvelle photo", "New photo"), nomNav + " · " + qui + " · " + h
		}
		return nomNav, bateau
	})
}

// notifierSos : alerte SOS, en plus de l'e-mail (RG-IOS-06, RG-AND-08).
func (a *app) notifierSos(ctx context.Context, alerte string) {
	if !a.push.actif() {
		return
	}
	var navigateur, bateau, qui string
	var navigation, probleme *string
	var heure time.Time
	var decalage *int
	if err := a.b.pool.QueryRow(ctx, `SELECT al.navigateur_id, al.navigation_id::text, b.nom, u.nom, al.probleme,
		al.heure_declenchement, al.decalage_minutes
		FROM alertes_sos al JOIN bateaux b ON b.id = al.bateau_id JOIN utilisateurs u ON u.id = al.navigateur_id
		WHERE al.id = $1`, alerte).Scan(&navigateur, &navigation, &bateau, &qui, &probleme, &heure, &decalage); err != nil {
		log.Printf("notification push SOS : %v", err)
		return
	}
	a.notifier(navigateur, navigation, "sos", func(l string) (string, string) {
		h := heureEnvoyee(heure, decalage, false)
		t := enLangue(l, qui+" a déclenché une alerte SOS à "+h+".", qui+" raised an SOS alert at "+h+".")
		if probleme != nil && *probleme != "" {
			t += " " + *probleme
		}
		return "SOS — " + bateau, t
	})
}

// positionsEnRetard : tâche de chaque minute (D-84) : une navigation en
// cours sans position reçue pendant deux fois sa fréquence donne une seule
// notification, jusqu'à la position suivante.
func (a *app) positionsEnRetard(ctx context.Context) error {
	if !a.push.actif() {
		return nil
	}
	lignes, err := a.b.pool.Query(ctx, `SELECT n.id, extract(epoch FROM $1 - d.derniere)::bigint / 60, d.derniere FROM navigations n
		CROSS JOIN LATERAL (SELECT coalesce(max(e.recu_le), n.creee_le) AS derniere FROM evenements e
			WHERE e.navigation_id = n.id AND e.latitude IS NOT NULL) d
		WHERE n.fin_enregistree IS NULL AND n.supprimee_le IS NULL
		AND d.derniere < $1 - make_interval(mins => 2 * n.frequence_minutes)
		AND (n.retard_push_le IS NULL OR n.retard_push_le < d.derniere)`, a.maintenant())
	if err != nil {
		return err
	}
	type retard struct {
		id       string
		minutes  int64
		derniere time.Time
	}
	retards, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (retard, error) {
		var r retard
		err := l.Scan(&r.id, &r.minutes, &r.derniere)
		return r, err
	})
	if err != nil {
		return err
	}
	for _, r := range retards {
		if _, err := a.b.pool.Exec(ctx, "UPDATE navigations SET retard_push_le = $2 WHERE id = $1", r.id, a.maintenant()); err != nil {
			return err
		}
		navigateur, nomNav, bateau, _, decalage, err := a.infosPush(ctx, r.id)
		if err != nil {
			return err
		}
		id := r.id
		duree := fmt.Sprintf("%d h %02d", r.minutes/60, r.minutes%60)
		h := heureEnvoyee(r.derniere, decalage, false)
		a.notifier(navigateur, &id, "position_en_retard", func(l string) (string, string) {
			return enLangue(l, "Position en retard — ", "Position overdue — ") + bateau,
				nomNav + enLangue(l, " : aucune position reçue depuis "+h+", soit ", ": no position received since "+h+", that is ") + duree
		})
	}
	return nil
}
