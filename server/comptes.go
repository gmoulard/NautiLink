package main

import (
	"context"
	"errors"
	"net/http"
	"net/mail"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Comptes et connexion (TODO-4.1) : RG-CPT-01, RG-CPT-02, RG-CPT-06,
// RG-CPT-07 à RG-CPT-11, RG-SMS-01, RG-PRM-03, RG-NOT-04.

// Avertissement bêta en vigueur (docs/textes/avertissement-beta.md, recopié
// sur le site de présentation). Le changer fait de nouveau accepter le texte
// à la connexion suivante (RG-CPT-07).
const (
	versionAvertissement = "2026-11-24"
	adresseAvertissement = "https://gmoulard.github.io/NautiLink/avertissement.html"
	// Validité du lien de vérification de l'adresse e-mail (RG-CPT-09) et
	// de celui du mot de passe oublié (RG-CPT-10).
	dureeLienVerification = 7 * 24 * time.Hour
	dureeLienMotDePasse   = time.Hour
)

var (
	errEmailDejaUtilise = &erreurAPI{http.StatusConflict, "email_deja_utilise",
		"Un compte existe déjà avec cette adresse e-mail.", 0}
	errIdentifiants = &erreurAPI{http.StatusUnauthorized, "non_authentifie",
		"Adresse e-mail ou mot de passe incorrect.", 0}
	errAvertissement = &erreurAPI{http.StatusPreconditionRequired, "avertissement_a_accepter",
		"Lisez et acceptez l'avertissement bêta pour continuer.", 0}
	reTelephone = regexp.MustCompile(`^\+[1-9][0-9]{6,14}$`)
)

func normaliserEmail(s string) (string, error) {
	s = strings.ToLower(strings.TrimSpace(s))
	adr, err := mail.ParseAddress(s)
	if err != nil || adr.Address != s || len(s) > 254 || strings.ContainsAny(s, " \r\n") {
		return "", errInvalide("Adresse e-mail invalide.")
	}
	return s, nil
}

// normaliserTelephone : numéro au format international E.164 (+33612345678),
// espaces, points et tirets retirés ; un numéro français 06… devient +336….
func normaliserTelephone(s string) (string, error) {
	s = strings.NewReplacer(" ", "", ".", "", "-", "", "(", "", ")", "").Replace(strings.TrimSpace(s))
	if strings.HasPrefix(s, "00") {
		s = "+" + s[2:]
	} else if len(s) == 10 && strings.HasPrefix(s, "0") {
		s = "+33" + s[1:]
	}
	if !reTelephone.MatchString(s) {
		return "", errInvalide("Numéro de téléphone invalide : écrivez-le au format international, par exemple +33 6 12 34 56 78.")
	}
	return s, nil
}

func validerMotDePasse(mdp string) error {
	if len([]rune(mdp)) < 8 || len(mdp) > 256 {
		return errInvalide("Le mot de passe doit faire au moins 8 caractères.")
	}
	return nil
}

func validerNom(nom string) (string, error) {
	nom = strings.TrimSpace(nom)
	if nom == "" || len([]rune(nom)) > 100 || strings.ContainsAny(nom, "\r\n") {
		return "", errInvalide("Indiquez votre nom (100 caractères au plus).")
	}
	return nom, nil
}

// langueDe : langue demandée, sinon celle du navigateur Internet ou du
// téléphone (en-tête Accept-Language), sinon le français (RG-PRM-03, D-93).
func langueDe(demandee string, r *http.Request) string {
	if demandee == "fr" || demandee == "en" {
		return demandee
	}
	if strings.HasPrefix(strings.ToLower(strings.TrimSpace(r.Header.Get("Accept-Language"))), "en") {
		return "en"
	}
	return "fr"
}

func estDoublon(err error) bool {
	var pe *pgconn.PgError
	return errors.As(err, &pe) && pe.Code == "23505"
}

// creerCompte : compte par e-mail et mot de passe ; refusé sans acceptation
// de la version en vigueur de l'avertissement bêta (RG-CPT-06).
func (a *app) creerCompte(ctx context.Context, r *http.Request, email, mdp, nom, langue, avertissement string) (string, error) {
	if avertissement != versionAvertissement {
		return "", &erreurAPI{http.StatusUnprocessableEntity, "avertissement_a_accepter",
			"Lisez et acceptez l'avertissement bêta pour créer votre compte.", 0}
	}
	email, err := normaliserEmail(email)
	if err != nil {
		return "", err
	}
	if nom, err = validerNom(nom); err != nil {
		return "", err
	}
	if err := validerMotDePasse(mdp); err != nil {
		return "", err
	}
	ip := "ip:" + adresseClient(r)
	if attente := a.limInscription.bloque(ip); attente > 0 {
		return "", errTropDEssais(attente)
	}
	a.limInscription.noter(ip)
	var id string
	err = a.b.pool.QueryRow(ctx, `WITH u AS (INSERT INTO utilisateurs (email, mot_de_passe, nom, langue, avertissement_version, avertissement_accepte_le)
		VALUES ($1, $2, $3, $4, $5, now()) RETURNING id), p AS (`+parametresNouveauCompte+`)
		SELECT id FROM u`, email, hacherMotDePasse(mdp), nom, langueDe(langue, r), avertissement).Scan(&id)
	if estDoublon(err) {
		return "", errEmailDejaUtilise
	}
	if err != nil {
		return "", err
	}
	return id, a.envoyerVerification(ctx, r, id)
}

// envoyerVerification : e-mail portant le lien de vérification de l'adresse.
func (a *app) envoyerVerification(ctx context.Context, r *http.Request, utilisateur string) error {
	var email, nom string
	var verifie *time.Time
	if err := a.b.pool.QueryRow(ctx, "SELECT email, nom, email_verifie_le FROM utilisateurs WHERE id = $1",
		utilisateur).Scan(&email, &nom, &verifie); err != nil {
		return err
	}
	if verifie != nil {
		return nil
	}
	cle := "verif:" + utilisateur
	if attente := a.limEnvoi.bloque(cle); attente > 0 {
		return errTropDEssais(attente)
	}
	a.limEnvoi.noter(cle)
	jeton := nouveauJeton()
	if _, err := a.b.pool.Exec(ctx, `INSERT INTO jetons_email (jeton, utilisateur_id, objet, email, expire_le)
		VALUES ($1, $2, 'verification', $3, $4)`, empreinte(jeton), utilisateur, email, time.Now().Add(dureeLienVerification)); err != nil {
		return err
	}
	a.courriel(email, "NautiLink : confirmez votre adresse e-mail",
		"Bonjour "+nom+",\n\nPour confirmer l'adresse e-mail de votre compte NautiLink, ouvrez ce lien :\n\n"+
			a.adressePublique(r)+"/verification?jeton="+jeton+"\n\n"+
			"Ce lien est valable 7 jours. Si vous n'avez pas créé de compte NautiLink, ignorez cet e-mail.\n\n"+
			"NautiLink — Version bêta\n")
	return nil
}

// verifierEmail : consomme le jeton du lien et marque l'adresse vérifiée.
func (a *app) verifierEmail(ctx context.Context, jeton string) (string, error) {
	var id string
	err := a.b.pool.QueryRow(ctx, `WITH j AS (
			UPDATE jetons_email SET utilise_le = now()
			WHERE jeton = $1 AND objet = 'verification' AND utilise_le IS NULL AND expire_le > now()
			RETURNING utilisateur_id, email)
		UPDATE utilisateurs u SET email_verifie_le = coalesce(u.email_verifie_le, now())
		FROM j WHERE u.id = j.utilisateur_id AND u.email = j.email RETURNING u.id`, empreinte(jeton)).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", &erreurAPI{http.StatusNotFound, "introuvable",
			"Ce lien n'est plus valable. Connectez-vous pour en recevoir un nouveau.", 0}
	}
	return id, err
}

