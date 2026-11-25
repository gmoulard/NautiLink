package main

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Mot de passe oublié (TODO-4.1, RG-CPT-10) : lien envoyé par e-mail, valable
// 1 heure et à usage unique ; le nouveau mot de passe ferme toutes les
// sessions du compte.

var errLienMotDePasse = &erreurAPI{http.StatusNotFound, "introuvable",
	"Ce lien n'est plus valable : demandez-en un nouveau avec « Mot de passe oublié ? ».", 0}

// demanderNouveauMotDePasse : envoie le lien à un compte inscrit par e-mail
// (avec un mot de passe). La réponse est la même que l'adresse ait un compte
// ou non, pour ne pas dire quelles adresses sont inscrites.
func (a *app) demanderNouveauMotDePasse(ctx context.Context, r *http.Request, email string) error {
	email = strings.ToLower(strings.TrimSpace(email))
	cleIP := "mdp-ip:" + adresseClient(r)
	if attente := a.limInscription.bloque(cleIP); attente > 0 {
		return errTropDEssais(attente)
	}
	a.limInscription.noter(cleIP)
	var id, nom string
	err := a.b.pool.QueryRow(ctx, "SELECT id, nom FROM utilisateurs WHERE email = $1 AND mot_de_passe <> ''",
		email).Scan(&id, &nom)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	cle := "mdp:" + id
	if a.limEnvoi.bloque(cle) > 0 {
		return nil
	}
	a.limEnvoi.noter(cle)
	jeton := nouveauJeton()
	if _, err := a.b.pool.Exec(ctx, `INSERT INTO jetons_email (jeton, utilisateur_id, objet, email, expire_le)
		VALUES ($1, $2, 'mot_de_passe', $3, $4)`, empreinte(jeton), id, email, time.Now().Add(dureeLienMotDePasse)); err != nil {
		return err
	}
	a.courriel(email, "NautiLink : choisir un nouveau mot de passe",
		"Bonjour "+nom+",\n\nPour choisir un nouveau mot de passe pour votre compte NautiLink, ouvrez ce lien :\n\n"+
			a.adressePublique(r)+"/mot-de-passe?jeton="+jeton+"\n\n"+
			"Ce lien est valable 1 heure et ne sert qu'une fois. Après le changement, reconnectez-vous "+
			"sur chacun de vos appareils.\n\n"+
			"Si vous n'avez rien demandé, ignorez cet e-mail : votre mot de passe ne change pas.\n\n"+
			"NautiLink — Version bêta\n")
	return nil
}

// lienMotDePasseValable : vrai si le lien peut encore servir (page Web).
func (a *app) lienMotDePasseValable(ctx context.Context, jeton string) (bool, error) {
	var ok bool
	err := a.b.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM jetons_email j JOIN utilisateurs u ON u.id = j.utilisateur_id
		WHERE j.jeton = $1 AND j.objet = 'mot_de_passe' AND j.utilise_le IS NULL AND j.expire_le > now() AND u.email = j.email)`,
		empreinte(jeton)).Scan(&ok)
	return ok, err
}

// changerMotDePasseOublie : consomme le lien, change le mot de passe et ferme
// toutes les sessions du compte.
func (a *app) changerMotDePasseOublie(ctx context.Context, jeton, mdp string) error {
	if err := validerMotDePasse(mdp); err != nil {
		return err
	}
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	var id, email string
	err = tx.QueryRow(ctx, `WITH j AS (
			UPDATE jetons_email SET utilise_le = now()
			WHERE jeton = $1 AND objet = 'mot_de_passe' AND utilise_le IS NULL AND expire_le > now()
			RETURNING utilisateur_id, email)
		UPDATE utilisateurs u SET mot_de_passe = $2
		FROM j WHERE u.id = j.utilisateur_id AND u.email = j.email RETURNING u.id, u.email`,
		empreinte(jeton), hacherMotDePasse(mdp)).Scan(&id, &email)
	if errors.Is(err, pgx.ErrNoRows) {
		return errLienMotDePasse
	}
	if err != nil {
		return err
	}
	// Les autres liens encore valables ne servent plus.
	if _, err := tx.Exec(ctx, `UPDATE jetons_email SET utilise_le = now()
		WHERE utilisateur_id = $1 AND objet = 'mot_de_passe' AND utilise_le IS NULL`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, "DELETE FROM sessions WHERE utilisateur_id = $1", id); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	a.limConnexionEmail.oublier("email:" + email)
	return nil
}

// ------------------------------------------------------------------ API

func (a *app) routesMotDePasse(mux *http.ServeMux, v string) {
	mux.HandleFunc("POST "+v+"/compte/mot-de-passe/oubli", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		var c struct{ Email string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		if err := a.demanderNouveauMotDePasse(r.Context(), r, c.Email); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("POST "+v+"/compte/mot-de-passe", a.api(false, func(w http.ResponseWriter, r *http.Request, _ *session) error {
		var c struct{ Jeton, MotDePasse string }
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		if err := a.changerMotDePasseOublie(r.Context(), c.Jeton, c.MotDePasse); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
}

// ------------------------------------------------------------------ Web

func (a *app) routesWebMotDePasse(mux *http.ServeMux, c string) {
	mux.HandleFunc("GET "+c+"/mot-de-passe-oublie", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		d.Titre = "Mot de passe oublié"
		a.rendre(w, "mot-de-passe-oublie.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/mot-de-passe-oublie", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		d.Titre, d.F["email"] = "Mot de passe oublié", r.FormValue("email")
		if err := a.demanderNouveauMotDePasse(r.Context(), r, r.FormValue("email")); err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			w.WriteHeader(http.StatusTooManyRequests)
		} else {
			d.Message = "Si un compte existe avec cette adresse, un e-mail vient de lui être envoyé avec un lien valable 1 heure."
		}
		a.rendre(w, "mot-de-passe-oublie.html", d)
		return nil
	}))

	mux.HandleFunc("GET "+c+"/mot-de-passe", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		jeton := r.URL.Query().Get("jeton")
		ok, err := a.lienMotDePasseValable(r.Context(), jeton)
		if err != nil {
			return err
		}
		if !ok {
			return errLienMotDePasse
		}
		d.Titre, d.D = "Nouveau mot de passe", jeton
		a.rendre(w, "mot-de-passe.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/mot-de-passe", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		jeton := r.FormValue("jeton")
		err := a.changerMotDePasseOublie(r.Context(), jeton, r.FormValue("motdepasse"))
		if err == nil {
			a.effacerCookie(w)
			http.Redirect(w, r, c+"/connexion?ok=motdepasse", http.StatusSeeOther)
			return nil
		}
		if err == errLienMotDePasse {
			return err
		}
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnprocessableEntity)
		d.Titre, d.D = "Nouveau mot de passe", jeton
		a.rendre(w, "mot-de-passe.html", d)
		return nil
	}))
}
