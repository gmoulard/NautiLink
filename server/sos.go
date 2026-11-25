package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

// Alertes SOS et e-mails de notification (TODO-4.7) : RG-SOS-02 à RG-SOS-06,
// RG-SOS-09 à RG-SOS-13, RG-SOS-15, RG-ECO-12, RG-NAV-25, RG-NOT-01 à
// RG-NOT-03, RG-PRM-04. Une alerte est acceptée quel que soit le quota,
// l'abonnement ou la confirmation de l'adresse e-mail (RG-SOS-03,
// RG-CPT-09) ; elle est rejouable sans doublon (08-architecture.md §5).
// Contenu des e-mails : Q-56 ; relance des e-mails en échec : Q-57 ; SOS
// après la fin : Q-58 ; historique vu des suiveurs : Q-59 ; personnes
// ajoutées pendant la navigation : Q-60 (propositions appliquées en attendant).

type statutSmsJSON struct {
	ContactID  *string    `json:"contactId"`
	Telephone  string     `json:"telephone"`
	Rang       int        `json:"rang"`
	Statut     string     `json:"statut"`
	Essais     int        `json:"essais"`
	MisAJourLe *time.Time `json:"misAJourLe,omitempty"`
}

var statutsSmsPermis = []string{"en_attente", "accepte_pour_envoi", "livraison_confirmee", "echec"}

type alerteSosJSON struct {
	ID                 string          `json:"id"`
	BateauID           string          `json:"bateauId"`
	NavigationID       *string         `json:"navigationId"`
	AppareilID         string          `json:"appareilId,omitempty"`
	HeureDeclenchement time.Time       `json:"heureDeclenchement"`
	Position           *positionJSON   `json:"position,omitempty"`
	NaturePosition     string          `json:"naturePosition"`
	ProblemeRencontre  *string         `json:"problemeRencontre"`
	PersonnesABord     *int            `json:"personnesABord,omitempty"`
	Sms                []statutSmsJSON `json:"sms"`
	EmailsEnvoyesA     []string        `json:"emailsEnvoyesA"`
}

// normaliser : contrôles de l'alerte reçue. Un SOS n'est refusé que pour un
// défaut de l'application (identifiants, heure, position impossible) ; la
// nature de la position se déduit de sa présence (RG-SOS-09 à RG-SOS-11).
func (al *alerteSosJSON) normaliser() error {
	if !estUUID(al.ID) {
		return errInvalide("Identifiant d'alerte invalide.")
	}
	if al.NavigationID != nil && *al.NavigationID == "" {
		al.NavigationID = nil
	}
	if al.NavigationID != nil && !estUUID(*al.NavigationID) {
		return errInvalide("Identifiant de navigation invalide.")
	}
	if al.NavigationID == nil && !estUUID(al.BateauID) {
		return errInvalide("Indiquez le bateau de l'alerte.")
	}
	if al.AppareilID != "" && !estUUID(al.AppareilID) {
		return errInvalide("Identifiant de téléphone invalide.")
	}
	if al.HeureDeclenchement.IsZero() {
		return errInvalide("Heure de déclenchement manquante.")
	}
	if err := al.Position.valider(); err != nil {
		return err
	}
	switch {
	case al.Position == nil:
		al.NaturePosition = "aucune"
	case al.NaturePosition != "derniere_connue":
		al.NaturePosition = "actuelle"
	}
	al.ProblemeRencontre = texteOuNul(al.ProblemeRencontre)
	if al.PersonnesABord != nil && *al.PersonnesABord < 1 {
		al.PersonnesABord = nil
	}
	return nil
}

// empreinte : contenu envoyé par le téléphone, pour reconnaître un renvoi.
func (al alerteSosJSON) empreinte() []byte {
	var p *positionJSON
	if al.Position != nil {
		q := *al.Position
		q.HeureAcquisition = q.HeureAcquisition.UTC()
		p = &q
	}
	b, _ := json.Marshal([]any{al.BateauID, al.NavigationID, al.AppareilID, al.HeureDeclenchement.UTC(), p,
		al.NaturePosition, al.ProblemeRencontre, al.PersonnesABord})
	h := sha256.Sum256(b)
	return h[:]
}