// connexionEmail : vérifie l'e-mail et le mot de passe, avec la protection
// contre les essais répétés ; demande l'acceptation de l'avertissement s'il a
// changé depuis la dernière acceptation (RG-CPT-07).
func (a *app) connexionEmail(ctx context.Context, r *http.Request, email, mdp, avertissement string) (string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	cleEmail, cleIP := "email:"+email, "ip:"+adresseClient(r)
	for _, l := range []struct {
		l *limiteur
		c string
	}{{a.limConnexionEmail, cleEmail}, {a.limConnexionIP, cleIP}} {
		if attente := l.l.bloque(l.c); attente > 0 {
			return "", errTropDEssais(attente)
		}
	}
	var id, hache, version string
	err := a.b.pool.QueryRow(ctx, "SELECT id, mot_de_passe, avertissement_version FROM utilisateurs WHERE email = $1",
		email).Scan(&id, &hache, &version)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}
	if !verifierMotDePasse(hache, mdp) {
		a.limConnexionEmail.noter(cleEmail)
		a.limConnexionIP.noter(cleIP)
		return "", errIdentifiants
	}
	a.limConnexionEmail.oublier(cleEmail)
	return id, a.accepterAvertissementSiBesoin(ctx, id, version, avertissement)
}

func (a *app) accepterAvertissementSiBesoin(ctx context.Context, id, accepte, avertissement string) error {
	if accepte == versionAvertissement {
		return nil
	}
	if avertissement != versionAvertissement {
		return errAvertissement
	}
	_, err := a.b.pool.Exec(ctx, `UPDATE utilisateurs SET avertissement_version = $2, avertissement_accepte_le = now()
		WHERE id = $1`, id, versionAvertissement)
	return err
}

