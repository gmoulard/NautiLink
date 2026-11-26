package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"log"
	"maps"
	"math"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Navigations, positions et journal de bord (TODO-4.5) : RG-NAV-01 à
// RG-NAV-22, RG-JRN-01 à RG-JRN-08, RG-GPS-04, RG-CPT-05, RG-BAT-03,
// RG-PAR-06 à RG-PAR-09. File d'attente et doublons : 08-architecture.md §5
// (RG-COM-05, D-110) : identifiants tirés par le téléphone, envois
// rejouables sans doublon.

type positionJSON struct {
	Latitude         float64   `json:"latitude"`
	Longitude        float64   `json:"longitude"`
	PrecisionMetres  *float64  `json:"precisionMetres,omitempty"`
	HeureAcquisition time.Time `json:"heureAcquisition"`
}

func (p *positionJSON) valider() error {
	if p == nil {
		return nil
	}
	if p.Latitude < -90 || p.Latitude > 90 || p.Longitude < -180 || p.Longitude > 180 ||
		math.IsNaN(p.Latitude) || math.IsNaN(p.Longitude) {
		return errInvalide("Position invalide.")
	}
	if p.HeureAcquisition.IsZero() {
		return errInvalide("Heure d'acquisition de la position manquante.")
	}
	return nil
}

type lieuJSON struct {
	Nom      *string       `json:"nom"`
	Position *positionJSON `json:"position"`
}

type destinationJSON struct {
	Texte    string        `json:"texte,omitempty"`
	Position *positionJSON `json:"position,omitempty"`
}

type fichierJSON struct {
	TypeMedia     string `json:"typeMedia"`
	TailleOctets  *int   `json:"tailleOctets,omitempty"`
	DureeSecondes *int   `json:"dureeSecondes,omitempty"`
	Recu          bool   `json:"recu"`
}

type evenementJSON struct {
	ID               string        `json:"id"`
	Type             string        `json:"type"`
	HeureAcquisition time.Time     `json:"heureAcquisition"`
	NumeroOrdre      *int          `json:"numeroOrdre,omitempty"`
	Position         *positionJSON `json:"position,omitempty"`
	GpsDisponible    *bool         `json:"gpsDisponible,omitempty"`
	Lieu             *string       `json:"lieu"`
	Texte            *string       `json:"texte"`
	Fichier          *fichierJSON  `json:"fichier"`
	Origine          string        `json:"origine,omitempty"`
	Masque           bool          `json:"masque"`
	RecuLe           time.Time     `json:"recuLe"`
	AlerteSosID      *string       `json:"alerteSosId"`
}

// empreinte : contenu envoyé par le téléphone, pour reconnaître un renvoi
// (même contenu : rien de créé) d'un envoi différent sous le même
// identifiant (409 evenement_different).
func (e evenementJSON) empreinte(navigation string) []byte {
	contenu := struct {
		N, T  string
		H     time.Time
		O     *int
		P     *positionJSON
		G     *bool
		X     *string
		F     *fichierJSON
		Or, S string
	}{N: navigation, T: e.Type, H: e.HeureAcquisition.UTC(), O: e.NumeroOrdre, G: e.GpsDisponible, X: e.Texte, Or: e.Origine}
	if e.Position != nil {
		p := *e.Position
		p.HeureAcquisition = p.HeureAcquisition.UTC()
		contenu.P = &p
	}
	if e.Fichier != nil {
		contenu.F = &fichierJSON{TypeMedia: e.Fichier.TypeMedia, TailleOctets: e.Fichier.TailleOctets, DureeSecondes: e.Fichier.DureeSecondes}
	}
	if e.AlerteSosID != nil {
		contenu.S = *e.AlerteSosID
	}
	b, _ := json.Marshal(contenu)
	h := sha256.Sum256(b)
	return h[:]
}

const (
	tailleFichierMax = 5 << 20 // photo d'environ 1 Mo (RG-JRN-08), note vocale d'une minute (RG-JRN-04)
	photosMax        = 20      // RG-JRN-08
	dureeVocaleMax   = 60      // secondes, RG-JRN-04
)

// validerEvenement : type permis, heure, position, fichier annoncé.
func validerEvenement(e *evenementJSON, types ...string) error {
	if !estUUID(e.ID) {
		return errInvalide("Identifiant d'événement invalide.")
	}
	if !slices.Contains(types, e.Type) {
		return errInvalide("Type d'événement invalide ici : " + strings.Join(types, ", ") + ".")
	}
	if e.HeureAcquisition.IsZero() {
		return errInvalide("Heure d'acquisition manquante.")
	}
	if err := e.Position.valider(); err != nil {
		return err
	}
	if e.Origine != "" && e.Origine != "android" && e.Origine != "ios" && e.Origine != "web" {
		return errInvalide("Origine invalide : android, ios ou web.")
	}
	e.Texte = texteOuNul(e.Texte)
	switch e.Type {
	case "photo":
		if e.Fichier == nil || e.Fichier.TypeMedia != "image/jpeg" {
			return errInvalide("Une photo est un fichier image/jpeg.")
		}
	case "note_vocale":
		if e.Fichier == nil || e.Fichier.TypeMedia != "audio/mp4" {
			return errInvalide("Une note vocale est un fichier audio/mp4.")
		}
	case "ajout":
		if e.Fichier != nil && e.Fichier.TypeMedia != "image/jpeg" && e.Fichier.TypeMedia != "audio/mp4" {
			return errInvalide("Fichier image/jpeg ou audio/mp4.")
		}
	default:
		e.Fichier = nil
	}
	if e.Fichier != nil && e.Fichier.TypeMedia == "audio/mp4" && e.Fichier.DureeSecondes != nil && *e.Fichier.DureeSecondes > dureeVocaleMax {
		return &erreurAPI{http.StatusUnprocessableEntity, "note_vocale_trop_longue", "Une note vocale dure 1 minute au plus.", 0}
	}
	return nil
}

func estPhoto(e evenementJSON) bool {
	return e.Fichier != nil && e.Fichier.TypeMedia == "image/jpeg"
}

// ------------------------------------------------------------------ navigation en base

type navLigne struct {
	id, navigateur, bateau, appareil, nom string
	destination                           *destinationJSON
	frequence, personnes, version         int
	parametres                            []byte
	alertees                              []string
	debutEnr                              time.Time
	finEnr                                *time.Time
	debut                                 time.Time
	fin                                   *time.Time
	meteoDepart, meteoArrivee             []byte
	epuise, cloture, supprimee            *time.Time
	empreinte                             []byte
	decalage                              *int
}

const colonnesNav = `id, navigateur_id, bateau_id, appareil_id, nom, destination, frequence_minutes, parametres,
	personnes_a_bord, personnes_alertees::text[], debut_enregistre, fin_enregistree, debut, fin, meteo_depart, meteo_arrivee,
	epuise_le, cloture_automatique_le, supprimee_le, empreinte, version, decalage_minutes`