// ------------------------------------------------------------------ réception

// envoyerAlerte : PUT /v1/alertes-sos/{alerteId}. Rend 201 (enregistrée,
// e-mails lancés) ou 200 (déjà reçue).
func (a *app) envoyerAlerte(ctx context.Context, r *http.Request, utilisateur, id string, al alerteSosJSON) (int, alerteSosJSON, error) {
	al.ID = id
	if err := al.normaliser(); err != nil {
		return 0, al, err
	}
	emp := al.empreinte()
	if code, deja, err := a.alerteDejaRecue(ctx, utilisateur, id, emp); code != 0 || err != nil {
		return code, deja, err
	}
	bateau, personnes := al.BateauID, al.PersonnesABord
	var navigation *string
	var n navLigne
	if al.NavigationID != nil {
		var err error
		if n, err = a.navigationDuNavigateur(ctx, utilisateur, *al.NavigationID); err != nil {
			return 0, al, err
		}
		bateau = n.bateau
		if personnes == nil {
			personnes = &n.personnes
		}
		// SOS déclenché après la fin enregistrée (clôture automatique,
		// RG-ECO-12, ou fin ordinaire, Q-58) : SOS depuis l'accueil.
		if n.finEnr == nil || !al.HeureDeclenchement.After(*n.finEnr) {
			navigation = &n.id
		}
	} else if ok, err := a.peutDemarrer(ctx, utilisateur, bateau); err != nil {
		return 0, al, err
	} else if !ok {
		return 0, al, errInterdit("pas_proprietaire", "Choisissez l'un de vos bateaux.")
	}
	var lat, lon, prec *float64
	var hp *time.Time
	if al.Position != nil {
		lat, lon, prec, hp = &al.Position.Latitude, &al.Position.Longitude, al.Position.PrecisionMetres, &al.Position.HeureAcquisition
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return 0, al, err
	}
	defer tx.Rollback(ctx)
	_, err = tx.Exec(ctx, `INSERT INTO alertes_sos (id, navigateur_id, bateau_id, navigation_id, appareil_id, heure_declenchement,
		latitude, longitude, precision_metres, heure_position, nature_position, probleme, personnes_a_bord, empreinte)
		VALUES ($1, $2, $3, $4, nullif($5, '')::uuid, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
		id, utilisateur, bateau, navigation, al.AppareilID, al.HeureDeclenchement, lat, lon, prec, hp,
		al.NaturePosition, al.ProblemeRencontre, personnes, emp)
	if estDoublon(err) {
		// Deux envois simultanés de la même alerte : le second est un renvoi.
		tx.Rollback(ctx)
		code, deja, err := a.alerteDejaRecue(ctx, utilisateur, id, emp)
		if code == 0 && err == nil {
			err = errEvenementDifferent()
		}
		return code, deja, err
	}
	if err != nil {
		return 0, al, err
	}
	// Enregistrement dans le journal de la navigation (RG-SOS-04, RG-JRN-02) ;
	// hors navigation, seulement dans l'historique du bateau (RG-SOS-15).
	if navigation != nil {
		e := evenementJSON{ID: id, Type: "sos", HeureAcquisition: al.HeureDeclenchement, Position: al.Position, AlerteSosID: &id}
		if al.Position != nil {
			g := al.NaturePosition == "actuelle"
			e.GpsDisponible = &g
		}
		if err := insererEvenement(ctx, tx, *navigation, e); err != nil {
			return 0, al, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, al, err
	}
	a.lancerEmailsSos(a.adressePublique(r), id)
	res, err := a.alerte(ctx, id)
	return http.StatusCreated, res, err
}

// alerteDejaRecue : renvoi d'une alerte reçue (200) ou contenu différent sous
// le même identifiant (409) ; code 0 si l'alerte est inconnue.
func (a *app) alerteDejaRecue(ctx context.Context, utilisateur, id string, emp []byte) (int, alerteSosJSON, error) {
	var auteur string
	var deja []byte
	err := a.b.pool.QueryRow(ctx, "SELECT navigateur_id, empreinte FROM alertes_sos WHERE id = $1", id).Scan(&auteur, &deja)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, alerteSosJSON{}, nil
	}
	if err != nil {
		return 0, alerteSosJSON{}, err
	}
	if auteur != utilisateur || string(deja) != string(emp) {
		return 0, alerteSosJSON{}, errEvenementDifferent()
	}
	al, err := a.alerte(ctx, id)
	return http.StatusOK, al, err
}

const colonnesAlerte = `id, bateau_id, navigation_id::text, coalesce(appareil_id::text, ''), heure_declenchement, latitude, longitude,
	precision_metres, heure_position, nature_position, probleme, personnes_a_bord, emails_envoyes_a`

func lireAlerte(l pgx.Row) (alerteSosJSON, error) {
	var al alerteSosJSON
	var lat, lon, prec *float64
	var hp *time.Time
	err := l.Scan(&al.ID, &al.BateauID, &al.NavigationID, &al.AppareilID, &al.HeureDeclenchement, &lat, &lon, &prec, &hp,
		&al.NaturePosition, &al.ProblemeRencontre, &al.PersonnesABord, &al.EmailsEnvoyesA)
	if lat != nil && lon != nil {
		al.Position = &positionJSON{Latitude: *lat, Longitude: *lon, PrecisionMetres: prec, HeureAcquisition: al.HeureDeclenchement}
		if hp != nil {
			al.Position.HeureAcquisition = *hp
		}
	}
	if al.EmailsEnvoyesA == nil {
		al.EmailsEnvoyesA = []string{}
	}
	return al, err
}

func (a *app) alerte(ctx context.Context, id string) (alerteSosJSON, error) {
	al, err := lireAlerte(a.b.pool.QueryRow(ctx, "SELECT "+colonnesAlerte+" FROM alertes_sos WHERE id = $1", id))
	if err != nil {
		return al, err
	}
	al.Sms, err = a.statutsSmsDe(ctx, id)
	return al, err
}

func (a *app) statutsSmsDe(ctx context.Context, alerte string) ([]statutSmsJSON, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT contact_id::text, telephone, rang, statut, essais, mis_a_jour_le
		FROM statuts_sms WHERE alerte_id = $1 ORDER BY rang, telephone`, alerte)
	if err != nil {
		return nil, err
	}
	l, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (statutSmsJSON, error) {
		var s statutSmsJSON
		var m time.Time
		err := l.Scan(&s.ContactID, &s.Telephone, &s.Rang, &s.Statut, &s.Essais, &m)
		s.MisAJourLe = &m
		return s, err
	})
	if l == nil {
		l = []statutSmsJSON{}
	}
	return l, err
}