// connexionExterne : connexion par Google ou par Apple ; la première crée le
// compte, avec la même acceptation de l'avertissement. L'adresse d'un compte
// NautiLink existant y est rattachée si le fournisseur la garantit vérifiée,
// sinon refusée (RG-CPT-11).
func (a *app) connexionExterne(ctx context.Context, r *http.Request, fournisseur, jeton, avertissement, nom string) (string, error) {
	v, ok := a.verificateurs[fournisseur]
	if !ok {
		return "", &erreurAPI{http.StatusNotImplemented, "fournisseur_indisponible",
			"La connexion par ce fournisseur n'est pas encore disponible.", 0}
	}
	idt, err := v.verifier(ctx, jeton)
	if err != nil {
		return "", errNonAuthentifie()
	}
	var id, version string
	err = a.b.pool.QueryRow(ctx, `SELECT u.id, u.avertissement_version FROM identites_externes i
		JOIN utilisateurs u ON u.id = i.utilisateur_id WHERE i.fournisseur = $1 AND i.sujet = $2`,
		fournisseur, idt.Sujet).Scan(&id, &version)
	if err == nil {
		return id, a.accepterAvertissementSiBesoin(ctx, id, version, avertissement)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}
	email, err := normaliserEmail(idt.Email)
	if err != nil {
		return "", errInvalide("Le fournisseur n'a pas donné d'adresse e-mail.")
	}
	err = a.b.pool.QueryRow(ctx, "SELECT id, avertissement_version FROM utilisateurs WHERE email = $1",
		email).Scan(&id, &version)
	if err == nil {
		return id, a.rattacherIdentite(ctx, fournisseur, idt, id, version, avertissement)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}
	if avertissement != versionAvertissement {
		return "", errAvertissement
	}
	if strings.TrimSpace(nom) == "" {
		nom = idt.Nom
	}
	if strings.TrimSpace(nom) == "" {
		nom = strings.SplitN(email, "@", 2)[0]
	}
	if nom, err = validerNom(nom); err != nil {
		return "", err
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)
	var verifie *time.Time
	if idt.EmailVerifie {
		maint := time.Now()
		verifie = &maint
	}
	err = tx.QueryRow(ctx, `WITH u AS (INSERT INTO utilisateurs (email, email_verifie_le, nom, langue, avertissement_version, avertissement_accepte_le)
		VALUES ($1, $2, $3, $4, $5, now()) RETURNING id), p AS (`+parametresNouveauCompte+`)
		SELECT id FROM u`, email, verifie, nom, langueDe("", r), avertissement).Scan(&id)
	if estDoublon(err) {
		return "", errEmailDejaUtilise
	}
	if err != nil {
		return "", err
	}
	if _, err := tx.Exec(ctx, "INSERT INTO identites_externes (fournisseur, sujet, utilisateur_id) VALUES ($1, $2, $3)",
		fournisseur, idt.Sujet, id); err != nil {
		return "", err
	}
	return id, tx.Commit(ctx)
}

// rattacherIdentite : identité Google ou Apple rattachée au compte existant
// de même adresse, seulement si le fournisseur garantit l'adresse vérifiée
// (RG-CPT-11) ; l'adresse du compte est alors tenue pour confirmée.
func (a *app) rattacherIdentite(ctx context.Context, fournisseur string, idt identiteExterne, id, version, avertissement string) error {
	if !idt.EmailVerifie {
		return &erreurAPI{http.StatusConflict, "email_deja_utilise",
			"Un compte existe déjà avec cette adresse e-mail : connectez-vous avec votre adresse e-mail et votre mot de passe.", 0}
	}
	if err := a.accepterAvertissementSiBesoin(ctx, id, version, avertissement); err != nil {
		return err
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `INSERT INTO identites_externes (fournisseur, sujet, utilisateur_id) VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING`, fournisseur, idt.Sujet, id); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, "UPDATE utilisateurs SET email_verifie_le = coalesce(email_verifie_le, now()) WHERE id = $1", id); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// ------------------------------------------------------------------ profil

