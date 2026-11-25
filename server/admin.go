package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Espace administrateur (TODO-7.1) : RG-ADM-01 à RG-ADM-04, RG-ADM-06.
// Profil unique d'administrateur (RG-ADM-03, D-47). Désignation des
// administrateurs : liste d'adresses e-mail dans NAUTILINK_ADMINS (Q-53, non
// validée) ; l'administrateur se connecte avec son compte NautiLink, dont
// l'adresse doit être confirmée, et reçoit une session distincte (cookie
// nautilink_admin, RG-ADM-01). Chaque action est tracée dans journal_admin,
// gardé 3 ans (RG-DON-02).

const (
	nomCookieAdmin      = "nautilink_admin"
	dureeSansUsageAdmin = 12 * time.Hour // Q-53, non validée
	dureeJournalAdmin   = "3 years"      // RG-DON-02
)

var errPasAdministrateur = &erreurAPI{http.StatusForbidden, "interdit",
	"Ce compte n'est pas administrateur, ou son adresse e-mail n'est pas confirmée.", 0}

var errPasDisponible = &erreurAPI{http.StatusNotFound, "non_disponible",
	"Cette fonction de l'espace administrateur n'est pas encore disponible.", 0}

// sessionAdmin : session ouverte dans l'espace administrateur.
type sessionAdmin struct {
	id, utilisateur, email string
}

func (a *app) estAdmin(email string) bool {
	return slices.Contains(a.cfg.Admins, strings.ToLower(strings.TrimSpace(email)))
}

// adminValide : le compte existe, son adresse est confirmée et figure dans
// NAUTILINK_ADMINS (relu à chaque requête : retirer une adresse retire l'accès).
func (a *app) adminValide(ctx context.Context, utilisateur string) (string, bool, error) {
	var email string
	var verifie *time.Time
	err := a.b.pool.QueryRow(ctx, "SELECT email, email_verifie_le FROM utilisateurs WHERE id = $1",
		utilisateur).Scan(&email, &verifie)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	return email, err == nil && verifie != nil && a.estAdmin(email), err
}

// connexionAdmin : e-mail et mot de passe du compte NautiLink, avec la même
// protection contre les essais répétés ; rend le jeton de la session.
func (a *app) connexionAdmin(ctx context.Context, r *http.Request, email, mdp string) (string, error) {
	id, err := a.connexionEmail(ctx, r, email, mdp, "")
	if err != nil && err != errAvertissement {
		return "", err
	}
	adresse, ok, err := a.adminValide(ctx, id)
	if err != nil {
		return "", err
	}
	if !ok {
		return "", errPasAdministrateur
	}
	jeton := nouveauJeton()
	if _, err := a.b.pool.Exec(ctx, "INSERT INTO sessions_admin (utilisateur_id, jeton) VALUES ($1, $2)",
		id, empreinte(jeton)); err != nil {
		return "", err
	}
	s := &sessionAdmin{utilisateur: id, email: adresse}
	if err := a.journaliser(ctx, s, "connexion", "session", "", nil); err != nil {
		return "", err
	}
	// Journaux d'administration gardés 3 ans (RG-DON-02), purgés à chaque connexion.
	_, err = a.b.pool.Exec(ctx, "DELETE FROM journal_admin WHERE le < now() - $1::interval", dureeJournalAdmin)
	return jeton, err
}

// sessionAdminDe : session de l'espace administrateur, ou nil.
func (a *app) sessionAdminDe(ctx context.Context, r *http.Request) (*sessionAdmin, error) {
	c, err := r.Cookie(nomCookieAdmin)
	if err != nil || c.Value == "" || !a.b.prete() {
		return nil, nil
	}
	s := &sessionAdmin{}
	var derniere time.Time
	err = a.b.pool.QueryRow(ctx, "SELECT id, utilisateur_id, derniere_utilisation FROM sessions_admin WHERE jeton = $1",
		empreinte(c.Value)).Scan(&s.id, &s.utilisateur, &derniere)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	email, ok, err := a.adminValide(ctx, s.utilisateur)
	if err != nil {
		return nil, err
	}
	if !ok || time.Since(derniere) > dureeSansUsageAdmin {
		_, err := a.b.pool.Exec(ctx, "DELETE FROM sessions_admin WHERE id = $1", s.id)
		return nil, err
	}
	s.email = email
	if time.Since(derniere) > time.Minute {
		if _, err := a.b.pool.Exec(ctx, "UPDATE sessions_admin SET derniere_utilisation = now() WHERE id = $1", s.id); err != nil {
			return nil, err
		}
	}
	return s, nil
}