func lireNav(l pgx.Row) (navLigne, error) {
	var n navLigne
	err := l.Scan(&n.id, &n.navigateur, &n.bateau, &n.appareil, &n.nom, &n.destination, &n.frequence, &n.parametres,
		&n.personnes, &n.alertees, &n.debutEnr, &n.finEnr, &n.debut, &n.fin, &n.meteoDepart, &n.meteoArrivee,
		&n.epuise, &n.cloture, &n.supprimee, &n.empreinte, &n.version, &n.decalage)
	return n, err
}

func (n navLigne) enCours() bool { return n.finEnr == nil }

// masque : événement hors de la plage affichée, après un changement
// d'heures (RG-NAV-22) ; il est gardé mais masqué du tracé.
func (n navLigne) masque(heure time.Time) bool {
	return heure.Before(n.debut) || (n.fin != nil && heure.After(*n.fin))
}

// lecteur : pool ou transaction.
type lecteur interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func (a *app) navigation(ctx context.Context, q lecteur, id string) (navLigne, error) {
	if !estUUID(id) {
		return navLigne{}, errIntrouvable()
	}
	return lireNav(q.QueryRow(ctx, "SELECT "+colonnesNav+" FROM navigations WHERE id = $1", id))
}

// conditionSuiveur : la navigation n (alias) est visible du suiveur $1 :
// accès de périmètre navigateur, ou de périmètre navigation sur elle
// (RG-PAR-02), sans retrait de cette navigation (RG-PAR-06), hors corbeille
// (RG-NAV-20). Périmètre navigateur : toutes ses navigations, y compris
// celles terminées avant l'accès (RG-PAR-09, D-111).
const conditionSuiveur = `n.supprimee_le IS NULL AND n.navigateur_id <> $1
	AND EXISTS (SELECT 1 FROM acces ac WHERE ac.suiveur_id = $1 AND ac.navigateur_id = n.navigateur_id
		AND (ac.perimetre = 'navigateur' OR ac.navigation_id = n.id))
	AND NOT EXISTS (SELECT 1 FROM retraits_navigation r WHERE r.navigation_id = n.id AND r.suiveur_id = $1)`

// navigationVue : la navigation et le rôle de l'utilisateur ; introuvable
// sans accès (le serveur ne distingue pas les deux).
func (a *app) navigationVue(ctx context.Context, utilisateur, id string) (navLigne, string, error) {
	n, err := a.navigation(ctx, a.b.pool, id)
	if err != nil {
		return n, "", err
	}
	if n.navigateur == utilisateur {
		return n, "navigateur", nil
	}
	var ok bool
	if err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM navigations n WHERE n.id = $2 AND "+conditionSuiveur+")",
		utilisateur, id).Scan(&ok); err != nil {
		return n, "", err
	}
	if !ok {
		return n, "", errIntrouvable()
	}
	return n, "suiveur", nil
}

// navigationDuNavigateur : modifications réservées au navigateur ; un
// suiveur est en lecture seule (RG-PAR-07, RG-PAR-08).
func (a *app) navigationDuNavigateur(ctx context.Context, utilisateur, id string) (navLigne, error) {
	n, role, err := a.navigationVue(ctx, utilisateur, id)
	if err == nil && role != "navigateur" {
		err = errInterdit("interdit", "Seul le navigateur modifie sa navigation.")
	}
	return n, err
}

// perimetreValide : périmètre d'un accès ; pour le périmètre navigation, la
// navigation doit être une navigation du navigateur (RG-PAR-02).
func (a *app) perimetreValide(ctx context.Context, navigateur string, perimetre, navigation *string) error {
	if err := validerPerimetre(perimetre, navigation); err != nil {
		return err
	}
	if *perimetre != "navigation" {
		return nil
	}
	var ok bool
	if err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM navigations WHERE id = $1 AND navigateur_id = $2)",
		*navigation, navigateur).Scan(&ok); err != nil {
		return err
	}
	if !ok {
		return errInvalide("Cette navigation n'est pas l'une des vôtres.")
	}
	return nil
}

// ------------------------------------------------------------------ présentation

type resumeBateau struct {
	ID  string `json:"id"`
	Nom string `json:"nom"`
}

type navigationJSON struct {
	ID                        string           `json:"id"`
	Nom                       string           `json:"nom"`
	Role                      string           `json:"role"`
	Etat                      string           `json:"etat"`
	Bateau                    resumeBateau     `json:"bateau"`
	Debut                     time.Time        `json:"debut"`
	Fin                       *time.Time       `json:"fin"`
	LieuDepart                *lieuJSON        `json:"lieuDepart"`
	LieuArrivee               *lieuJSON        `json:"lieuArrivee"`
	DureeMinutes              int              `json:"dureeMinutes"`
	DistanceMetres            float64          `json:"distanceMetres"`
	DernierePosition          *lieuJSON        `json:"dernierePosition"`
	SupprimeeDefinitivementLe *time.Time       `json:"supprimeeDefinitivementLe,omitempty"`
	Version                   int              `json:"version,omitempty"`
	Navigateur                *personneJSON    `json:"navigateur,omitempty"`
	Destination               *destinationJSON `json:"destination,omitempty"`
	DebutEnregistre           *time.Time       `json:"debutEnregistre,omitempty"`
	FinEnregistree            *time.Time       `json:"finEnregistree,omitempty"`
	FrequenceMinutes          int              `json:"frequenceMinutes,omitempty"`
	PersonnesABord            int              `json:"personnesABord,omitempty"`
	MeteoDepart               json.RawMessage  `json:"meteoDepart,omitempty"`
	MeteoArrivee              json.RawMessage  `json:"meteoArrivee,omitempty"`
	ClotureAutomatiqueLe      *time.Time       `json:"clotureAutomatiqueLe,omitempty"`
	Fiche                     *bateauJSON      `json:"fiche,omitempty"`
	Suiveurs                  []personneJSON   `json:"suiveurs,omitempty"`
	ContactsSos               []personneJSON   `json:"contactsSos,omitempty"`
	AdressePage               string           `json:"adressePage,omitempty"`
	decalage                  *int             // fuseau du téléphone au début (RG-PRM-07), pour l'affichage Web
}

const dureeCorbeille = 30 * 24 * time.Hour // RG-NAV-20

