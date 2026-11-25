package main

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Contacts, invitations et accès (TODO-4.3) : RG-CTC-01 à RG-CTC-05,
// RG-PAR-01 à RG-PAR-08, RG-NOT-02, RG-NOT-03, RG-COM-04.

type contactJSON struct {
	ID             string    `json:"id"`
	Nom            string    `json:"nom"`
	Telephone      *string   `json:"telephone"`
	Email          *string   `json:"email"`
	Suiveur        bool      `json:"suiveur"`
	ContactSos     bool      `json:"contactSos"`
	Perimetre      *string   `json:"perimetre"`
	NavigationID   *string   `json:"navigationId"`
	Version        int       `json:"version"`
	UtilisateurID  *string   `json:"utilisateurId"`
	EtatInvitation string    `json:"etatInvitation"`
	ModifieLe      time.Time `json:"modifieLe"`
	navigateur     string
	supprime       bool
}

type personneJSON struct {
	ID        string  `json:"id"`
	Nom       string  `json:"nom"`
	Telephone *string `json:"telephone"`
	Email     *string `json:"email"`
}

type invitationJSON struct {
	ID           string    `json:"id"`
	ContactID    *string   `json:"contactId"`
	Canal        string    `json:"canal"`
	Email        *string   `json:"email,omitempty"`
	Telephone    *string   `json:"telephone,omitempty"`
	Perimetre    string    `json:"perimetre"`
	NavigationID *string   `json:"navigationId,omitempty"`
	Lien         string    `json:"lien"`
	Etat         string    `json:"etat"`
	CreeeLe      time.Time `json:"creeeLe"`
}

type accesJSON struct {
	ID           string       `json:"id"`
	Navigateur   personneJSON `json:"navigateur"`
	Suiveur      personneJSON `json:"suiveur"`
	Perimetre    string       `json:"perimetre"`
	NavigationID *string      `json:"navigationId"`
	AccordeLe    time.Time    `json:"accordeLe"`
}

const colonnesContact = `c.id, c.navigateur_id, c.nom, c.telephone, c.email, c.suiveur, c.contact_sos, c.perimetre,
	c.navigation_id, c.version, c.utilisateur_id, c.modifie_le, c.supprime_le IS NOT NULL,
	coalesce((SELECT i.etat FROM invitations i WHERE i.contact_id = c.id ORDER BY i.creee_le DESC LIMIT 1), 'aucune')`

func lireContact(l pgx.Row) (contactJSON, error) {
	var c contactJSON
	err := l.Scan(&c.ID, &c.navigateur, &c.Nom, &c.Telephone, &c.Email, &c.Suiveur, &c.ContactSos, &c.Perimetre,
		&c.NavigationID, &c.Version, &c.UtilisateurID, &c.ModifieLe, &c.supprime, &c.EtatInvitation)
	return c, err
}

func (a *app) contact(ctx context.Context, q interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}, navigateur, id string) (contactJSON, error) {
	if !estUUID(id) {
		return contactJSON{}, errIntrouvable()
	}
	return lireContact(q.QueryRow(ctx, "SELECT "+colonnesContact+` FROM contacts c
		WHERE c.id = $1 AND c.navigateur_id = $2 AND c.supprime_le IS NULL`, id, navigateur))
}

// validerPerimetre : périmètre navigation (une navigation) ou navigateur
// (toutes ses navigations présentes et futures) (RG-PAR-02).
func validerPerimetre(perimetre *string, navigation *string) error {
	if perimetre == nil || (*perimetre != "navigation" && *perimetre != "navigateur") {
		return errInvalide("Choisissez ce que le suiveur verra : une navigation ou toutes vos navigations.")
	}
	if *perimetre == "navigation" && (navigation == nil || !estUUID(*navigation)) {
		return errInvalide("Choisissez la navigation que le suiveur verra.")
	}
	if *perimetre == "navigateur" && navigation != nil {
		*navigation = ""
	}
	return nil
}

func texteOuNul(p *string) *string {
	if p == nil || strings.TrimSpace(*p) == "" {
		return nil
	}
	t := strings.TrimSpace(*p)
	return &t
}

