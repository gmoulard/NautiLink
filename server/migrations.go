package main

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// migrations : schéma de la base, appliqué au démarrage du serveur dans
// l'ordre, chacune une seule fois (table schema_migrations). Une migration
// publiée n'est jamais modifiée ni retirée : on en ajoute une à la fin, sans
// perte des données existantes (ajouts de tables, de colonnes, d'index).
var migrations = []string{
	// 1 — TODO-4.1 : comptes, identités Google et Apple, sessions, jetons envoyés par e-mail.
	`CREATE TABLE utilisateurs (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		email text NOT NULL UNIQUE,
		email_verifie_le timestamptz,
		mot_de_passe text NOT NULL DEFAULT '',
		nom text NOT NULL,
		telephone text,
		recevoir_sms boolean NOT NULL DEFAULT false,
		langue text NOT NULL DEFAULT 'fr',
		emails_debut boolean NOT NULL DEFAULT true,
		push_debut boolean NOT NULL DEFAULT true,
		push_fin boolean NOT NULL DEFAULT true,
		push_photo boolean NOT NULL DEFAULT true,
		push_position_en_retard boolean NOT NULL DEFAULT true,
		avertissement_version text NOT NULL,
		avertissement_accepte_le timestamptz NOT NULL,
		cree_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE TABLE identites_externes (
		fournisseur text NOT NULL,
		sujet text NOT NULL,
		utilisateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		cree_le timestamptz NOT NULL DEFAULT now(),
		PRIMARY KEY (fournisseur, sujet)
	);
	CREATE TABLE sessions (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		utilisateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		jeton_acces bytea NOT NULL UNIQUE,
		jeton_renouvellement bytea UNIQUE,
		support text NOT NULL,
		appareil_id uuid,
		creee_le timestamptz NOT NULL DEFAULT now(),
		derniere_utilisation timestamptz NOT NULL DEFAULT now()
	);
	CREATE INDEX sessions_utilisateur ON sessions (utilisateur_id);
	CREATE TABLE jetons_email (
		jeton bytea PRIMARY KEY,
		utilisateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		objet text NOT NULL,
		email text NOT NULL,
		expire_le timestamptz NOT NULL,
		utilise_le timestamptz
	);`,

	// 2 — TODO-4.2 : téléphones des utilisateurs, bateaux et leur fiche, téléphone associé.
	`CREATE TABLE appareils (
		id uuid PRIMARY KEY,
		utilisateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		plateforme text NOT NULL,
		nom text NOT NULL DEFAULT '',
		jeton_push text,
		version_application text NOT NULL DEFAULT '',
		mis_a_jour_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE INDEX appareils_utilisateur ON appareils (utilisateur_id);
	CREATE TABLE bateaux (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		proprietaire_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		nom text NOT NULL,
		type text NOT NULL,
		longueur_metres double precision,
		immatriculation text NOT NULL DEFAULT '',
		port_attache text NOT NULL DEFAULT '',
		moteur text NOT NULL DEFAULT '',
		autonomie text NOT NULL DEFAULT '',
		capacite_carburant_litres double precision,
		vitesse_noeuds double precision,
		tirant_eau_metres double precision,
		photo bytea,
		appareil_associe_id uuid REFERENCES appareils ON DELETE SET NULL,
		cree_le timestamptz NOT NULL DEFAULT now(),
		modifie_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE INDEX bateaux_proprietaire ON bateaux (proprietaire_id);`,
}

// cleVerrou : verrou consultatif PostgreSQL qui empêche deux serveurs de
// migrer la même base en même temps.
const cleVerrou = 7_406_001

func migrer(ctx context.Context, pool *pgxpool.Pool) error {
	conn, err := pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()
	if _, err := conn.Exec(ctx, "SELECT pg_advisory_lock($1)", cleVerrou); err != nil {
		return err
	}
	defer conn.Exec(context.Background(), "SELECT pg_advisory_unlock($1)", cleVerrou)
	if _, err := conn.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (
		version integer PRIMARY KEY, appliquee_le timestamptz NOT NULL DEFAULT now())`); err != nil {
		return err
	}
	var faite int
	if err := conn.QueryRow(ctx, "SELECT coalesce(max(version), 0) FROM schema_migrations").Scan(&faite); err != nil {
		return err
	}
	for i := faite; i < len(migrations); i++ {
		tx, err := conn.Begin(ctx)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, migrations[i]); err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("migration %d : %w", i+1, err)
		}
		if _, err := tx.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", i+1); err != nil {
			tx.Rollback(ctx)
			return err
		}
		if err := tx.Commit(ctx); err != nil {
			return err
		}
	}
	return nil
}