type pushJSON struct {
	Debut            bool `json:"debut"`
	Fin              bool `json:"fin"`
	Photo            bool `json:"photo"`
	PositionEnRetard bool `json:"positionEnRetard"`
}

type profilJSON struct {
	ID                           string    `json:"id"`
	Email                        string    `json:"email"`
	EmailVerifie                 bool      `json:"emailVerifie"`
	Nom                          string    `json:"nom"`
	Telephone                    *string   `json:"telephone"`
	RecevoirSms                  bool      `json:"recevoirSms"`
	Langue                       string    `json:"langue"`
	EmailsDebut                  bool      `json:"emailsDebut"`
	Push                         pushJSON  `json:"push"`
	AvertissementVersionAcceptee string    `json:"avertissementVersionAcceptee"`
	AvertissementAccepteLe       time.Time `json:"avertissementAccepteLe"`
}

func (a *app) profil(ctx context.Context, id string) (profilJSON, error) {
	var p profilJSON
	var verifie *time.Time
	err := a.b.pool.QueryRow(ctx, `SELECT id, email, email_verifie_le, nom, telephone, recevoir_sms, langue,
		emails_debut, push_debut, push_fin, push_photo, push_position_en_retard,
		avertissement_version, avertissement_accepte_le FROM utilisateurs WHERE id = $1`, id).Scan(
		&p.ID, &p.Email, &verifie, &p.Nom, &p.Telephone, &p.RecevoirSms, &p.Langue, &p.EmailsDebut,
		&p.Push.Debut, &p.Push.Fin, &p.Push.Photo, &p.Push.PositionEnRetard,
		&p.AvertissementVersionAcceptee, &p.AvertissementAccepteLe)
	p.EmailVerifie = verifie != nil
	return p, err
}

// modifierProfil : seuls les champs présents changent (RG-COM-04). « Recevoir
// les SMS » passe à vrai quand un numéro est renseigné pour la première fois
// (RG-SMS-01). Les désinscriptions valent pour tous les navigateurs suivis
// (RG-NOT-04) ; le SOS n'est pas désactivable (RG-NOT-02, RG-IOS-06).
func (a *app) modifierProfil(ctx context.Context, id string, c champs) (profilJSON, error) {
	p, err := a.profil(ctx, id)
	if err != nil {
		return p, err
	}
	if c.a("nom") {
		if err := c.lire("nom", &p.Nom); err != nil {
			return p, err
		}
		if p.Nom, err = validerNom(p.Nom); err != nil {
			return p, err
		}
	}
	if c.a("telephone") {
		var t *string
		if err := c.lire("telephone", &t); err != nil {
			return p, err
		}
		if t != nil && strings.TrimSpace(*t) == "" {
			t = nil
		}
		if t != nil {
			n, err := normaliserTelephone(*t)
			if err != nil {
				return p, err
			}
			if p.Telephone == nil && !c.a("recevoirSms") {
				p.RecevoirSms = true
			}
			t = &n
		}
		p.Telephone = t
	}
	if c.a("recevoirSms") {
		if err := c.lire("recevoirSms", &p.RecevoirSms); err != nil {
			return p, err
		}
	}
	if c.a("langue") {
		if err := c.lire("langue", &p.Langue); err != nil || (p.Langue != "fr" && p.Langue != "en") {
			return p, errInvalide("Langue invalide : fr ou en.")
		}
	}
	if c.a("emailsDebut") {
		if err := c.lire("emailsDebut", &p.EmailsDebut); err != nil {
			return p, err
		}
	}
	if c.a("push") {
		var push champs
		if err := c.lire("push", &push); err != nil {
			return p, err
		}
		for nom, v := range map[string]*bool{"debut": &p.Push.Debut, "fin": &p.Push.Fin,
			"photo": &p.Push.Photo, "positionEnRetard": &p.Push.PositionEnRetard} {
			if push.a(nom) {
				if err := push.lire(nom, v); err != nil {
					return p, err
				}
			}
		}
	}
	_, err = a.b.pool.Exec(ctx, `UPDATE utilisateurs SET nom = $2, telephone = $3, recevoir_sms = $4, langue = $5,
		emails_debut = $6, push_debut = $7, push_fin = $8, push_photo = $9, push_position_en_retard = $10
		WHERE id = $1`, id, p.Nom, p.Telephone, p.RecevoirSms, p.Langue, p.EmailsDebut,
		p.Push.Debut, p.Push.Fin, p.Push.Photo, p.Push.PositionEnRetard)
	return p, err
}