// appliquerContact : champs présents dans c (RG-CTC-01, RG-CTC-05). À la
// création, les deux cases sont cochées par défaut ; « Contact SOS » est
// décoché pour un contact sans numéro, et refusé s'il est demandé.
func appliquerContact(k *contactJSON, c champs, creation bool) error {
	for nom, v := range map[string]**string{"telephone": &k.Telephone, "email": &k.Email, "perimetre": &k.Perimetre, "navigationId": &k.NavigationID} {
		if c.a(nom) {
			var t *string
			if err := c.lire(nom, &t); err != nil {
				return err
			}
			*v = texteOuNul(t)
		}
	}
	if c.a("nom") {
		var t *string
		if err := c.lire("nom", &t); err != nil {
			return err
		}
		k.Nom = ""
		if t != nil {
			k.Nom = strings.TrimSpace(*t)
		}
	}
	if len([]rune(k.Nom)) > 100 || strings.ContainsAny(k.Nom, "\r\n") {
		return errInvalide("Nom trop long (100 caractères au plus).")
	}
	if k.Telephone != nil {
		t, err := normaliserTelephone(*k.Telephone)
		if err != nil {
			return err
		}
		k.Telephone = &t
	}
	if k.Email != nil {
		e, err := normaliserEmail(*k.Email)
		if err != nil {
			return err
		}
		k.Email = &e
	}
	if k.Telephone == nil && k.Email == nil {
		return errInvalide("Indiquez un numéro de téléphone ou une adresse e-mail.")
	}
	if creation {
		k.Suiveur, k.ContactSos = true, k.Telephone != nil
	}
	if c.a("suiveur") {
		if err := c.lire("suiveur", &k.Suiveur); err != nil {
			return err
		}
	}
	sosDemande := false
	if c.a("contactSos") {
		if err := c.lire("contactSos", &k.ContactSos); err != nil {
			return err
		}
		sosDemande = k.ContactSos
	}
	if k.Telephone == nil {
		if sosDemande {
			return &erreurAPI{http.StatusUnprocessableEntity, "contact_sos_sans_telephone",
				"Un contact SOS doit avoir un numéro de téléphone.", 0}
		}
		k.ContactSos = false
	}
	if k.Nom == "" {
		if k.Email != nil {
			k.Nom = *k.Email
		} else {
			k.Nom = *k.Telephone
		}
	}
	return nil
}

func (a *app) contacts(ctx context.Context, navigateur string, depuis int64) (liste []contactJSON, supprimes []string, curseur int64, err error) {
	if err = a.b.pool.QueryRow(ctx, "SELECT coalesce(max(modification), 0) FROM contacts WHERE navigateur_id = $1",
		navigateur).Scan(&curseur); err != nil {
		return
	}
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesContact+` FROM contacts c
		WHERE c.navigateur_id = $1 AND c.modification > $2 AND ($2 > 0 OR c.supprime_le IS NULL)
		ORDER BY lower(c.nom)`, navigateur, depuis)
	if err != nil {
		return
	}
	tous, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (contactJSON, error) { return lireContact(l) })
	if err != nil {
		return
	}
	liste, supprimes = []contactJSON{}, []string{}
	for _, c := range tous {
		if c.supprime {
			supprimes = append(supprimes, c.ID)
		} else {
			liste = append(liste, c)
		}
	}
	return
}