// distance : formule de haversine, en mètres.
func distance(p, q positionJSON) float64 {
	const r = 6_371_000.0
	rad := math.Pi / 180
	dLat := (q.Latitude - p.Latitude) * rad
	dLon := (q.Longitude - p.Longitude) * rad
	h := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Cos(p.Latitude*rad)*math.Cos(q.Latitude*rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 2 * r * math.Asin(math.Sqrt(h))
}

// resumer : résumé d'une navigation (RG-NAV-16) : lieux de départ et
// d'arrivée (première et dernière position non masquées), durée, distance
// (somme des distances entre positions successives, D-35).
func (a *app) resumer(ctx context.Context, n navLigne, role string) (navigationJSON, error) {
	r := navigationJSON{ID: n.id, Nom: n.nom, Role: role, Debut: n.debut, Fin: n.fin, decalage: n.decalage}
	switch {
	case n.supprimee != nil:
		r.Etat = "corbeille"
		fin := n.supprimee.Add(dureeCorbeille)
		r.SupprimeeDefinitivementLe = &fin
	case n.enCours():
		r.Etat = "en_cours"
	default:
		r.Etat = "terminee"
	}
	r.Bateau.ID = n.bateau
	if err := a.b.pool.QueryRow(ctx, "SELECT nom FROM bateaux WHERE id = $1", n.bateau).Scan(&r.Bateau.Nom); err != nil {
		return r, err
	}
	fin := a.maintenant()
	if n.fin != nil {
		fin = *n.fin
	}
	r.DureeMinutes = max(0, int(fin.Sub(n.debut).Minutes()))
	lignes, err := a.b.pool.Query(ctx, `SELECT heure_acquisition, latitude, longitude, precision_metres, heure_position, lieu
		FROM evenements WHERE navigation_id = $1 AND latitude IS NOT NULL AND supprime_le IS NULL
		ORDER BY heure_acquisition, numero_ordre NULLS LAST`, n.id)
	if err != nil {
		return r, err
	}
	var precedente *lieuJSON
	for lignes.Next() {
		var heure time.Time
		var hp *time.Time
		l := &lieuJSON{Position: &positionJSON{}}
		if err := lignes.Scan(&heure, &l.Position.Latitude, &l.Position.Longitude, &l.Position.PrecisionMetres, &hp, &l.Nom); err != nil {
			lignes.Close()
			return r, err
		}
		if n.masque(heure) {
			continue
		}
		l.Position.HeureAcquisition = heure
		if hp != nil {
			l.Position.HeureAcquisition = *hp
		}
		if precedente == nil {
			r.LieuDepart = l
		} else {
			r.DistanceMetres += distance(*precedente.Position, *l.Position)
		}
		precedente = l
	}
	lignes.Close()
	if err := lignes.Err(); err != nil {
		return r, err
	}
	r.DistanceMetres = math.Round(r.DistanceMetres)
	r.DernierePosition = precedente
	if !n.enCours() {
		r.LieuArrivee = precedente
	}
	return r, nil
}

// detailler : page d'une navigation : fiche du bateau, suiveurs et contacts
// SOS du navigateur (RG-PAR-08).
func (a *app) detailler(ctx context.Context, n navLigne, role string) (navigationJSON, error) {
	r, err := a.resumer(ctx, n, role)
	if err != nil {
		return r, err
	}
	r.Version = n.version
	r.Destination = n.destination
	r.DebutEnregistre = &n.debutEnr
	r.FinEnregistree = n.finEnr
	r.FrequenceMinutes = n.frequence
	r.PersonnesABord = n.personnes
	r.MeteoDepart, r.MeteoArrivee = n.meteoDepart, n.meteoArrivee // RG-NAV-28 : Météo-France, Q-39
	r.ClotureAutomatiqueLe = n.cloture
	var p personneJSON
	if err := a.b.pool.QueryRow(ctx, "SELECT id, nom, telephone, email FROM utilisateurs WHERE id = $1", n.navigateur).
		Scan(&p.ID, &p.Nom, &p.Telephone, &p.Email); err != nil {
		return r, err
	}
	r.Navigateur = &p
	b, err := lireBateau(a.b.pool.QueryRow(ctx, "SELECT "+colonnesBateau+" FROM bateaux WHERE id = $1", n.bateau))
	if err != nil {
		return r, err
	}
	r.Fiche = &b
	if r.Suiveurs, err = a.suiveursDe(ctx, n); err != nil {
		return r, err
	}
	lignes, err := a.b.pool.Query(ctx, `SELECT id, nom, telephone, email FROM contacts
		WHERE navigateur_id = $1 AND contact_sos AND supprime_le IS NULL ORDER BY nom`, n.navigateur)
	if err != nil {
		return r, err
	}
	r.ContactsSos, err = pgx.CollectRows(lignes, func(l pgx.CollectableRow) (personneJSON, error) {
		var p personneJSON
		err := l.Scan(&p.ID, &p.Nom, &p.Telephone, &p.Email)
		return p, err
	})
	return r, err
}

// suiveursDe : comptes ayant accès à la navigation (RG-PAR-02, RG-PAR-06).
func (a *app) suiveursDe(ctx context.Context, n navLigne) ([]personneJSON, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT DISTINCT u.id, u.nom, u.telephone, u.email FROM acces ac
		JOIN utilisateurs u ON u.id = ac.suiveur_id
		WHERE ac.navigateur_id = $1 AND (ac.perimetre = 'navigateur' OR ac.navigation_id = $2)
		AND NOT EXISTS (SELECT 1 FROM retraits_navigation r WHERE r.navigation_id = $2 AND r.suiveur_id = u.id)
		ORDER BY u.nom, u.id`, n.navigateur, n.id)
	if err != nil {
		return nil, err
	}
	l, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (personneJSON, error) {
		var p personneJSON
		err := l.Scan(&p.ID, &p.Nom, &p.Telephone, &p.Email)
		return p, err
	})
	if l == nil {
		l = []personneJSON{}
	}
	return l, err
}

// ------------------------------------------------------------------ démarrage

type demarrageJSON struct {
	BateauID          string           `json:"bateauId"`
	AppareilID        string           `json:"appareilId"`
	Destination       *destinationJSON `json:"destination"`
	FrequenceMinutes  int              `json:"frequenceMinutes"`
	Parametres        json.RawMessage  `json:"parametres"`
	PersonnesABord    int              `json:"personnesABord"`
	PersonnesAlertees *[]string        `json:"personnesAlertees"`
	Debut             evenementJSON    `json:"debut"`
}

func (d *demarrageJSON) empreinte() []byte {
	var p bytes.Buffer
	if len(d.Parametres) > 0 {
		_ = json.Compact(&p, d.Parametres)
	}
	b, _ := json.Marshal([]any{d.BateauID, d.AppareilID, d.Destination, d.FrequenceMinutes, p.String(),
		d.PersonnesABord, d.PersonnesAlertees, d.Debut.empreinte("")})
	h := sha256.Sum256(b)
	return h[:]
}

// errVerificationEmail : un compte dont l'adresse n'est pas vérifiée ne
// démarre pas de navigation (RG-CPT-09, D-105) ; le SOS, lui, n'est jamais
// bloqué (RG-SOS-03).
var errVerificationEmail = &erreurAPI{http.StatusForbidden, "email_non_verifie",
	"Vérifiez d'abord votre adresse e-mail : ouvrez le lien que NautiLink vous a envoyé, puis démarrez la navigation.", 0}

// demarrer : PUT /v1/navigations/{id} (RG-NAV-01 à RG-NAV-08, RG-CPT-05).
// Rend le code (201 créée, 200 déjà reçue) et la navigation.
func (a *app) demarrer(ctx context.Context, utilisateur, id string, d demarrageJSON) (int, navigationJSON, error) {
	if !estUUID(id) {
		return 0, navigationJSON{}, errInvalide("Identifiant de navigation invalide.")
	}
	if d.Debut.Type == "" {
		d.Debut.Type = "debut"
	}
	if err := validerEvenement(&d.Debut, "debut"); err != nil {
		return 0, navigationJSON{}, err
	}
	if !slices.Contains(frequences, d.FrequenceMinutes) {
		return 0, navigationJSON{}, errInvalide("Fréquence invalide : 15, 30, 60, 120, 180, 360, 720, 1440, 2880 ou 14400 minutes.")
	}
	if d.PersonnesABord < 1 {
		return 0, navigationJSON{}, errInvalide("Indiquez le nombre de personnes à bord (au moins 1).")
	}
	if d.PersonnesAlertees != nil {
		for _, c := range *d.PersonnesAlertees {
			if !estUUID(c) {
				return 0, navigationJSON{}, errInvalide("Personne alertée invalide.")
			}
		}
	}
	if d.Destination != nil {
		d.Destination.Texte = strings.TrimSpace(d.Destination.Texte)
		if err := d.Destination.Position.valider(); err != nil {
			return 0, navigationJSON{}, err
		}
		if d.Destination.Texte == "" && d.Destination.Position == nil {
			d.Destination = nil
		}
	}
	emp := d.empreinte()
	// Renvoi : même identifiant, même contenu → 200 sans rien créer.
	if n, err := a.navigation(ctx, a.b.pool, id); err == nil {
		if n.navigateur != utilisateur || !bytes.Equal(n.empreinte, emp) {
			return 0, navigationJSON{}, errEvenementDifferent()
		}
		r, err := a.detailler(ctx, n, "navigateur")
		return http.StatusOK, r, err
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return 0, navigationJSON{}, err
	}
	if ok, err := a.peutDemarrer(ctx, utilisateur, d.BateauID); err != nil {
		return 0, navigationJSON{}, err
	} else if !ok {
		return 0, navigationJSON{}, errInterdit("pas_proprietaire", "Seul le propriétaire du bateau peut démarrer une navigation avec ce bateau.")
	}
	var verifie bool
	if err := a.b.pool.QueryRow(ctx, "SELECT email_verifie_le IS NOT NULL FROM utilisateurs WHERE id = $1", utilisateur).Scan(&verifie); err != nil {
		return 0, navigationJSON{}, err
	}
	if !verifie {
		return 0, navigationJSON{}, errVerificationEmail
	}
	var nomBateau string
	var associe *string
	if err := a.b.pool.QueryRow(ctx, "SELECT nom, appareil_associe_id FROM bateaux WHERE id = $1", d.BateauID).Scan(&nomBateau, &associe); err != nil {
		return 0, navigationJSON{}, err
	}
	if associe == nil || !strings.EqualFold(*associe, d.AppareilID) {
		return 0, navigationJSON{}, errInterdit("telephone_non_associe", "Ce téléphone n'est pas associé à ce bateau.")
	}
	if err := a.verifierQuotaAuDemarrage(ctx, utilisateur); err != nil {
		return 0, navigationJSON{}, err
	}
	// Nom généré (RG-NAV-17, D-15), date dans le fuseau du téléphone.
	nom := nomBateau + " — " + d.Debut.HeureAcquisition.Format("2006-01-02 15:04")
	if d.Destination != nil && d.Destination.Texte != "" {
		nom = nomBateau + " — " + d.Destination.Texte
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return 0, navigationJSON{}, err
	}
	defer tx.Rollback(ctx)
	_, err = tx.Exec(ctx, `INSERT INTO navigations (id, navigateur_id, bateau_id, appareil_id, nom, destination, frequence_minutes,
		parametres, personnes_a_bord, personnes_alertees, debut_enregistre, debut, empreinte, decalage_minutes)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11, $12, $13)`,
		id, utilisateur, d.BateauID, d.AppareilID, nom, d.Destination, d.FrequenceMinutes, jsonOuNul(d.Parametres),
		d.PersonnesABord, d.PersonnesAlertees, d.Debut.HeureAcquisition, emp, decalageHoraire(d.Debut.HeureAcquisition))
	if estDoublon(err) {
		return 0, navigationJSON{}, &erreurAPI{http.StatusConflict, "navigation_en_cours",
			"Une navigation est déjà en cours sur ce bateau ou sur ce téléphone.", 0}
	}
	if err != nil {
		return 0, navigationJSON{}, err
	}
	if err := insererEvenement(ctx, tx, id, d.Debut); err != nil {
		return 0, navigationJSON{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, navigationJSON{}, err
	}
	n, err := a.navigation(ctx, a.b.pool, id)
	if err != nil {
		return 0, navigationJSON{}, err
	}
	a.apresDemarrage(ctx, n)
	r, err := a.detailler(ctx, n, "navigateur")
	return http.StatusCreated, r, err
}

func jsonOuNul(b json.RawMessage) any {
	if len(b) == 0 || string(b) == "null" {
		return nil
	}
	return []byte(b)
}

func errEvenementDifferent() error {
	return &erreurAPI{http.StatusConflict, "evenement_different", "Cet identifiant a déjà servi pour un envoi différent.", 0}
}

func errCloturee() error {
	return &erreurAPI{http.StatusConflict, "navigation_cloturee",
		"Cette navigation a été clôturée automatiquement : le quota gratuit est épuisé depuis plus de 24 heures.", 0}
}

func insererEvenement(ctx context.Context, tx pgx.Tx, navigation string, e evenementJSON) error {
	var lat, lon, prec *float64
	var hp *time.Time
	if e.Position != nil {
		lat, lon, prec, hp = &e.Position.Latitude, &e.Position.Longitude, e.Position.PrecisionMetres, &e.Position.HeureAcquisition
	}
	var ft *string
	var taille, duree *int
	if e.Fichier != nil {
		ft, taille, duree = &e.Fichier.TypeMedia, e.Fichier.TailleOctets, e.Fichier.DureeSecondes
	}
	_, err := tx.Exec(ctx, `INSERT INTO evenements (id, navigation_id, type, heure_acquisition, numero_ordre, latitude, longitude,
		precision_metres, heure_position, gps_disponible, texte, fichier_type, fichier_taille, fichier_duree, origine, alerte_sos_id, empreinte)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, nullif($15, ''), $16, $17)`,
		e.ID, navigation, e.Type, e.HeureAcquisition, e.NumeroOrdre, lat, lon, prec, hp, e.GpsDisponible, e.Texte,
		ft, taille, duree, e.Origine, e.AlerteSosID, e.empreinte(navigation))
	if estDoublon(err) {
		return errEvenementDifferent()
	}
	return err
}

// ------------------------------------------------------------------ fin

// terminer : PUT /v1/navigations/{id}/fin (RG-NAV-13, RG-NAV-14) : fin
// avec son heure réelle, même arrivée tard ; rejouable.
func (a *app) terminer(ctx context.Context, utilisateur, id string, e evenementJSON) (navigationJSON, error) {
	if e.Type == "" {
		e.Type = "fin"
	}
	if err := validerEvenement(&e, "fin"); err != nil {
		return navigationJSON{}, err
	}
	n, err := a.navigationDuNavigateur(ctx, utilisateur, id)
	if err != nil {
		return navigationJSON{}, err
	}
	if !n.enCours() {
		var emp []byte
		err := a.b.pool.QueryRow(ctx, "SELECT empreinte FROM evenements WHERE id = $1 AND navigation_id = $2", e.ID, id).Scan(&emp)
		switch {
		case err == nil && bytes.Equal(emp, e.empreinte(id)):
			return a.detailler(ctx, n, "navigateur") // renvoi
		case err == nil:
			return navigationJSON{}, errEvenementDifferent()
		case !errors.Is(err, pgx.ErrNoRows):
			return navigationJSON{}, err
		case n.cloture == nil:
			return navigationJSON{}, &erreurAPI{http.StatusConflict, "evenement_different", "Cette navigation est déjà terminée.", 0}
		case e.HeureAcquisition.After(*n.cloture):
			return navigationJSON{}, errCloturee() // RG-ECO-12
		}
		// Fin acquise avant la clôture automatique, reçue après : gardée
		// (RG-ECO-12) ; la navigation finit à son heure réelle.
	}
	if e.HeureAcquisition.Before(n.debutEnr) {
		return navigationJSON{}, errInvalide("La fin ne peut pas précéder le début.")
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return navigationJSON{}, err
	}
	defer tx.Rollback(ctx)
	if err := insererEvenement(ctx, tx, id, e); err != nil {
		return navigationJSON{}, err
	}
	if _, err := tx.Exec(ctx, `UPDATE navigations SET fin_enregistree = $2, fin = CASE WHEN fin IS NULL OR fin = fin_enregistree
		THEN $2 ELSE fin END, epuise_le = NULL, cloture_automatique_le = NULL, version = version + 1, modifiee_le = now()
		WHERE id = $1`, id, e.HeureAcquisition); err != nil {
		return navigationJSON{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return navigationJSON{}, err
	}
	a.notifierNavigation(ctx, id, "fin", e.HeureAcquisition) // RG-IOS-06
	if n, err = a.navigation(ctx, a.b.pool, id); err != nil {
		return navigationJSON{}, err
	}
	return a.detailler(ctx, n, "navigateur")
}

// ------------------------------------------------------------------ journal

const colonnesEvenement = `id, type, heure_acquisition, numero_ordre, latitude, longitude, precision_metres, heure_position,
	gps_disponible, lieu, texte, fichier_type, fichier_taille, fichier_duree,
	EXISTS (SELECT 1 FROM fichiers f WHERE f.evenement_id = e.id), coalesce(origine, ''), recu_le, alerte_sos_id::text`

func lireEvenement(l pgx.Row, n navLigne) (evenementJSON, error) {
	var e evenementJSON
	var lat, lon, prec *float64
	var hp *time.Time
	var ft *string
	var taille, duree *int
	var recu bool
	err := l.Scan(&e.ID, &e.Type, &e.HeureAcquisition, &e.NumeroOrdre, &lat, &lon, &prec, &hp, &e.GpsDisponible, &e.Lieu,
		&e.Texte, &ft, &taille, &duree, &recu, &e.Origine, &e.RecuLe, &e.AlerteSosID)
	if lat != nil && lon != nil {
		e.Position = &positionJSON{Latitude: *lat, Longitude: *lon, PrecisionMetres: prec, HeureAcquisition: e.HeureAcquisition}
		if hp != nil {
			e.Position.HeureAcquisition = *hp
		}
	}
	if ft != nil {
		e.Fichier = &fichierJSON{TypeMedia: *ft, TailleOctets: taille, DureeSecondes: duree, Recu: recu}
	}
	// Un SOS n'est jamais masqué du journal, même hors de la plage affichée
	// ou déclenché après la fin (RG-SOS-19, D-120).
	e.Masque = e.Type != "sos" && n.masque(e.HeureAcquisition)
	return e, err
}

// journalDeBord : événements dans l'ordre de l'heure d'acquisition (RG-JRN-03) ;
// depuis : seulement ce qui a été reçu, modifié ou supprimé après ce curseur.
func (a *app) journalDeBord(ctx context.Context, n navLigne, depuis int64) (evts []evenementJSON, supprimes []string, curseur int64, err error) {
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesEvenement+` FROM evenements e
		WHERE navigation_id = $1 AND modification > $2 AND supprime_le IS NULL
		ORDER BY heure_acquisition, numero_ordre NULLS LAST, recu_le`, n.id, depuis)
	if err != nil {
		return
	}
	if evts, err = pgx.CollectRows(lignes, func(l pgx.CollectableRow) (evenementJSON, error) { return lireEvenement(l, n) }); err != nil {
		return
	}
	if evts == nil {
		evts = []evenementJSON{}
	}
	supprimes = []string{}
	if depuis > 0 {
		lignes, err = a.b.pool.Query(ctx, `SELECT id::text FROM evenements WHERE navigation_id = $1 AND modification > $2
			AND supprime_le IS NOT NULL`, n.id, depuis)
		if err != nil {
			return
		}
		if supprimes, err = pgx.CollectRows(lignes, pgx.RowTo[string]); err != nil {
			return
		}
	}
	err = a.b.pool.QueryRow(ctx, "SELECT coalesce(max(modification), 0) FROM evenements WHERE navigation_id = $1", n.id).Scan(&curseur)
	return
}

// envoyerEvenement : PUT /v1/navigations/{id}/evenements/{evenementId} ;
// idempotent (08-architecture.md §5). Rend 201 (enregistré) ou 200 (déjà reçu).
func (a *app) envoyerEvenement(ctx context.Context, utilisateur, navID string, e evenementJSON) (int, evenementJSON, error) {
	if err := validerEvenement(&e, "position_automatique", "position_manuelle", "note", "photo", "note_vocale", "ajout"); err != nil {
		return 0, e, err
	}
	n, err := a.navigationDuNavigateur(ctx, utilisateur, navID)
	if err != nil {
		return 0, e, err
	}
	var emp []byte
	var nav string
	err = a.b.pool.QueryRow(ctx, "SELECT empreinte, navigation_id FROM evenements WHERE id = $1", e.ID).Scan(&emp, &nav)
	if err == nil {
		if nav != navID || !bytes.Equal(emp, e.empreinte(navID)) {
			return 0, e, errEvenementDifferent()
		}
		r, err := lireEvenement(a.b.pool.QueryRow(ctx, "SELECT "+colonnesEvenement+" FROM evenements e WHERE id = $1", e.ID), n)
		return http.StatusOK, r, err
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return 0, e, err
	}
	if e.Type == "ajout" && n.enCours() {
		return 0, e, &erreurAPI{http.StatusConflict, "navigation_en_cours", "Les ajouts se font une fois la navigation terminée.", 0}
	}
	if e.Type != "ajout" && n.cloture != nil && e.HeureAcquisition.After(*n.cloture) {
		return 0, e, errCloturee() // RG-ECO-12
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return 0, e, err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, "SELECT 1 FROM navigations WHERE id = $1 FOR UPDATE", navID); err != nil {
		return 0, e, err
	}
	if estPhoto(e) {
		var nb int
		if err := tx.QueryRow(ctx, `SELECT count(*) FROM evenements WHERE navigation_id = $1 AND fichier_type = 'image/jpeg'
			AND supprime_le IS NULL`, navID).Scan(&nb); err != nil {
			return 0, e, err
		}
		if nb >= photosMax {
			return 0, e, &erreurAPI{http.StatusConflict, "limite_photos", "Une navigation compte au plus 20 photos.", 0}
		}
	}
	if err := insererEvenement(ctx, tx, navID, e); err != nil {
		return 0, e, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, e, err
	}
	if estPhoto(e) {
		a.notifierNavigation(ctx, navID, "photo", e.HeureAcquisition) // RG-IOS-06
	}
	r, err := lireEvenement(a.b.pool.QueryRow(ctx, "SELECT "+colonnesEvenement+" FROM evenements e WHERE id = $1", e.ID), n)
	return http.StatusCreated, r, err
}

// evenementModifiable : notes, photos, notes vocales et ajouts, quelle que
// soit leur origine (RG-JRN-06) ; jamais début, fin, positions ni SOS (RG-JRN-07).
func (a *app) evenementModifiable(ctx context.Context, utilisateur, navID, id string) (navLigne, error) {
	n, err := a.navigationModifiable(ctx, utilisateur, navID)
	if err != nil {
		return n, err
	}
	if !estUUID(id) {
		return n, errIntrouvable()
	}
	var typ string
	if err := a.b.pool.QueryRow(ctx, "SELECT type FROM evenements WHERE id = $1 AND navigation_id = $2 AND supprime_le IS NULL",
		id, navID).Scan(&typ); err != nil {
		return n, err
	}
	if !slices.Contains([]string{"note", "photo", "note_vocale", "ajout"}, typ) {
		return n, errInterdit("evenement_non_modifiable", "Le début, la fin, les positions et les alertes SOS ne se modifient pas.")
	}
	return n, nil
}

// ------------------------------------------------------------------ liste

// navigations : GET /v1/navigations : en cours d'abord, puis de la plus
// récente à la plus ancienne ; comme navigateur et comme suiveur.
func (a *app) navigations(ctx context.Context, utilisateur, role, etat, bateau string, decalage int) ([]navigationJSON, int, error) {
	const parPage = 50
	conditions := []string{}
	switch role {
	case "navigateur":
		conditions = append(conditions, "n.navigateur_id = $1 AND n.supprimee_le IS NULL")
	case "suiveur":
		conditions = append(conditions, conditionSuiveur)
	default:
		conditions = append(conditions, "((n.navigateur_id = $1 AND n.supprimee_le IS NULL) OR ("+conditionSuiveur+"))")
	}
	switch etat {
	case "en_cours":
		conditions = append(conditions, "n.fin_enregistree IS NULL")
	case "terminee":
		conditions = append(conditions, "n.fin_enregistree IS NOT NULL")
	}
	args := []any{utilisateur}
	if bateau != "" {
		if !estUUID(bateau) {
			return nil, 0, errInvalide("Bateau invalide.")
		}
		args = append(args, bateau)
		conditions = append(conditions, "n.bateau_id = $2")
	}
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesNav+" FROM navigations n WHERE "+strings.Join(conditions, " AND ")+
		" ORDER BY n.fin_enregistree IS NULL DESC, n.debut DESC, n.id LIMIT "+strconv.Itoa(parPage+1)+
		" OFFSET "+strconv.Itoa(decalage), args...)
	if err != nil {
		return nil, 0, err
	}
	navs, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (navLigne, error) { return lireNav(l) })
	if err != nil {
		return nil, 0, err
	}
	suivant := 0
	if len(navs) > parPage {
		navs, suivant = navs[:parPage], decalage+parPage
	}
	liste := []navigationJSON{}
	for _, n := range navs {
		r := "suiveur"
		if n.navigateur == utilisateur {
			r = "navigateur"
		}
		s, err := a.resumer(ctx, n, r)
		if err != nil {
			return nil, 0, err
		}
		liste = append(liste, s)
	}
	return liste, suivant, nil
}

// modifierNavigation : PATCH (RG-NAV-17, RG-NAV-22) : nom à tout moment ;
// destination, bateau (parmi les siens) et heures une fois la navigation
// terminée. Le quota reste calculé sur les heures enregistrées (RG-ECO-02).
func (a *app) modifierNavigation(ctx context.Context, utilisateur, id string, c champs) (navigationJSON, error) {
	n, err := a.navigationModifiable(ctx, utilisateur, id)
	if err != nil {
		return navigationJSON{}, err
	}
	if n.enCours() && (c.a("destination") || c.a("bateauId") || c.a("debut") || c.a("fin")) {
		return navigationJSON{}, &erreurAPI{http.StatusConflict, "navigation_en_cours",
			"La destination, le bateau et les heures se modifient une fois la navigation terminée.", 0}
	}
	if c.a("nom") {
		var nom string
		if err := c.lire("nom", &nom); err != nil {
			return navigationJSON{}, err
		}
		if nom = strings.TrimSpace(nom); nom == "" {
			return navigationJSON{}, errInvalide("Le nom ne peut pas être vide.")
		}
		n.nom = nom
	}
	if c.a("destination") {
		if err := c.lire("destination", &n.destination); err != nil {
			return navigationJSON{}, err
		}
		if n.destination != nil {
			n.destination.Texte = strings.TrimSpace(n.destination.Texte)
			if err := n.destination.Position.valider(); err != nil {
				return navigationJSON{}, err
			}
		}
	}
	if c.a("bateauId") {
		if err := c.lire("bateauId", &n.bateau); err != nil {
			return navigationJSON{}, err
		}
		if ok, err := a.peutDemarrer(ctx, utilisateur, n.bateau); err != nil {
			return navigationJSON{}, err
		} else if !ok {
			return navigationJSON{}, errInterdit("pas_proprietaire", "Choisissez l'un de vos bateaux.")
		}
	}
	if c.a("debut") {
		if err := c.lire("debut", &n.debut); err != nil {
			return navigationJSON{}, err
		}
	}
	if c.a("fin") {
		if err := c.lire("fin", &n.fin); err != nil || n.fin == nil {
			return navigationJSON{}, errInvalide("Heure de fin invalide.")
		}
	}
	if n.fin != nil && n.fin.Before(n.debut) {
		return navigationJSON{}, errInvalide("La fin ne peut pas précéder le début.")
	}
	if _, err := a.b.pool.Exec(ctx, `UPDATE navigations SET nom = $2, destination = $3, bateau_id = $4, debut = $5, fin = $6,
		version = version + 1, modifiee_le = now() WHERE id = $1`, id, n.nom, n.destination, n.bateau, n.debut, n.fin); err != nil {
		return navigationJSON{}, err
	}
	if n, err = a.navigation(ctx, a.b.pool, id); err != nil {
		return navigationJSON{}, err
	}
	return a.detailler(ctx, n, "navigateur")
}

// ------------------------------------------------------------------ fichiers

func (a *app) deposerFichier(ctx context.Context, utilisateur, id, typeMedia string, donnees []byte) error {
	if !estUUID(id) {
		return errIntrouvable()
	}
	var navID string
	var attendu *string
	if err := a.b.pool.QueryRow(ctx, "SELECT navigation_id, fichier_type FROM evenements WHERE id = $1 AND supprime_le IS NULL",
		id).Scan(&navID, &attendu); err != nil {
		return err
	}
	if _, err := a.navigationDuNavigateur(ctx, utilisateur, navID); err != nil {
		return err
	}
	if attendu == nil || !strings.HasPrefix(typeMedia, *attendu) {
		return errInvalide("Ce fichier ne correspond pas à l'événement.")
	}
	if len(donnees) > tailleFichierMax {
		return &erreurAPI{http.StatusRequestEntityTooLarge, "invalide", "Fichier trop gros (5 Mo au plus).", 0}
	}
	if *attendu == "image/jpeg" && !bytes.HasPrefix(donnees, []byte{0xFF, 0xD8, 0xFF}) {
		return errInvalide("La photo doit être au format JPEG.")
	}
	if *attendu == "audio/mp4" && (len(donnees) < 12 || string(donnees[4:8]) != "ftyp") {
		return errInvalide("La note vocale doit être au format AAC (.m4a).")
	}
	_, err := a.b.pool.Exec(ctx, `INSERT INTO fichiers (evenement_id, type_media, contenu) VALUES ($1, $2, $3)
		ON CONFLICT (evenement_id) DO UPDATE SET contenu = EXCLUDED.contenu, recu_le = now()`, id, *attendu, donnees)
	if err != nil {
		return err
	}
	_, err = a.b.pool.Exec(ctx, "UPDATE evenements SET modification = nextval('modifications') WHERE id = $1", id)
	return err
}

// ------------------------------------------------------------------ synchronisation

// operation : traitement d'un élément de la file d'attente du téléphone,
// identique à l'appel unitaire correspondant (POST /v1/synchronisation).
type operation func(ctx context.Context, r *http.Request, s *session, id, navigation string, contenu json.RawMessage) (int, any, error)

func (a *app) operations() map[string]operation {
	ops := map[string]operation{
		"demarrage": func(ctx context.Context, r *http.Request, s *session, id, _ string, contenu json.RawMessage) (int, any, error) {
			var d demarrageJSON
			if err := json.Unmarshal(contenu, &d); err != nil {
				return 0, nil, errInvalide("Démarrage illisible.")
			}
			return a.demarrer(ctx, s.utilisateur, id, d)
		},
		"evenement": func(ctx context.Context, r *http.Request, s *session, id, navigation string, contenu json.RawMessage) (int, any, error) {
			var e evenementJSON
			if err := json.Unmarshal(contenu, &e); err != nil {
				return 0, nil, errInvalide("Événement illisible.")
			}
			e.ID = id
			return a.envoyerEvenement(ctx, s.utilisateur, navigation, e)
		},
		"fin": func(ctx context.Context, r *http.Request, s *session, id, navigation string, contenu json.RawMessage) (int, any, error) {
			var e evenementJSON
			if err := json.Unmarshal(contenu, &e); err != nil {
				return 0, nil, errInvalide("Fin illisible.")
			}
			if navigation == "" {
				navigation = id
			}
			n, err := a.terminer(ctx, s.utilisateur, navigation, e)
			n.AdressePage = a.adressePublique(r) + "/navigations/" + navigation
			return http.StatusOK, n, err
		},
	}
	maps.Copy(ops, a.operationsSos())
	return ops
}

type resultatElement struct {
	ID     string            `json:"id"`
	Statut int               `json:"statut"`
	Erreur map[string]string `json:"erreur,omitempty"`
}

func (a *app) synchroniser(ctx context.Context, r *http.Request, s *session, elements []struct {
	Operation    string          `json:"operation"`
	ID           string          `json:"id"`
	NavigationID string          `json:"navigationId"`
	Contenu      json.RawMessage `json:"contenu"`
}) []resultatElement {
	ops := a.operations()
	resultats := make([]resultatElement, 0, len(elements))
	for _, el := range elements {
		op, ok := ops[el.Operation]
		var statut int
		var err error
		if !ok {
			err = errInvalide("Opération inconnue : " + el.Operation + ".")
		} else {
			statut, _, err = op(ctx, r, s, el.ID, el.NavigationID, el.Contenu)
		}
		re := resultatElement{ID: el.ID, Statut: statut}
		if err != nil {
			e := enErreurAPI(err)
			re.Statut, re.Erreur = e.statut, map[string]string{"code": e.code, "message": e.message}
		}
		resultats = append(resultats, re)
	}
	return resultats
}

// ------------------------------------------------------------------ routes de l'API

func (a *app) routesNavigations(mux *http.ServeMux, v string) {
	ops := a.operations()
	unitaire := func(nom string, navigationDuChemin bool) gestionnaire {
		return func(w http.ResponseWriter, r *http.Request, s *session) error {
			contenu, err := lireCorps(r)
			if err != nil {
				return err
			}
			id, nav := r.PathValue("navigationId"), ""
			if e := r.PathValue("evenementId"); e != "" {
				id, nav = e, r.PathValue("navigationId")
			} else if a := r.PathValue("alerteId"); a != "" {
				id = a
			}
			if navigationDuChemin {
				nav = r.PathValue("navigationId")
			}
			statut, corps, err := ops[nom](r.Context(), r, s, id, nav, contenu)
			if err != nil {
				return err
			}
			ecrireJSON(w, statut, corps)
			return nil
		}
	}
	mux.HandleFunc("PUT "+v+"/navigations/{navigationId}", a.api(true, unitaire("demarrage", false)))
	mux.HandleFunc("PUT "+v+"/navigations/{navigationId}/fin", a.api(true, unitaire("fin", true)))
	mux.HandleFunc("PUT "+v+"/navigations/{navigationId}/evenements/{evenementId}", a.api(true, unitaire("evenement", true)))

	mux.HandleFunc("GET "+v+"/navigations", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		q := r.URL.Query()
		decalage, _ := strconv.Atoi(q.Get("curseur"))
		l, suivant, err := a.navigations(r.Context(), s.utilisateur, q.Get("role"), q.Get("etat"), q.Get("bateauId"), max(0, decalage))
		if err != nil {
			return err
		}
		var curseur *string
		if suivant > 0 {
			c := strconv.Itoa(suivant)
			curseur = &c
		}
		ecrireJSON(w, http.StatusOK, map[string]any{"navigations": l, "curseurSuivant": curseur})
		return nil
	}))
	mux.HandleFunc("GET "+v+"/navigations/{navigationId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		n, role, err := a.navigationVue(r.Context(), s.utilisateur, r.PathValue("navigationId"))
		if err != nil {
			return err
		}
		d, err := a.detailler(r.Context(), n, role)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, d)
		return nil
	}))
	mux.HandleFunc("PATCH "+v+"/navigations/{navigationId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		d, err := a.modifierNavigation(r.Context(), s.utilisateur, r.PathValue("navigationId"), c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, d)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/navigations/{navigationId}/evenements", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		n, _, err := a.navigationVue(r.Context(), s.utilisateur, r.PathValue("navigationId"))
		if err != nil {
			return err
		}
		depuis, _ := strconv.ParseInt(r.URL.Query().Get("depuis"), 10, 64)
		evts, supprimes, curseur, err := a.journalDeBord(r.Context(), n, depuis)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, map[string]any{"evenements": evts, "supprimes": supprimes, "curseur": strconv.FormatInt(curseur, 10)})
		return nil
	}))
	mux.HandleFunc("PATCH "+v+"/navigations/{navigationId}/evenements/{evenementId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c struct {
			Texte *string `json:"texte"`
		}
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		id := r.PathValue("evenementId")
		n, err := a.evenementModifiable(r.Context(), s.utilisateur, r.PathValue("navigationId"), id)
		if err != nil {
			return err
		}
		if _, err := a.b.pool.Exec(r.Context(), `UPDATE evenements SET texte = $2, modification = nextval('modifications')
			WHERE id = $1`, id, texteOuNul(c.Texte)); err != nil {
			return err
		}
		e, err := lireEvenement(a.b.pool.QueryRow(r.Context(), "SELECT "+colonnesEvenement+" FROM evenements e WHERE id = $1", id), n)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, e)
		return nil
	}))
	mux.HandleFunc("DELETE "+v+"/navigations/{navigationId}/evenements/{evenementId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		id := r.PathValue("evenementId")
		if _, err := a.evenementModifiable(r.Context(), s.utilisateur, r.PathValue("navigationId"), id); err != nil {
			return err
		}
		if _, err := a.b.pool.Exec(r.Context(), `UPDATE evenements SET supprime_le = now(), texte = NULL,
			modification = nextval('modifications') WHERE id = $1`, id); err != nil {
			return err
		}
		if _, err := a.b.pool.Exec(r.Context(), "DELETE FROM fichiers WHERE evenement_id = $1", id); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("PUT "+v+"/fichiers/{evenementId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		donnees, err := lireTout(r, tailleFichierMax)
		if err != nil {
			return err
		}
		if err := a.deposerFichier(r.Context(), s.utilisateur, r.PathValue("evenementId"), r.Header.Get("Content-Type"), donnees); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
	mux.HandleFunc("GET "+v+"/fichiers/{evenementId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		id := r.PathValue("evenementId")
		if !estUUID(id) {
			return errIntrouvable()
		}
		var navID string
		if err := a.b.pool.QueryRow(r.Context(), "SELECT navigation_id FROM evenements WHERE id = $1 AND supprime_le IS NULL", id).Scan(&navID); err != nil {
			return err
		}
		if _, _, err := a.navigationVue(r.Context(), s.utilisateur, navID); err != nil {
			return err
		}
		var typ string
		var contenu []byte
		if err := a.b.pool.QueryRow(r.Context(), "SELECT type_media, contenu FROM fichiers WHERE evenement_id = $1", id).Scan(&typ, &contenu); err != nil {
			return err
		}
		w.Header().Set("Content-Type", typ)
		w.Header().Set("Cache-Control", "private, no-cache")
		w.Header().Set("Content-Length", strconv.Itoa(len(contenu)))
		_, _ = w.Write(contenu)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/navigations/{navigationId}/suiveurs", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		n, _, err := a.navigationVue(r.Context(), s.utilisateur, r.PathValue("navigationId"))
		if err != nil {
			return err
		}
		l, err := a.suiveursDe(r.Context(), n)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, l)
		return nil
	}))
	mux.HandleFunc("DELETE "+v+"/navigations/{navigationId}/suiveurs/{utilisateurId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		n, err := a.navigationModifiable(r.Context(), s.utilisateur, r.PathValue("navigationId"))
		if err != nil {
			return err
		}
		suiveur := r.PathValue("utilisateurId")
		if !estUUID(suiveur) {
			return errIntrouvable()
		}
		// Retrait de cette navigation seulement, effet immédiat (RG-PAR-06).
		if _, err := a.b.pool.Exec(r.Context(), `INSERT INTO retraits_navigation (navigation_id, suiveur_id)
			SELECT $1, $2 WHERE EXISTS (SELECT 1 FROM utilisateurs WHERE id = $2) ON CONFLICT DO NOTHING`, n.id, suiveur); err != nil {
			return err
		}
		if _, err := a.b.pool.Exec(r.Context(), "DELETE FROM acces WHERE navigateur_id = $1 AND suiveur_id = $2 AND navigation_id = $3",
			n.navigateur, suiveur, n.id); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("POST "+v+"/synchronisation", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var corps struct {
			AppareilID string `json:"appareilId"`
			Elements   []struct {
				Operation    string          `json:"operation"`
				ID           string          `json:"id"`
				NavigationID string          `json:"navigationId"`
				Contenu      json.RawMessage `json:"contenu"`
			} `json:"elements"`
		}
		if err := lireJSONTaille(r, &corps, 8<<20); err != nil {
			return err
		}
		if len(corps.Elements) > 200 {
			return errInvalide("200 éléments au plus par lot.")
		}
		ecrireJSON(w, http.StatusOK, map[string]any{"resultats": a.synchroniser(r.Context(), r, s, corps.Elements)})
		return nil
	}))
}

func lireCorps(r *http.Request) (json.RawMessage, error) {
	var brut json.RawMessage
	if err := lireJSON(r, &brut); err != nil {
		return nil, err
	}
	return brut, nil
}

func lireJSONTaille(r *http.Request, v any, taille int64) error {
	if err := json.NewDecoder(http.MaxBytesReader(nil, r.Body, taille)).Decode(v); err != nil {
		return errInvalide("Corps de la requête illisible.")
	}
	return nil
}

func lireTout(r *http.Request, taille int) ([]byte, error) {
	var b bytes.Buffer
	n, err := b.ReadFrom(http.MaxBytesReader(nil, r.Body, int64(taille)+1))
	if n > int64(taille) {
		return nil, &erreurAPI{http.StatusRequestEntityTooLarge, "invalide", "Fichier trop gros (5 Mo au plus).", 0}
	}
	if err != nil {
		var trop *http.MaxBytesError
		if errors.As(err, &trop) {
			return nil, &erreurAPI{http.StatusRequestEntityTooLarge, "invalide", "Fichier trop gros (5 Mo au plus).", 0}
		}
		return nil, errInvalide("Fichier illisible.")
	}
	return b.Bytes(), nil
}

// apresDemarrage : traitements qui suivent le démarrage : e-mail de début
// (RG-NOT-02, sos.go) et notification push (RG-IOS-06, push.go) ; la météo
// n'est pas branchée (Q-39).
func (a *app) apresDemarrage(ctx context.Context, n navLigne) {
	if err := a.emailsDebut(ctx, n); err != nil {
		log.Printf("navigation %s : e-mails de début : %v", n.id, err)
	}
	a.notifierNavigation(ctx, n.id, "debut", n.debutEnr)
}