func (a *app) poserCookieAdmin(w http.ResponseWriter, jeton string) {
	http.SetCookie(w, &http.Cookie{Name: nomCookieAdmin, Value: jeton, Path: a.cfg.Chemin + "/",
		MaxAge: int(dureeSansUsageAdmin.Seconds()), HttpOnly: true, Secure: true, SameSite: http.SameSiteStrictMode})
}

func (a *app) effacerCookieAdmin(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{Name: nomCookieAdmin, Value: "", Path: a.cfg.Chemin + "/",
		MaxAge: -1, HttpOnly: true, Secure: true, SameSite: http.SameSiteStrictMode})
}

// ------------------------------------------------------------------ journal

type entreeJournal struct {
	Le         time.Time       `json:"le"`
	Admin      string          `json:"admin"`
	Action     string          `json:"action"`
	Ressource  string          `json:"ressource"`
	Cible      string          `json:"cible"`
	Details    json.RawMessage `json:"details,omitempty"`
	AdresseIP  string          `json:"-"`
	DetailsTxt string          `json:"-"`
}

// journaliser : trace une action de l'administrateur (RG-ADM-03). L'adresse
// e-mail est copiée : l'entrée reste si le compte est supprimé.
func (a *app) journaliser(ctx context.Context, s *sessionAdmin, action, ressource, cible string, details any) error {
	var d []byte
	if details != nil {
		d, _ = json.Marshal(details)
	}
	_, err := a.b.pool.Exec(ctx, `INSERT INTO journal_admin (admin_id, admin_email, action, ressource, cible, details)
		VALUES ($1, $2, $3, $4, $5, $6)`, s.utilisateur, s.email, action, ressource, cible, d)
	return err
}

func (a *app) journal(ctx context.Context, recherche string, decalage int) ([]entreeJournal, error) {
	rows, err := a.b.pool.Query(ctx, `SELECT le, admin_email, action, ressource, cible, coalesce(details::text, '')
		FROM journal_admin WHERE $1 = '' OR admin_email ILIKE '%'||$1||'%' OR ressource ILIKE '%'||$1||'%'
		OR cible ILIKE '%'||$1||'%' OR action ILIKE '%'||$1||'%'
		ORDER BY le DESC, id DESC LIMIT $2 OFFSET $3`, recherche, tailleAdminPage, decalage)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(l pgx.CollectableRow) (entreeJournal, error) {
		var e entreeJournal
		err := l.Scan(&e.Le, &e.Admin, &e.Action, &e.Ressource, &e.Cible, &e.DetailsTxt)
		if e.DetailsTxt != "" {
			e.Details = json.RawMessage(e.DetailsTxt)
		}
		return e, err
	})
}

// ------------------------------------------------------------------ listes

const tailleAdminPage = 100

func decalageDe(curseur string) int {
	n, err := strconv.Atoi(curseur)
	if err != nil || n < 0 {
		return 0
	}
	return n
}

type utilisateurAdminJSON struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	EmailVerifie bool      `json:"emailVerifie"`
	Nom          string    `json:"nom"`
	Telephone    *string   `json:"telephone"`
	CreeLe       time.Time `json:"creeLe"`
	Bateaux      int       `json:"bateaux"`
	Contacts     int       `json:"contacts"`
}

func (a *app) utilisateursAdmin(ctx context.Context, recherche string, decalage int) ([]utilisateurAdminJSON, error) {
	rows, err := a.b.pool.Query(ctx, `SELECT u.id, u.email, u.email_verifie_le IS NOT NULL, u.nom, u.telephone, u.cree_le,
		(SELECT count(*) FROM bateaux b WHERE b.proprietaire_id = u.id),
		(SELECT count(*) FROM contacts c WHERE c.navigateur_id = u.id AND c.supprime_le IS NULL)
		FROM utilisateurs u WHERE $1 = '' OR u.email ILIKE '%'||$1||'%' OR u.nom ILIKE '%'||$1||'%'
		OR coalesce(u.telephone, '') LIKE '%'||$1||'%'
		ORDER BY u.cree_le DESC, u.id LIMIT $2 OFFSET $3`, strings.TrimSpace(recherche), tailleAdminPage, decalage)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(l pgx.CollectableRow) (utilisateurAdminJSON, error) {
		var u utilisateurAdminJSON
		err := l.Scan(&u.ID, &u.Email, &u.EmailVerifie, &u.Nom, &u.Telephone, &u.CreeLe, &u.Bateaux, &u.Contacts)
		return u, err
	})
}