// creerContact : ajout depuis le Web, l'application mobile ou l'écran de
// démarrage (RG-CTC-02, RG-NAV-26). Cocher « Suiveur » envoie une invitation
// avec le périmètre choisi (RG-CTC-04). L'identifiant peut être tiré par le
// client pour un ajout hors connexion : un renvoi ne crée pas de doublon.
func (a *app) creerContact(ctx context.Context, r *http.Request, navigateur string, c champs) (contactJSON, bool, error) {
	var k contactJSON
	if c.a("id") {
		if err := c.lire("id", &k.ID); err != nil || !estUUID(k.ID) {
			return k, false, errInvalide("Identifiant de contact invalide.")
		}
		if existant, err := a.contact(ctx, a.b.pool, navigateur, k.ID); err == nil {
			return existant, false, nil
		}
	}
	if err := appliquerContact(&k, c, true); err != nil {
		return k, false, err
	}
	if k.Suiveur {
		if err := a.perimetreValide(ctx, navigateur, k.Perimetre, k.NavigationID); err != nil {
			return k, false, err
		}
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return k, false, err
	}
	defer tx.Rollback(ctx)
	var id string
	err = tx.QueryRow(ctx, `INSERT INTO contacts (id, navigateur_id, nom, telephone, email, suiveur, contact_sos, perimetre, navigation_id)
		VALUES (coalesce(nullif($1, '')::uuid, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
		k.ID, navigateur, k.Nom, k.Telephone, k.Email, k.Suiveur, k.ContactSos, k.Perimetre, texteOuNul(k.NavigationID)).Scan(&id)
	if estDoublon(err) {
		return k, false, &erreurAPI{http.StatusConflict, "invalide", "Cet identifiant de contact est déjà pris.", 0}
	}
	if err != nil {
		return k, false, err
	}
	var envoi func()
	if k.Suiveur {
		if _, envoi, err = a.inviterContact(ctx, tx, r, navigateur, id); err != nil {
			return k, false, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return k, false, err
	}
	if envoi != nil {
		envoi()
	}
	k, err = a.contact(ctx, a.b.pool, navigateur, id)
	return k, true, err
}

// modifierContact : seuls les champs présents changent (RG-COM-04).
// Décocher « Suiveur » retire le suiveur de toutes les navigations et annule
// l'invitation en attente (RG-CTC-04, RG-PAR-06) ; le recocher envoie une
// nouvelle invitation.
func (a *app) modifierContact(ctx context.Context, r *http.Request, navigateur, id string, c champs) (contactJSON, error) {
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return contactJSON{}, err
	}
	defer tx.Rollback(ctx)
	if !estUUID(id) {
		return contactJSON{}, errIntrouvable()
	}
	if _, err := tx.Exec(ctx, "SELECT 1 FROM contacts WHERE id = $1 FOR UPDATE", id); err != nil {
		return contactJSON{}, err
	}
	k, err := a.contact(ctx, tx, navigateur, id)
	if err != nil {
		return k, err
	}
	etaitSuiveur := k.Suiveur
	if err := appliquerContact(&k, c, false); err != nil {
		return k, err
	}
	if k.Suiveur && !etaitSuiveur {
		if err := a.perimetreValide(ctx, navigateur, k.Perimetre, k.NavigationID); err != nil {
			return k, err
		}
	}
	if _, err := tx.Exec(ctx, `UPDATE contacts SET nom = $3, telephone = $4, email = $5, suiveur = $6, contact_sos = $7,
		perimetre = $8, navigation_id = $9, version = version + 1, modification = nextval('modifications'), modifie_le = now()
		WHERE id = $1 AND navigateur_id = $2`, id, navigateur, k.Nom, k.Telephone, k.Email, k.Suiveur, k.ContactSos,
		k.Perimetre, texteOuNul(k.NavigationID)); err != nil {
		return k, err
	}
	var envoi func()
	switch {
	case etaitSuiveur && !k.Suiveur:
		err = retirerSuiveur(ctx, tx, navigateur, k)
	case !etaitSuiveur && k.Suiveur:
		_, envoi, err = a.inviterContact(ctx, tx, r, navigateur, id)
	}
	if err != nil {
		return k, err
	}
	if err := tx.Commit(ctx); err != nil {
		return k, err
	}
	if envoi != nil {
		envoi()
	}
	return a.contact(ctx, a.b.pool, navigateur, id)
}

// retirerSuiveur : retrait immédiat de toutes les navigations présentes et
// futures, invitations en attente annulées (RG-PAR-06).
func retirerSuiveur(ctx context.Context, tx pgx.Tx, navigateur string, k contactJSON) error {
	if _, err := tx.Exec(ctx, `DELETE FROM acces WHERE navigateur_id = $1 AND (contact_id = $2 OR suiveur_id = $3)`,
		navigateur, k.ID, k.UtilisateurID); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `UPDATE invitations SET etat = 'annulee' WHERE contact_id = $1 AND etat = 'envoyee'`, k.ID)
	return err
}

// supprimerContact : retire aussi ses accès ; la suppression est transmise
// aux téléphones par `depuis` (RG-CTC-03).
func (a *app) supprimerContact(ctx context.Context, navigateur, id string) error {
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	k, err := a.contact(ctx, tx, navigateur, id)
	if err != nil {
		return err
	}
	if err := retirerSuiveur(ctx, tx, navigateur, k); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE contacts SET supprime_le = now(), modification = nextval('modifications'),
		modifie_le = now() WHERE id = $1`, id); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// ------------------------------------------------------------------ invitations

func (a *app) lienInvitation(r *http.Request, jeton string) string {
	return a.adressePublique(r) + "/invitation?jeton=" + jeton
}

const colonnesInvitation = `id, contact_id, canal, email, telephone, perimetre, navigation_id, jeton, etat, creee_le`

func (a *app) lireInvitation(r *http.Request, l pgx.Row) (invitationJSON, error) {
	var i invitationJSON
	var jeton string
	err := l.Scan(&i.ID, &i.ContactID, &i.Canal, &i.Email, &i.Telephone, &i.Perimetre, &i.NavigationID, &jeton, &i.Etat, &i.CreeeLe)
	i.Lien = a.lienInvitation(r, jeton)
	return i, err
}

// inviterContact : invitation du contact avec son périmètre ; par e-mail si
// l'adresse est connue (envoyée par le serveur, copie au navigateur), sinon
// par téléphone : le lien est rendu, l'application Android l'envoie par SMS,
// le Web l'affiche (RG-PAR-03, RG-PAR-04, RG-NOT-03). L'envoi de l'e-mail
// est rendu à part, pour partir après la validation de la transaction.
func (a *app) inviterContact(ctx context.Context, tx pgx.Tx, r *http.Request, navigateur, contactID string) (invitationJSON, func(), error) {
	k, err := a.contact(ctx, tx, navigateur, contactID)
	if err != nil {
		return invitationJSON{}, nil, err
	}
	canal := "telephone"
	if k.Email != nil {
		canal = "email"
	}
	return a.inviter(ctx, tx, r, navigateur, k, canal)
}

// errInvitationEmail : un compte dont l'adresse n'est pas confirmée n'envoie
// pas d'invitation, par aucun canal (RG-CPT-09, D-105).
var errInvitationEmail = &erreurAPI{http.StatusForbidden, "email_non_verifie",
	"Confirmez d'abord votre adresse e-mail : ouvrez le lien que NautiLink vous a envoyé, puis invitez vos suiveurs.", 0}

func (a *app) inviter(ctx context.Context, tx pgx.Tx, r *http.Request, navigateur string, k contactJSON, canal string) (invitationJSON, func(), error) {
	var confirmee bool
	if err := tx.QueryRow(ctx, "SELECT email_verifie_le IS NOT NULL FROM utilisateurs WHERE id = $1", navigateur).Scan(&confirmee); err != nil {
		return invitationJSON{}, nil, err
	}
	if !confirmee {
		return invitationJSON{}, nil, errInvitationEmail
	}
	if err := a.perimetreValide(ctx, navigateur, k.Perimetre, k.NavigationID); err != nil {
		return invitationJSON{}, nil, err
	}
	if (canal == "email" && k.Email == nil) || (canal == "telephone" && k.Telephone == nil) {
		return invitationJSON{}, nil, errInvalide("Indiquez l'adresse e-mail ou le numéro de téléphone de la personne invitée.")
	}
	if _, err := tx.Exec(ctx, `UPDATE invitations SET etat = 'annulee' WHERE contact_id = $1 AND etat = 'envoyee'`, k.ID); err != nil {
		return invitationJSON{}, nil, err
	}
	jeton := nouveauJeton()
	var email, telephone *string
	if canal == "email" {
		email = k.Email
	} else {
		telephone = k.Telephone
	}
	i, err := a.lireInvitation(r, tx.QueryRow(ctx, `INSERT INTO invitations (navigateur_id, contact_id, canal, email, telephone,
		perimetre, navigation_id, jeton) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING `+colonnesInvitation,
		navigateur, k.ID, canal, email, telephone, *k.Perimetre, texteOuNul(k.NavigationID), jeton))
	if err != nil {
		return i, nil, err
	}
	if _, err := tx.Exec(ctx, "UPDATE contacts SET modification = nextval('modifications') WHERE id = $1", k.ID); err != nil {
		return i, nil, err
	}
	if canal != "email" {
		return i, nil, nil
	}
	p, err := a.profil(ctx, navigateur)
	if err != nil {
		return i, nil, err
	}
	envoi := func() {
		portee := "toutes ses navigations, présentes et futures"
		if *k.Perimetre == "navigation" {
			portee = "une de ses navigations"
		}
		a.courriel(*k.Email, "NautiLink : "+p.Nom+" vous invite à suivre ses navigations",
			"Bonjour,\n\n"+p.Nom+" vous invite à suivre "+portee+" sur NautiLink : position, journal de bord et alertes.\n\n"+
				"Pour accepter, ouvrez ce lien puis connectez-vous ou créez votre compte NautiLink :\n\n"+i.Lien+"\n\n"+
				"Si vous ne connaissez pas cette personne, ignorez cet e-mail.\n\nNautiLink — Version bêta\n")
		a.courriel(p.Email, "NautiLink : copie de votre invitation à "+k.Nom,
			"Bonjour "+p.Nom+",\n\nCopie de l'invitation envoyée à "+k.Nom+" ("+*k.Email+") pour suivre "+portee+".\n\n"+
				"NautiLink — Version bêta\n")
	}
	return i, envoi, nil
}

// nouvelleInvitation : POST /v1/invitations. Sans contact donné, l'invité est
// ajouté à la liste de contacts, les deux cases cochées (RG-CTC-04, RG-PAR-03).
func (a *app) nouvelleInvitation(ctx context.Context, r *http.Request, navigateur string, c champs) (invitationJSON, error) {
	var corps struct {
		ContactID, Canal, Email, Telephone, Perimetre, NavigationID string
	}
	for nom, v := range map[string]*string{"contactId": &corps.ContactID, "canal": &corps.Canal, "email": &corps.Email,
		"telephone": &corps.Telephone, "perimetre": &corps.Perimetre, "navigationId": &corps.NavigationID} {
		if c.a(nom) {
			var t *string
			if err := c.lire(nom, &t); err != nil {
				return invitationJSON{}, err
			}
			if t != nil {
				*v = *t
			}
		}
	}
	if corps.Canal != "email" && corps.Canal != "telephone" {
		return invitationJSON{}, errInvalide("Canal invalide : email ou telephone.")
	}
	modif := champs{"suiveur": enJSON(true), "perimetre": enJSON(corps.Perimetre), "navigationId": enJSON(texteOuNul(&corps.NavigationID))}
	if corps.Email != "" {
		modif["email"] = enJSON(corps.Email)
	}
	if corps.Telephone != "" {
		modif["telephone"] = enJSON(corps.Telephone)
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return invitationJSON{}, err
	}
	defer tx.Rollback(ctx)
	var k contactJSON
	if corps.ContactID != "" {
		if k, err = a.contact(ctx, tx, navigateur, corps.ContactID); err != nil {
			return invitationJSON{}, err
		}
		if err := appliquerContact(&k, modif, false); err != nil {
			return invitationJSON{}, err
		}
	} else if err := appliquerContact(&k, modif, true); err != nil {
		return invitationJSON{}, err
	}
	if err := a.perimetreValide(ctx, navigateur, k.Perimetre, k.NavigationID); err != nil {
		return invitationJSON{}, err
	}
	if err := tx.QueryRow(ctx, `INSERT INTO contacts (id, navigateur_id, nom, telephone, email, suiveur, contact_sos, perimetre, navigation_id)
		VALUES (coalesce(nullif($1, '')::uuid, gen_random_uuid()), $2, $3, $4, $5, true, $6, $7, $8)
		ON CONFLICT (id) DO UPDATE SET telephone = EXCLUDED.telephone, email = EXCLUDED.email, suiveur = true,
			perimetre = EXCLUDED.perimetre, navigation_id = EXCLUDED.navigation_id, version = contacts.version + 1,
			modification = nextval('modifications'), modifie_le = now()
		RETURNING id`, k.ID, navigateur, k.Nom, k.Telephone, k.Email, k.ContactSos, k.Perimetre, texteOuNul(k.NavigationID)).Scan(&k.ID); err != nil {
		return invitationJSON{}, err
	}
	i, envoi, err := a.inviter(ctx, tx, r, navigateur, k, corps.Canal)
	if err != nil {
		return i, err
	}
	if err := tx.Commit(ctx); err != nil {
		return i, err
	}
	if envoi != nil {
		envoi()
	}
	return i, nil
}

func (a *app) invitations(ctx context.Context, r *http.Request, navigateur, contact string) ([]invitationJSON, error) {
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesInvitation+` FROM invitations
		WHERE navigateur_id = $1 AND ($2 = '' OR contact_id::text = $2) ORDER BY creee_le DESC`, navigateur, contact)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(lignes, func(l pgx.CollectableRow) (invitationJSON, error) { return a.lireInvitation(r, l) })
}

