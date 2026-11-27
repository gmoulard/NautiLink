package main

import (
	"context"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"
)

// Plusieurs téléphones d'un même compte dans une navigation (TODO-4.14,
// RG-NAV-03, RG-NAV-39, D-177) : un téléphone du compte rejoint la
// navigation en cours d'un bateau du compte et y envoie positions manuelles,
// notes, photos, notes vocales et SOS. La navigation appartient au compte,
// pas à un téléphone : le serveur ne refuse aucun envoi d'un téléphone du
// compte (D-182) ; c'est l'application qui n'envoie pas de positions
// automatiques depuis un téléphone qui a rejoint. Un téléphone a au plus une
// navigation en cours, démarrée ou rejointe ; un compte peut en avoir
// plusieurs.

func errTelephoneOccupe() error {
	return &erreurAPI{http.StatusConflict, "navigation_en_cours", "Ce téléphone a déjà une navigation en cours.", 0}
}

// verrouTelephone : un téléphone à la fois démarre ou rejoint une
// navigation, pour que deux demandes simultanées ne lui en donnent pas deux.
func verrouTelephone(ctx context.Context, tx pgx.Tx, appareil string) error {
	_, err := tx.Exec(ctx, "SELECT pg_advisory_xact_lock(hashtext('telephone:' || lower($1)))", appareil)
	return err
}

// telephoneOccupe : le téléphone a une navigation en cours autre que sauf,
// démarrée ou rejointe (RG-NAV-03).
func telephoneOccupe(ctx context.Context, tx pgx.Tx, appareil, sauf string) (bool, error) {
	var occupe bool
	err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM navigations WHERE appareil_id = $1::uuid AND fin_enregistree IS NULL AND id <> $2::uuid)
		OR EXISTS (SELECT 1 FROM navigations_rejointes r JOIN navigations m ON m.id = r.navigation_id
			WHERE r.appareil_id = $1::uuid AND m.fin_enregistree IS NULL AND m.id <> $2::uuid)`, appareil, sauf).Scan(&occupe)
	return occupe, err
}

// rejoindre : PUT /v1/navigations/{id}/rejoindre : le téléphone rejoint la
// navigation en cours d'un bateau du compte, sans lui être associé
// (RG-NAV-39). Rend 201 (rejointe), 200 (déjà rejointe, ou téléphone qui
// l'a démarrée) et la navigation.
func (a *app) rejoindre(ctx context.Context, utilisateur, id, appareil string) (int, navigationJSON, error) {
	if !estUUID(appareil) {
		return 0, navigationJSON{}, errInvalide("Identifiant de téléphone invalide.")
	}
	n, err := a.navigationDuNavigateur(ctx, utilisateur, id)
	if err != nil {
		return 0, navigationJSON{}, err
	}
	var connu bool
	if err := a.b.pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM appareils WHERE id = $1 AND utilisateur_id = $2)",
		appareil, utilisateur).Scan(&connu); err != nil {
		return 0, navigationJSON{}, err
	}
	if !connu {
		return 0, navigationJSON{}, errInterdit("telephone_inconnu", "Ce téléphone n'est pas enregistré sur votre compte.")
	}
	if !n.enCours() {
		return 0, navigationJSON{}, &erreurAPI{http.StatusConflict, "navigation_terminee", "Cette navigation est terminée.", 0}
	}
	statut := http.StatusOK
	if !strings.EqualFold(n.appareil, appareil) {
		tx, err := a.b.pool.Begin(ctx)
		if err != nil {
			return 0, navigationJSON{}, err
		}
		defer tx.Rollback(ctx)
		if err := verrouTelephone(ctx, tx, appareil); err != nil {
			return 0, navigationJSON{}, err
		}
		if occupe, err := telephoneOccupe(ctx, tx, appareil, id); err != nil {
			return 0, navigationJSON{}, err
		} else if occupe {
			return 0, navigationJSON{}, errTelephoneOccupe()
		}
		tag, err := tx.Exec(ctx, `INSERT INTO navigations_rejointes (navigation_id, appareil_id) VALUES ($1, $2)
			ON CONFLICT DO NOTHING`, id, appareil)
		if err != nil {
			return 0, navigationJSON{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return 0, navigationJSON{}, err
		}
		if tag.RowsAffected() == 1 {
			statut = http.StatusCreated
		}
	}
	r, err := a.detailler(ctx, n, "navigateur")
	return statut, r, err
}

// telephonesRejoints : téléphones qui ont rejoint la navigation (RG-NAV-39).
func (a *app) telephonesRejoints(ctx context.Context, navigation string) ([]string, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT appareil_id::text FROM navigations_rejointes WHERE navigation_id = $1
		ORDER BY rejointe_le`, navigation)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(lignes, pgx.RowTo[string])
}