// ------------------------------------------------------------------ statuts des SMS SOS

// statutsSms : PUT /v1/alertes-sos/{alerteId}/sms (RG-SOS-12) : statut de
// chaque SMS SOS envoyé par le téléphone Android ; un statut plus ancien que
// celui déjà reçu ne le remplace pas.
func (a *app) statutsSms(ctx context.Context, utilisateur, id string, statuts []statutSmsJSON) error {
	if !estUUID(id) {
		return errIntrouvable()
	}
	var auteur string
	if err := a.b.pool.QueryRow(ctx, "SELECT navigateur_id FROM alertes_sos WHERE id = $1", id).Scan(&auteur); err != nil {
		return err
	}
	if auteur != utilisateur {
		return errIntrouvable()
	}
	for _, s := range statuts {
		s.Telephone = strings.TrimSpace(s.Telephone)
		if s.Telephone == "" || (s.Rang != 1 && s.Rang != 2) || !slices.Contains(statutsSmsPermis, s.Statut) || s.Essais < 0 {
			return errInvalide("Statut de SMS invalide : téléphone, rang 1 ou 2, statut en_attente, accepte_pour_envoi, livraison_confirmee ou echec.")
		}
		if s.ContactID != nil && *s.ContactID != "" && !estUUID(*s.ContactID) {
			return errInvalide("Contact invalide.")
		}
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	for _, s := range statuts {
		m := a.maintenant()
		if s.MisAJourLe != nil {
			m = *s.MisAJourLe
		}
		if _, err := tx.Exec(ctx, `INSERT INTO statuts_sms (alerte_id, telephone, rang, contact_id, statut, essais, mis_a_jour_le)
			VALUES ($1, $2, $3, nullif($4, '')::uuid, $5, $6, $7)
			ON CONFLICT (alerte_id, telephone, rang) DO UPDATE SET contact_id = EXCLUDED.contact_id, statut = EXCLUDED.statut,
			essais = EXCLUDED.essais, mis_a_jour_le = EXCLUDED.mis_a_jour_le WHERE statuts_sms.mis_a_jour_le <= EXCLUDED.mis_a_jour_le`,
			id, s.Telephone, s.Rang, texteOuVide(s.ContactID), s.Statut, s.Essais, m); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func texteOuVide(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

// ------------------------------------------------------------------ historique

// alertes : GET /v1/alertes-sos (RG-SOS-12, RG-SOS-13) : alertes du
// navigateur, et pour un suiveur celles des navigations qu'il voit
// (RG-PAR-07) et, hors navigation, celles des navigateurs qu'il suit avec
// le périmètre navigateur (Q-59).
func (a *app) alertes(ctx context.Context, utilisateur, bateau, navigation string) ([]alerteSosJSON, error) {
	if (bateau != "" && !estUUID(bateau)) || (navigation != "" && !estUUID(navigation)) {
		return []alerteSosJSON{}, nil
	}
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesAlerte+` FROM alertes_sos al
		WHERE (al.navigateur_id = $1
			OR (al.navigation_id IS NOT NULL AND EXISTS (SELECT 1 FROM navigations n WHERE n.id = al.navigation_id AND `+conditionSuiveur+`))
			OR (al.navigation_id IS NULL AND EXISTS (SELECT 1 FROM acces ac WHERE ac.suiveur_id = $1
				AND ac.navigateur_id = al.navigateur_id AND ac.perimetre = 'navigateur')))
		AND ($2 = '' OR al.bateau_id::text = $2) AND ($3 = '' OR al.navigation_id::text = $3)
		ORDER BY al.heure_declenchement DESC, al.id`, utilisateur, strings.ToLower(bateau), strings.ToLower(navigation))
	if err != nil {
		return nil, err
	}
	l, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (alerteSosJSON, error) { return lireAlerte(l) })
	if err != nil {
		return nil, err
	}
	for i := range l {
		if l[i].Sms, err = a.statutsSmsDe(ctx, l[i].ID); err != nil {
			return nil, err
		}
	}
	if l == nil {
		l = []alerteSosJSON{}
	}
	return l, nil
}

// ------------------------------------------------------------------ e-mails SOS

// verrouEmailsSos : un seul envoi des e-mails SOS à la fois, pour que la
// relance chaque minute ne double pas l'envoi qui suit la réception.
var verrouEmailsSos sync.Mutex

// lancerEmailsSos : e-mails de l'alerte, sans faire attendre la réponse au
// téléphone (dans les essais, avant la réponse).
func (a *app) lancerEmailsSos(adresse, id string) {
	envoi := func() {
		if err := a.emailsSos(context.Background(), adresse, id); err != nil {
			log.Printf("alerte SOS %s : e-mails : %v", id, err)
		}
	}
	if a.mailSynchrone {
		envoi()
	} else {
		go envoi()
	}
}

type donneesSos struct {
	al                        alerteSosJSON
	navigateur, emailNav, lng string
	bateau                    bateauJSON
	nomNavigation             string
}

// destinatairesSos : suiveurs de la navigation, ou de périmètre navigateur
// hors navigation (RG-SOS-06, RG-SOS-15), et contacts SOS dont l'e-mail est
// connu, sans les personnes décochées au démarrage (RG-NAV-25) ; un
// suiveur dont l'accès a été accordé après le démarrage n'a pas pu être
// décoché : il est prévenu (Q-60). Une adresse ne reçoit qu'un e-mail. La
// copie au navigateur (RG-NOT-03) est à part.
func (a *app) destinatairesSos(ctx context.Context, navigateur string, navigation *string, alertees []string) ([]string, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT u.email FROM acces ac JOIN utilisateurs u ON u.id = ac.suiveur_id
		WHERE ac.navigateur_id = $1 AND u.id <> $1
		AND (ac.perimetre = 'navigateur' OR ($2::uuid IS NOT NULL AND ac.navigation_id = $2::uuid))
		AND NOT EXISTS (SELECT 1 FROM retraits_navigation r WHERE r.navigation_id = $2::uuid AND r.suiveur_id = u.id)
		AND ($3::text[] IS NULL OR ac.contact_id IS NULL OR ac.contact_id::text = ANY($3::text[])
			OR ac.accorde_le > (SELECT creee_le FROM navigations WHERE id = $2::uuid))
		UNION ALL
		SELECT c.email FROM contacts c WHERE c.navigateur_id = $1 AND c.contact_sos AND c.supprime_le IS NULL
		AND coalesce(c.email, '') <> '' AND ($3::text[] IS NULL OR c.id::text = ANY($3::text[]))`, navigateur, navigation, alertees)
	if err != nil {
		return nil, err
	}
	adresses, err := pgx.CollectRows(lignes, pgx.RowTo[string])
	if err != nil {
		return nil, err
	}
	return sansDoublon(adresses), nil
}

func sansDoublon(adresses []string) []string {
	vues := map[string]bool{}
	var l []string
	for _, x := range adresses {
		x = strings.TrimSpace(x)
		if k := strings.ToLower(x); x != "" && !vues[k] {
			vues[k] = true
			l = append(l, x)
		}
	}
	return l
}

// emailsSos : envoie les e-mails de l'alerte qui ne sont pas encore partis
// (emails_envoyes_a : adresses acceptées par le relais) ; un échec est
// relancé chaque minute (Q-57).
func (a *app) emailsSos(ctx context.Context, adresse, id string) error {
	verrouEmailsSos.Lock()
	defer verrouEmailsSos.Unlock()
	al, err := a.alerte(ctx, id)
	if err != nil {
		return err
	}
	d := donneesSos{al: al}
	var navigateur string
	if err := a.b.pool.QueryRow(ctx, "SELECT navigateur_id, u.nom, u.email, u.langue FROM alertes_sos JOIN utilisateurs u ON u.id = navigateur_id WHERE alertes_sos.id = $1",
		id).Scan(&navigateur, &d.navigateur, &d.emailNav, &d.lng); err != nil {
		return err
	}
	if d.bateau, err = lireBateau(a.b.pool.QueryRow(ctx, "SELECT "+colonnesBateau+" FROM bateaux WHERE id = $1", al.BateauID)); err != nil {
		return err
	}
	var alertees []string
	if al.NavigationID != nil {
		n, err := a.navigation(ctx, a.b.pool, *al.NavigationID)
		if err != nil {
			return err
		}
		alertees, d.nomNavigation = n.alertees, n.nom
	}
	dests, err := a.destinatairesSos(ctx, navigateur, al.NavigationID, alertees)
	if err != nil {
		return err
	}
	deja := map[string]bool{}
	for _, x := range al.EmailsEnvoyesA {
		deja[strings.ToLower(x)] = true
	}
	sujet, texte := texteSos(d, adresse)
	var premiere error
	envoyer := func(dest, sujet, texte string) {
		if deja[strings.ToLower(dest)] {
			return
		}
		if err := a.envoyer(dest, sujet, texte); err != nil {
			if premiere == nil {
				premiere = fmt.Errorf("%s : %w", dest, err)
			}
			return
		}
		deja[strings.ToLower(dest)] = true
		if _, err := a.b.pool.Exec(ctx, `UPDATE alertes_sos SET emails_envoyes_a = array_append(emails_envoyes_a, $2)
			WHERE id = $1 AND NOT ($2 = ANY(emails_envoyes_a))`, id, dest); err != nil && premiere == nil {
			premiere = err
		}
	}
	for _, x := range dests {
		envoyer(x, sujet, texte)
	}
	if d.emailNav != "" {
		cs, ct := copieSos(d, dests, sujet, texte)
		envoyer(d.emailNav, cs, ct)
	}
	return premiere
}

// relanceEmailsSos : délai pendant lequel les e-mails SOS en échec sont
// relancés chaque minute (Q-57).
const relanceEmailsSos = 24 * time.Hour

// relancerEmailsSos : tâche de fond, chaque minute ; les alertes reçues
// depuis moins d'une minute sont laissées à l'envoi qui suit la réception.
func (a *app) relancerEmailsSos(ctx context.Context) error {
	t := a.maintenant()
	lignes, err := a.b.pool.Query(ctx, `SELECT id::text FROM alertes_sos WHERE recue_le > $1 AND recue_le <= $2
		ORDER BY recue_le`, t.Add(-relanceEmailsSos), t.Add(-time.Minute))
	if err != nil {
		return err
	}
	ids, err := pgx.CollectRows(lignes, pgx.RowTo[string])
	if err != nil {
		return err
	}
	for _, id := range ids {
		if err := a.emailsSos(ctx, a.cfg.AdressePublique, id); err != nil {
			log.Printf("alerte SOS %s : relance des e-mails : %v", id, err)
		}
	}
	return nil
}

// ------------------------------------------------------------------ textes (Q-56)

func enLangue(lng, fr, en string) string {
	if lng == "en" {
		return en
	}
	return fr
}

func heureTexte(t time.Time) string { return t.UTC().Format("2006-01-02 15:04") + " UTC" }

func nombreTexte(v *float64, unite string) string {
	if v == nil {
		return ""
	}
	return strings.TrimSuffix(strings.TrimRight(fmt.Sprintf("%.2f", *v), "0"), ".") + " " + unite
}

// texteSos : contenu des deux SMS SOS (RG-SOS-07, RG-SOS-08, RG-SOS-09 à
// RG-SOS-11) dans la langue du navigateur (RG-PRM-04), avec le lien vers la
// page de la navigation (Q-56, proposition).
func texteSos(d donneesSos, adresse string) (string, string) {
	l, al, b := d.lng, d.al, d.bateau
	sujet := enLangue(l, "SOS — "+b.Nom+" : alerte de "+d.navigateur, "SOS — "+b.Nom+": distress alert from "+d.navigateur)
	var s strings.Builder
	s.WriteString(enLangue(l, "ALERTE SOS envoyée par ", "SOS ALERT sent by ") + d.navigateur +
		enLangue(l, " depuis le bateau ", " from the boat ") + b.Nom + enLangue(l, ", le ", ", on ") + heureTexte(al.HeureDeclenchement) + ".\n\n")
	ligne := func(fr, en, v string) {
		if strings.TrimSpace(v) != "" {
			s.WriteString(enLangue(l, fr, en) + " : " + v + "\n")
		}
	}
	ligne("Bateau", "Boat", b.Nom)
	ligne("Type", "Type", b.Type)
	ligne("Longueur", "Length", nombreTexte(b.LongueurMetres, "m"))
	ligne("Immatriculation", "Registration", b.Immatriculation)
	if al.PersonnesABord != nil {
		ligne("Personnes à bord", "People on board", fmt.Sprint(*al.PersonnesABord))
	}
	if al.ProblemeRencontre != nil {
		ligne("Problème rencontré", "Problem", *al.ProblemeRencontre)
	}
	s.WriteString("\n")
	if p := al.Position; p == nil {
		s.WriteString(enLangue(l, "GPS indisponible : aucune position connue.\n", "GPS unavailable: no known position.\n"))
	} else {
		if al.NaturePosition == "derniere_connue" {
			s.WriteString(enLangue(l, "GPS indisponible. Dernière position connue, pas nécessairement la position actuelle :\n",
				"GPS unavailable. Last known position, not necessarily the current position:\n"))
		} else {
			s.WriteString(enLangue(l, "Position :\n", "Position:\n"))
		}
		s.WriteString(fmt.Sprintf("%.5f, %.5f", p.Latitude, p.Longitude) + enLangue(l, " (acquise le ", " (acquired on ") +
			heureTexte(p.HeureAcquisition) + ")\n" + fmt.Sprintf("https://www.google.com/maps?q=%.5f,%.5f", p.Latitude, p.Longitude) + "\n")
	}
	s.WriteString("\n")
	ligne("Port d'attache", "Home port", b.PortAttache)
	ligne("Moteur", "Engine", b.Moteur)
	ligne("Autonomie", "Range", b.Autonomie)
	ligne("Capacité en carburant", "Fuel capacity", nombreTexte(b.CapaciteCarburantLitres, "l"))
	ligne("Vitesse", "Speed", nombreTexte(b.VitesseNoeuds, enLangue(l, "nœuds", "knots")))
	ligne("Tirant d'eau", "Draught", nombreTexte(b.TirantEauMetres, "m"))
	if al.NavigationID != nil && adresse != "" {
		s.WriteString("\n" + enLangue(l, "Navigation « ", "Trip “") + d.nomNavigation + enLangue(l, " » : ", "”: ") +
			adresse + "/navigations/" + *al.NavigationID + "\n")
	}
	s.WriteString("\nNautiLink — " + enLangue(l, "Version bêta", "Beta version") + "\n")
	return sujet, s.String()
}

// copieSos : copie au navigateur (RG-NOT-03), avec la liste des adresses
// prévenues.
func copieSos(d donneesSos, dests []string, sujet, texte string) (string, string) {
	l := d.lng
	liste := strings.Join(dests, ", ")
	if liste == "" {
		liste = enLangue(l, "aucun suiveur ni contact SOS avec e-mail", "no follower or SOS contact with an e-mail address")
	}
	return enLangue(l, "Copie — ", "Copy — ") + sujet,
		enLangue(l, "Copie de votre alerte SOS, envoyée par e-mail à : ", "Copy of your SOS alert, sent by e-mail to: ") + liste + "\n\n" + texte
}

// ------------------------------------------------------------------ e-mail de début (RG-NOT-02)

// emailsDebut : e-mail de début de navigation aux suiveurs de la navigation
// qui ne s'en sont pas désinscrits (RG-NOT-02, RG-NOT-04), sauf les personnes
// décochées au démarrage (RG-NAV-25), et copie au navigateur (RG-NOT-03).
func (a *app) emailsDebut(ctx context.Context, n navLigne) error {
	lignes, err := a.b.pool.Query(ctx, `SELECT u.email FROM acces ac JOIN utilisateurs u ON u.id = ac.suiveur_id
		WHERE ac.navigateur_id = $1 AND u.id <> $1 AND u.emails_debut
		AND (ac.perimetre = 'navigateur' OR ac.navigation_id = $2)
		AND NOT EXISTS (SELECT 1 FROM retraits_navigation r WHERE r.navigation_id = $2 AND r.suiveur_id = u.id)
		AND ($3::text[] IS NULL OR ac.contact_id IS NULL OR ac.contact_id::text = ANY($3::text[]))`, n.navigateur, n.id, n.alertees)
	if err != nil {
		return err
	}
	dests, err := pgx.CollectRows(lignes, pgx.RowTo[string])
	if err != nil {
		return err
	}
	dests = sansDoublon(dests)
	var nom, email, l, bateau string
	if err := a.b.pool.QueryRow(ctx, "SELECT u.nom, u.email, u.langue, b.nom FROM utilisateurs u, bateaux b WHERE u.id = $1 AND b.id = $2",
		n.navigateur, n.bateau).Scan(&nom, &email, &l, &bateau); err != nil {
		return err
	}
	sujet := enLangue(l, "NautiLink : "+nom+" a démarré une navigation", "NautiLink: "+nom+" has started a trip")
	var s strings.Builder
	s.WriteString(enLangue(l, "Bonjour,\n\n"+nom+" a démarré la navigation « "+n.nom+" » avec le bateau "+bateau+", le ",
		"Hello,\n\n"+nom+" has started the trip “"+n.nom+"” on the boat "+bateau+", on ") + heureTexte(n.debutEnr) + ".\n")
	if n.destination != nil && n.destination.Texte != "" {
		s.WriteString(enLangue(l, "Destination : ", "Destination: ") + n.destination.Texte + "\n")
	}
	if a.cfg.AdressePublique != "" {
		s.WriteString("\n" + enLangue(l, "Suivre la navigation : ", "Follow the trip: ") + a.cfg.AdressePublique + "/navigations/" + n.id + "\n")
	}
	s.WriteString(enLangue(l, "\nPour ne plus recevoir ces e-mails, décochez « E-mail au début d'une navigation » dans votre compte NautiLink.\n",
		"\nTo stop receiving these e-mails, untick “E-mail at the start of a trip” in your NautiLink account.\n"))
	s.WriteString("\nNautiLink — " + enLangue(l, "Version bêta", "Beta version") + "\n")
	for _, x := range dests {
		a.courriel(x, sujet, s.String())
	}
	if email != "" {
		liste := strings.Join(dests, ", ")
		if liste == "" {
			liste = enLangue(l, "aucun suiveur", "no follower")
		}
		a.courriel(email, enLangue(l, "Copie — ", "Copy — ")+sujet,
			enLangue(l, "Copie de l'e-mail de début envoyé à : ", "Copy of the start e-mail sent to: ")+liste+"\n\n"+s.String())
	}
	return nil
}

// ------------------------------------------------------------------ routes

// operationsSos : éléments alerte_sos et statuts_sms de la file d'attente
// du téléphone (POST /v1/synchronisation).
func (a *app) operationsSos() map[string]operation {
	return map[string]operation{
		"alerte_sos": func(ctx context.Context, r *http.Request, s *session, id, _ string, contenu json.RawMessage) (int, any, error) {
			var al alerteSosJSON
			if err := json.Unmarshal(contenu, &al); err != nil {
				return 0, nil, errInvalide("Alerte SOS illisible.")
			}
			return a.envoyerAlerte(ctx, r, s.utilisateur, id, al)
		},
		"statuts_sms": func(ctx context.Context, r *http.Request, s *session, id, _ string, contenu json.RawMessage) (int, any, error) {
			var l []statutSmsJSON
			if err := json.Unmarshal(contenu, &l); err != nil {
				return 0, nil, errInvalide("Statuts des SMS illisibles.")
			}
			return http.StatusNoContent, nil, a.statutsSms(ctx, s.utilisateur, id, l)
		},
	}
}

func (a *app) routesSos(mux *http.ServeMux, v string) {
	mux.HandleFunc("GET "+v+"/alertes-sos", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		q := r.URL.Query()
		l, err := a.alertes(r.Context(), s.utilisateur, q.Get("bateauId"), q.Get("navigationId"))
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, l)
		return nil
	}))
	mux.HandleFunc("PUT "+v+"/alertes-sos/{alerteId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var al alerteSosJSON
		if err := lireJSON(r, &al); err != nil {
			return err
		}
		code, res, err := a.envoyerAlerte(r.Context(), r, s.utilisateur, r.PathValue("alerteId"), al)
		if err != nil {
			return err
		}
		ecrireJSON(w, code, res)
		return nil
	}))
	mux.HandleFunc("PUT "+v+"/alertes-sos/{alerteId}/sms", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var l []statutSmsJSON
		if err := lireJSON(r, &l); err != nil {
			return err
		}
		if err := a.statutsSms(r.Context(), s.utilisateur, r.PathValue("alerteId"), l); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
}