// annulerInvitation : tant qu'elle n'est pas acceptée ; elle n'expire pas
// (RG-PAR-05).
func (a *app) annulerInvitation(ctx context.Context, navigateur, id string) error {
	if !estUUID(id) {
		return errIntrouvable()
	}
	var etat string
	var contact *string
	err := a.b.pool.QueryRow(ctx, "SELECT etat, contact_id FROM invitations WHERE id = $1 AND navigateur_id = $2",
		id, navigateur).Scan(&etat, &contact)
	if err != nil {
		return err
	}
	if etat == "acceptee" {
		return &erreurAPI{http.StatusConflict, "invitation_deja_acceptee", "Cette invitation a déjà été acceptée.", 0}
	}
	if _, err := a.b.pool.Exec(ctx, "UPDATE invitations SET etat = 'annulee' WHERE id = $1", id); err != nil {
		return err
	}
	_, err = a.b.pool.Exec(ctx, "UPDATE contacts SET modification = nextval('modifications') WHERE id = $1", contact)
	return err
}

// invitationParJeton : invitation en attente ou acceptée, avec le nom du
// navigateur (page d'invitation).
func (a *app) invitationParJeton(ctx context.Context, jeton string) (id, navigateur, nomNavigateur, etat string, acceptePar *string, err error) {
	err = a.b.pool.QueryRow(ctx, `SELECT i.id, i.navigateur_id, u.nom, i.etat, i.acceptee_par FROM invitations i
		JOIN utilisateurs u ON u.id = i.navigateur_id WHERE i.jeton = $1 AND i.etat <> 'annulee'`, jeton).Scan(
		&id, &navigateur, &nomNavigateur, &etat, &acceptePar)
	if errors.Is(err, pgx.ErrNoRows) {
		err = &erreurAPI{http.StatusNotFound, "introuvable", "Cette invitation n'existe pas ou a été annulée.", 0}
	}
	return
}