type bateauAdminJSON struct {
	bateauJSON
	ProprietaireEmail string `json:"proprietaireEmail"`
}

func (a *app) bateauxAdmin(ctx context.Context, recherche, proprietaire string, decalage int) ([]bateauAdminJSON, error) {
	rows, err := a.b.pool.Query(ctx, `SELECT `+prefixer(colonnesBateau, "b.")+`, u.email
		FROM bateaux b JOIN utilisateurs u ON u.id = b.proprietaire_id
		WHERE ($1 = '' OR b.nom ILIKE '%'||$1||'%' OR b.immatriculation ILIKE '%'||$1||'%' OR u.email ILIKE '%'||$1||'%')
		AND ($2 = '' OR b.proprietaire_id::text = $2)
		ORDER BY b.nom, b.id LIMIT $3 OFFSET $4`, strings.TrimSpace(recherche), proprietaire, tailleAdminPage, decalage)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, lireBateauAdmin)
}

func lireBateauAdmin(l pgx.CollectableRow) (bateauAdminJSON, error) {
	var b bateauAdminJSON
	err := l.Scan(&b.ID, &b.ProprietaireID, &b.Nom, &b.Type, &b.LongueurMetres, &b.Immatriculation, &b.PortAttache,
		&b.Moteur, &b.Autonomie, &b.CapaciteCarburantLitres, &b.VitesseNoeuds, &b.TirantEauMetres,
		&b.AppareilAssocieID, &b.AUnePhoto, &b.ProprietaireEmail)
	return b, err
}

// prefixer : « id, nom, photo IS NOT NULL » → « b.id, b.nom, b.photo IS NOT NULL ».
func prefixer(colonnes, p string) string {
	parts := strings.Split(colonnes, ",")
	for i, c := range parts {
		parts[i] = p + strings.TrimSpace(c)
	}
	return strings.Join(parts, ", ")
}

func (a *app) bateauAdmin(ctx context.Context, id string) (bateauAdminJSON, error) {
	if !estUUID(id) {
		return bateauAdminJSON{}, errIntrouvable()
	}
	rows, err := a.b.pool.Query(ctx, `SELECT `+prefixer(colonnesBateau, "b.")+`, u.email
		FROM bateaux b JOIN utilisateurs u ON u.id = b.proprietaire_id WHERE b.id = $1`, id)
	if err != nil {
		return bateauAdminJSON{}, err
	}
	return pgx.CollectExactlyOneRow(rows, lireBateauAdmin)
}

// modifierBateauAdmin : fiche (mêmes contrôles que pour le propriétaire) et
// rattachement à un autre compte (proprietaireId ou proprietaireEmail). Au
// changement de compte, le téléphone associé, qui appartient à l'ancien
// propriétaire, est retiré (RG-BAT-02).
func (a *app) modifierBateauAdmin(ctx context.Context, id string, c champs) (bateauAdminJSON, error) {
	b, err := a.bateauAdmin(ctx, id)
	if err != nil {
		return b, err
	}
	nouveau := ""
	if c.a("proprietaireEmail") {
		var email string
		if err := c.lire("proprietaireEmail", &email); err != nil {
			return b, err
		}
		err := a.b.pool.QueryRow(ctx, "SELECT id FROM utilisateurs WHERE email = $1",
			strings.ToLower(strings.TrimSpace(email))).Scan(&nouveau)
		if errors.Is(err, pgx.ErrNoRows) {
			return b, errInvalide("Aucun compte n'a cette adresse e-mail.")
		} else if err != nil {
			return b, err
		}
	} else if c.a("proprietaireId") {
		if err := c.lire("proprietaireId", &nouveau); err != nil {
			return b, err
		}
		var existe bool
		if !estUUID(nouveau) {
			return b, errInvalide("Compte introuvable.")
		}
		if err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM utilisateurs WHERE id = $1)", nouveau).Scan(&existe); err != nil {
			return b, err
		}
		if !existe {
			return b, errInvalide("Compte introuvable.")
		}
	}
	delete(c, "proprietaireEmail")
	delete(c, "proprietaireId")
	if len(c) > 0 {
		if _, err := a.modifierBateau(ctx, b.ProprietaireID, id, c); err != nil {
			return b, err
		}
	}
	if nouveau != "" && nouveau != b.ProprietaireID {
		if _, err := a.b.pool.Exec(ctx, `UPDATE bateaux SET proprietaire_id = $2, appareil_associe_id = NULL,
			modifie_le = now() WHERE id = $1`, id, nouveau); err != nil {
			return b, err
		}
	}
	return a.bateauAdmin(ctx, id)
}