// ------------------------------------------------------------------ routes de l'API

func (a *app) routesComptes(mux *http.ServeMux, v string) {
	a.routesMotDePasse(mux, v)

	mux.HandleFunc("GET "+v+"/avertissement", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		ecrireJSON(w, http.StatusOK, map[string]string{"version": versionAvertissement, "adresseTexte": adresseAvertissement})
		return nil
	}))

	mux.HandleFunc("POST "+v+"/comptes", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		var c struct{ Email, MotDePasse, Nom, Langue, AvertissementVersion string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		id, err := a.creerCompte(r.Context(), r, c.Email, c.MotDePasse, c.Nom, c.Langue, c.AvertissementVersion)
		if err != nil {
			return err
		}
		acces, renouv, err := a.ouvrirSession(r.Context(), id, "mobile", true)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusCreated, nouvelleSessionJSON(acces, renouv))
		return nil
	}))

	mux.HandleFunc("POST "+v+"/sessions", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		var c struct{ Email, MotDePasse, Fournisseur, JetonIdentite, AvertissementVersion, Nom string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		var id string
		var err error
		if c.Fournisseur != "" {
			id, err = a.connexionExterne(r.Context(), r, c.Fournisseur, c.JetonIdentite, c.AvertissementVersion, c.Nom)
		} else {
			id, err = a.connexionEmail(r.Context(), r, c.Email, c.MotDePasse, c.AvertissementVersion)
		}
		if err != nil {
			return err
		}
		acces, renouv, err := a.ouvrirSession(r.Context(), id, "mobile", true)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, nouvelleSessionJSON(acces, renouv))
		return nil
	}))

	mux.HandleFunc("POST "+v+"/sessions/renouvellement", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		var c struct{ JetonRenouvellement string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		acces, renouv := nouveauJeton(), nouveauJeton()
		var derniere time.Time
		var appareil *string
		var id string
		err := a.b.pool.QueryRow(r.Context(), `SELECT id, derniere_utilisation, appareil_id FROM sessions
			WHERE jeton_renouvellement = $1`, empreinte(c.JetonRenouvellement)).Scan(&id, &derniere, &appareil)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNonAuthentifie()
		}
		if err != nil {
			return err
		}
		if time.Since(derniere) > dureeSansUsage && !(appareil != nil && a.navigationEnCoursSurAppareil(r.Context(), *appareil)) {
			_, _ = a.b.pool.Exec(r.Context(), "DELETE FROM sessions WHERE id = $1", id)
			return errNonAuthentifie()
		}
		if _, err := a.b.pool.Exec(r.Context(), `UPDATE sessions SET jeton_acces = $2, jeton_renouvellement = $3,
			derniere_utilisation = now() WHERE id = $1`, id, empreinte(acces), empreinte(renouv)); err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, nouvelleSessionJSON(acces, renouv))
		return nil
	}))

	mux.HandleFunc("DELETE "+v+"/sessions/courante", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		// La file d'attente du téléphone n'est pas touchée (RG-CPT-08).
		if _, err := a.b.pool.Exec(r.Context(), "DELETE FROM sessions WHERE id = $1", s.id); err != nil {
			return err
		}
		if s.parCookie {
			a.effacerCookie(w)
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/compte", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		p, err := a.profil(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, p)
		return nil
	}))

	mux.HandleFunc("PATCH "+v+"/compte", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		p, err := a.modifierProfil(r.Context(), s.utilisateur, c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, p)
		return nil
	}))

	mux.HandleFunc("POST "+v+"/compte/avertissement", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c struct{ Version string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		if c.Version != versionAvertissement {
			return &erreurAPI{http.StatusConflict, "avertissement_a_accepter",
				"Cette version de l'avertissement n'est plus en vigueur.", 0}
		}
		if err := a.accepterAvertissementSiBesoin(r.Context(), s.utilisateur, "", c.Version); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("POST "+v+"/compte/verification", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		var c struct{ Jeton string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		if _, err := a.verifierEmail(r.Context(), c.Jeton); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("POST "+v+"/compte/verification/envoi", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if err := a.envoyerVerification(r.Context(), r, s.utilisateur); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
}