// accepterInvitation : l'accès est accordé dès que l'invité est connecté
// (RG-PAR-01, RG-PAR-05) ; e-mail « nouvel accès » au suiveur, copie au
// navigateur (RG-NOT-02, RG-NOT-03).
func (a *app) accepterInvitation(ctx context.Context, suiveur, jeton string) (accesJSON, error) {
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return accesJSON{}, err
	}
	defer tx.Rollback(ctx)
	var id, navigateur, perimetre, etat string
	var contact, navigation, acceptePar *string
	err = tx.QueryRow(ctx, `SELECT id, navigateur_id, contact_id, perimetre, navigation_id, etat, acceptee_par
		FROM invitations WHERE jeton = $1 AND etat <> 'annulee' FOR UPDATE`, jeton).Scan(
		&id, &navigateur, &contact, &perimetre, &navigation, &etat, &acceptePar)
	if errors.Is(err, pgx.ErrNoRows) {
		return accesJSON{}, &erreurAPI{http.StatusNotFound, "introuvable", "Cette invitation n'existe pas ou a été annulée.", 0}
	}
	if err != nil {
		return accesJSON{}, err
	}
	if navigateur == suiveur {
		return accesJSON{}, errInvalide("Vous ne pouvez pas accepter votre propre invitation.")
	}
	if etat == "acceptee" {
		if acceptePar != nil && *acceptePar == suiveur {
			return a.accesDuSuiveur(ctx, navigateur, suiveur, navigation)
		}
		return accesJSON{}, &erreurAPI{http.StatusConflict, "invitation_deja_acceptee", "Cette invitation a déjà été acceptée.", 0}
	}
	if _, err := tx.Exec(ctx, `INSERT INTO acces (navigateur_id, suiveur_id, perimetre, navigation_id, contact_id)
		VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING`, navigateur, suiveur, perimetre, navigation, contact); err != nil {
		return accesJSON{}, err
	}
	if _, err := tx.Exec(ctx, `UPDATE invitations SET etat = 'acceptee', acceptee_le = now(), acceptee_par = $2 WHERE id = $1`,
		id, suiveur); err != nil {
		return accesJSON{}, err
	}
	if _, err := tx.Exec(ctx, `UPDATE contacts SET utilisateur_id = $2, modification = nextval('modifications'), modifie_le = now()
		WHERE id = $1`, contact, suiveur); err != nil {
		return accesJSON{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return accesJSON{}, err
	}
	ac, err := a.accesDuSuiveur(ctx, navigateur, suiveur, navigation)
	if err != nil {
		return ac, err
	}
	portee := "toutes ses navigations, présentes et futures"
	if perimetre == "navigation" {
		portee = "une de ses navigations"
	}
	if ac.Suiveur.Email != nil {
		a.courriel(*ac.Suiveur.Email, "NautiLink : vous suivez maintenant "+ac.Navigateur.Nom,
			"Bonjour "+ac.Suiveur.Nom+",\n\n"+ac.Navigateur.Nom+" vous a donné accès à "+portee+" sur NautiLink.\n\nNautiLink — Version bêta\n")
	}
	if ac.Navigateur.Email != nil {
		a.courriel(*ac.Navigateur.Email, "NautiLink : copie — "+ac.Suiveur.Nom+" suit maintenant vos navigations",
			"Bonjour "+ac.Navigateur.Nom+",\n\nCopie : "+ac.Suiveur.Nom+" a accepté votre invitation et suit "+
				strings.Replace(portee, "ses", "vos", 1)+".\n\nNautiLink — Version bêta\n")
	}
	return ac, nil
}