func (a *app) supprimerAdmin(ctx context.Context, table, id string) error {
	if !estUUID(id) {
		return errIntrouvable()
	}
	t, err := a.b.pool.Exec(ctx, "DELETE FROM "+table+" WHERE id = $1", id)
	if err == nil && t.RowsAffected() == 0 {
		return errIntrouvable()
	}
	return err
}

// contactAdmin : navigateur propriétaire d'un contact non supprimé.
func (a *app) navigateurDuContact(ctx context.Context, id string) (string, error) {
	if !estUUID(id) {
		return "", errIntrouvable()
	}
	var n string
	err := a.b.pool.QueryRow(ctx, "SELECT navigateur_id FROM contacts WHERE id = $1 AND supprime_le IS NULL", id).Scan(&n)
	return n, err
}

// ------------------------------------------------------------------ annonces

type annonceJSON struct {
	ID      string     `json:"id"`
	Texte   string     `json:"texte"`
	FinLe   *time.Time `json:"finLe"`
	CreeeLe time.Time  `json:"creeeLe"`
	EnCours bool       `json:"enCours"`
}

const tailleAnnonceMax = 500

func (a *app) annonces(ctx context.Context, utilisateur string) ([]annonceJSON, error) {
	rows, err := a.b.pool.Query(ctx, `SELECT n.id, n.texte, n.fin_le, n.creee_le, n.fin_le IS NULL OR n.fin_le > now()
		FROM annonces n WHERE ($1 = '' OR ((n.fin_le IS NULL OR n.fin_le > now())
			AND NOT EXISTS (SELECT 1 FROM annonces_fermees f WHERE f.annonce_id = n.id AND f.utilisateur_id::text = $1)))
		ORDER BY n.creee_le DESC, n.id`, utilisateur)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(l pgx.CollectableRow) (annonceJSON, error) {
		var n annonceJSON
		err := l.Scan(&n.ID, &n.Texte, &n.FinLe, &n.CreeeLe, &n.EnCours)
		return n, err
	})
}

// appliquerAnnonce : texte (500 caractères au plus) et date de fin, null :
// jusqu'à sa fermeture par l'utilisateur (RG-ADM-06).
func appliquerAnnonce(n *annonceJSON, c champs, creation bool) error {
	if c.a("texte") || creation {
		if err := c.lire("texte", &n.Texte); err != nil {
			return err
		}
		n.Texte = strings.TrimSpace(n.Texte)
		if n.Texte == "" || len([]rune(n.Texte)) > tailleAnnonceMax {
			return errInvalide("Le texte de l'annonce est obligatoire (500 caractères au plus).")
		}
	}
	if c.a("finLe") {
		if err := c.lire("finLe", &n.FinLe); err != nil {
			return err
		}
	}
	return nil
}

func (a *app) creerAnnonce(ctx context.Context, s *sessionAdmin, c champs) (annonceJSON, error) {
	var n annonceJSON
	if err := appliquerAnnonce(&n, c, true); err != nil {
		return n, err
	}
	err := a.b.pool.QueryRow(ctx, `INSERT INTO annonces (texte, fin_le, creee_par) VALUES ($1, $2, $3)
		RETURNING id, creee_le, fin_le IS NULL OR fin_le > now()`, n.Texte, n.FinLe, s.email).Scan(&n.ID, &n.CreeeLe, &n.EnCours)
	return n, err
}