// ------------------------------------------------------------------ accès

const selectAcces = `SELECT a.id, n.id, n.nom, n.telephone, n.email, s.id, s.nom, s.telephone, s.email,
	a.perimetre, a.navigation_id, a.accorde_le FROM acces a
	JOIN utilisateurs n ON n.id = a.navigateur_id JOIN utilisateurs s ON s.id = a.suiveur_id `

func lireAcces(l pgx.Row) (accesJSON, error) {
	var ac accesJSON
	err := l.Scan(&ac.ID, &ac.Navigateur.ID, &ac.Navigateur.Nom, &ac.Navigateur.Telephone, &ac.Navigateur.Email,
		&ac.Suiveur.ID, &ac.Suiveur.Nom, &ac.Suiveur.Telephone, &ac.Suiveur.Email, &ac.Perimetre, &ac.NavigationID, &ac.AccordeLe)
	return ac, err
}

func (a *app) accesDuSuiveur(ctx context.Context, navigateur, suiveur string, navigation *string) (accesJSON, error) {
	return lireAcces(a.b.pool.QueryRow(ctx, selectAcces+`WHERE a.navigateur_id = $1 AND a.suiveur_id = $2
		AND a.navigation_id IS NOT DISTINCT FROM $3`, navigateur, suiveur, navigation))
}

// listeAcces : accès donnés (role navigateur) ou reçus (role suiveur).
func (a *app) listeAcces(ctx context.Context, utilisateur, role string) ([]accesJSON, error) {
	colonne := "a.navigateur_id"
	if role == "suiveur" {
		colonne = "a.suiveur_id"
	}
	lignes, err := a.b.pool.Query(ctx, selectAcces+"WHERE "+colonne+" = $1 ORDER BY a.accorde_le", utilisateur)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(lignes, func(l pgx.CollectableRow) (accesJSON, error) { return lireAcces(l) })
}

func (a *app) accesDonne(ctx context.Context, navigateur, id string) (accesJSON, error) {
	if !estUUID(id) {
		return accesJSON{}, errIntrouvable()
	}
	return lireAcces(a.b.pool.QueryRow(ctx, selectAcces+"WHERE a.id = $1 AND a.navigateur_id = $2", id, navigateur))
}

// changerPerimetre : le navigateur change le périmètre à tout moment (RG-PAR-02).
func (a *app) changerPerimetre(ctx context.Context, navigateur, id string, perimetre, navigation *string) (accesJSON, error) {
	if _, err := a.accesDonne(ctx, navigateur, id); err != nil {
		return accesJSON{}, err
	}
	if err := a.perimetreValide(ctx, navigateur, perimetre, navigation); err != nil {
		return accesJSON{}, err
	}
	_, err := a.b.pool.Exec(ctx, "UPDATE acces SET perimetre = $2, navigation_id = $3 WHERE id = $1", id, *perimetre, texteOuNul(navigation))
	if estDoublon(err) {
		return accesJSON{}, &erreurAPI{http.StatusConflict, "invalide", "Ce suiveur a déjà cet accès.", 0}
	}
	if err != nil {
		return accesJSON{}, err
	}
	return a.accesDonne(ctx, navigateur, id)
}