func (a *app) modifierAnnonce(ctx context.Context, id string, c champs) (annonceJSON, error) {
	var n annonceJSON
	if !estUUID(id) {
		return n, errIntrouvable()
	}
	err := a.b.pool.QueryRow(ctx, "SELECT id, texte, fin_le, creee_le FROM annonces WHERE id = $1", id).Scan(
		&n.ID, &n.Texte, &n.FinLe, &n.CreeeLe)
	if err != nil {
		return n, err
	}
	if err := appliquerAnnonce(&n, c, false); err != nil {
		return n, err
	}
	err = a.b.pool.QueryRow(ctx, `UPDATE annonces SET texte = $2, fin_le = $3 WHERE id = $1
		RETURNING fin_le IS NULL OR fin_le > now()`, id, n.Texte, n.FinLe).Scan(&n.EnCours)
	return n, err
}

func (a *app) fermerAnnonce(ctx context.Context, utilisateur, id string) error {
	if !estUUID(id) {
		return errIntrouvable()
	}
	t, err := a.b.pool.Exec(ctx, `INSERT INTO annonces_fermees (annonce_id, utilisateur_id)
		SELECT id, $2 FROM annonces WHERE id = $1 ON CONFLICT DO NOTHING`, id, utilisateur)
	if err != nil {
		return err
	}
	if t.RowsAffected() == 0 {
		var existe bool
		if err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM annonces WHERE id = $1)", id).Scan(&existe); err != nil {
			return err
		}
		if !existe {
			return errIntrouvable()
		}
	}
	return nil
}

// ------------------------------------------------------------------ statistiques et supervision

type statistiquesJSON struct {
	Utilisateurs         int `json:"utilisateurs"`
	EmailsConfirmes      int `json:"emailsConfirmes"`
	Inscrits7Jours       int `json:"inscrits7Jours"`
	Actifs30Jours        int `json:"actifs30Jours"`
	Bateaux              int `json:"bateaux"`
	BateauxAvecTelephone int `json:"bateauxAvecTelephone"`
	Contacts             int `json:"contacts"`
	Suiveurs             int `json:"suiveurs"`
	AnnoncesEnCours      int `json:"annoncesEnCours"`
}

func (a *app) statistiques(ctx context.Context) (statistiquesJSON, error) {
	var s statistiquesJSON
	err := a.b.pool.QueryRow(ctx, `SELECT
		(SELECT count(*) FROM utilisateurs),
		(SELECT count(*) FROM utilisateurs WHERE email_verifie_le IS NOT NULL),
		(SELECT count(*) FROM utilisateurs WHERE cree_le > now() - interval '7 days'),
		(SELECT count(DISTINCT utilisateur_id) FROM sessions WHERE derniere_utilisation > now() - interval '30 days'),
		(SELECT count(*) FROM bateaux),
		(SELECT count(*) FROM bateaux WHERE appareil_associe_id IS NOT NULL),
		(SELECT count(*) FROM contacts WHERE supprime_le IS NULL),
		(SELECT count(*) FROM acces),
		(SELECT count(*) FROM annonces WHERE fin_le IS NULL OR fin_le > now())`).Scan(
		&s.Utilisateurs, &s.EmailsConfirmes, &s.Inscrits7Jours, &s.Actifs30Jours, &s.Bateaux, &s.BateauxAvecTelephone,
		&s.Contacts, &s.Suiveurs, &s.AnnoncesEnCours)
	return s, err
}

var demarreLe = time.Now()

type supervisionJSON struct {
	Version         string    `json:"version"`
	Base            string    `json:"base"`
	Schema          int       `json:"schema"`
	DemarreLe       time.Time `json:"demarreLe"`
	SessionsWeb     int       `json:"sessionsWeb"`
	SessionsMobiles int       `json:"sessionsMobiles"`
}

// supervision : état du serveur. Erreurs, incidents et synchronisations
// (RG-ADM-02) restent à faire : les journaux techniques ne sont pas encore
// gardés en base.
func (a *app) supervision(ctx context.Context) (supervisionJSON, error) {
	s := supervisionJSON{Version: version, Base: a.b.etat(ctx), DemarreLe: demarreLe.UTC().Truncate(time.Second)}
	err := a.b.pool.QueryRow(ctx, `SELECT (SELECT coalesce(max(version), 0) FROM schema_migrations),
		(SELECT count(*) FROM sessions WHERE support = 'web'), (SELECT count(*) FROM sessions WHERE support = 'mobile')`).Scan(
		&s.Schema, &s.SessionsWeb, &s.SessionsMobiles)
	return s, err
}