// retirerAcces : retrait du suiveur de toutes les navigations présentes et
// futures, effet immédiat (RG-PAR-06) ; son contact n'est plus « Suiveur »
// (RG-CTC-04).
func (a *app) retirerAcces(ctx context.Context, navigateur, id string) error {
	ac, err := a.accesDonne(ctx, navigateur, id)
	if err != nil {
		return err
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, "DELETE FROM acces WHERE navigateur_id = $1 AND suiveur_id = $2", navigateur, ac.Suiveur.ID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE contacts SET suiveur = false, version = version + 1, modification = nextval('modifications'),
		modifie_le = now() WHERE navigateur_id = $1 AND utilisateur_id = $2 AND suiveur`, navigateur, ac.Suiveur.ID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// suitLeNavigateur : vrai si suiveur a un accès de périmètre navigateur
// donné par navigateur (RG-PAR-02) : il voit alors ses fiches de bateau
// (RG-PAR-08).
func (a *app) suitLeNavigateur(ctx context.Context, suiveur, navigateur string) bool {
	var ok bool
	_ = a.b.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM acces WHERE suiveur_id = $1 AND navigateur_id = $2
		AND perimetre = 'navigateur')`, suiveur, navigateur).Scan(&ok)
	return ok
}

// ------------------------------------------------------------------ routes de l'API

func (a *app) routesContacts(mux *http.ServeMux, v string) {
	mux.HandleFunc("GET "+v+"/contacts", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var depuis int64
		if d := r.URL.Query().Get("depuis"); d != "" {
			var err error
			if depuis, err = strconv.ParseInt(d, 10, 64); err != nil || depuis < 0 {
				return errInvalide("Curseur « depuis » invalide.")
			}
		}
		l, sup, curseur, err := a.contacts(r.Context(), s.utilisateur, depuis)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, map[string]any{"contacts": l, "supprimes": sup, "curseur": strconv.FormatInt(curseur, 10)})
		return nil
	}))
	mux.HandleFunc("POST "+v+"/contacts", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		k, cree, err := a.creerContact(r.Context(), r, s.utilisateur, c)
		if err != nil {
			return err
		}
		statut := http.StatusCreated
		if !cree {
			statut = http.StatusOK
		}
		ecrireJSON(w, statut, k)
		return nil
	}))
	mux.HandleFunc("PATCH "+v+"/contacts/{contactId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		k, err := a.modifierContact(r.Context(), r, s.utilisateur, r.PathValue("contactId"), c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, k)
		return nil
	}))
	mux.HandleFunc("DELETE "+v+"/contacts/{contactId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if err := a.supprimerContact(r.Context(), s.utilisateur, r.PathValue("contactId")); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/invitations", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		l, err := a.invitations(r.Context(), r, s.utilisateur, "")
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, l)
		return nil
	}))
	mux.HandleFunc("POST "+v+"/invitations", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		i, err := a.nouvelleInvitation(r.Context(), r, s.utilisateur, c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusCreated, i)
		return nil
	}))
	mux.HandleFunc("DELETE "+v+"/invitations/{invitationId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if err := a.annulerInvitation(r.Context(), s.utilisateur, r.PathValue("invitationId")); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
	mux.HandleFunc("POST "+v+"/invitations/acceptation", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c struct{ JetonInvitation string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		ac, err := a.accepterInvitation(r.Context(), s.utilisateur, c.JetonInvitation)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, ac)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/acces", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		role := r.URL.Query().Get("role")
		if role != "" && role != "navigateur" && role != "suiveur" {
			return errInvalide("Rôle invalide : navigateur ou suiveur.")
		}
		l, err := a.listeAcces(r.Context(), s.utilisateur, role)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, l)
		return nil
	}))
	mux.HandleFunc("PATCH "+v+"/acces/{accesId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c struct {
			Perimetre    *string
			NavigationID *string
		}
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		ac, err := a.changerPerimetre(r.Context(), s.utilisateur, r.PathValue("accesId"), c.Perimetre, c.NavigationID)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, ac)
		return nil
	}))
	mux.HandleFunc("DELETE "+v+"/acces/{accesId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if err := a.retirerAcces(r.Context(), s.utilisateur, r.PathValue("accesId")); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
}
