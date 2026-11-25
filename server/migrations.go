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

	// 3 — TODO-4.3 : contacts (suppressions gardées pour la synchronisation),
	// invitations, accès des suiveurs. « modification » : rang de la dernière
	// modification, curseur « depuis » de la synchronisation (RG-CTC-03).
	`CREATE SEQUENCE modifications;
	CREATE TABLE contacts (
		id uuid PRIMARY KEY,
		navigateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		nom text NOT NULL,
		telephone text,
		email text,
		suiveur boolean NOT NULL,
		contact_sos boolean NOT NULL,
		perimetre text,
		navigation_id uuid,
		utilisateur_id uuid REFERENCES utilisateurs ON DELETE SET NULL,
		version integer NOT NULL DEFAULT 1,
		modification bigint NOT NULL DEFAULT nextval('modifications'),
		modifie_le timestamptz NOT NULL DEFAULT now(),
		supprime_le timestamptz
	);
	CREATE INDEX contacts_navigateur ON contacts (navigateur_id, modification);
	CREATE TABLE invitations (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		navigateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		contact_id uuid REFERENCES contacts ON DELETE SET NULL,
		canal text NOT NULL,
		email text,
		telephone text,
		perimetre text NOT NULL,
		navigation_id uuid,
		jeton text NOT NULL UNIQUE,
		etat text NOT NULL DEFAULT 'envoyee',
		creee_le timestamptz NOT NULL DEFAULT now(),
		acceptee_le timestamptz,
		acceptee_par uuid REFERENCES utilisateurs ON DELETE SET NULL
	);
	CREATE INDEX invitations_contact ON invitations (contact_id);
	CREATE TABLE acces (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		navigateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		suiveur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		perimetre text NOT NULL,
		navigation_id uuid,
		contact_id uuid REFERENCES contacts ON DELETE SET NULL,
		accorde_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE UNIQUE INDEX acces_unique ON acces (navigateur_id, suiveur_id,
		coalesce(navigation_id, '00000000-0000-0000-0000-000000000000'));
	CREATE INDEX acces_suiveur ON acces (suiveur_id);`,

	// 4 — TODO-4.4 : paramètres généraux ; null : jamais réglé (Q-52).
	`CREATE TABLE parametres (
		utilisateur_id uuid PRIMARY KEY REFERENCES utilisateurs ON DELETE CASCADE,
		sms_actifs boolean,
		sms_debut boolean,
		sms_positions_automatiques boolean,
		sms_positions_manuelles boolean,
		sms_notes boolean,
		sms_photos boolean,
		sms_notes_vocales boolean,
		sms_fin boolean,
		photo_en_mms boolean,
		frequence_par_defaut integer,
		version integer NOT NULL DEFAULT 0,
		modifie_le timestamptz NOT NULL DEFAULT now()
	);`,

	// 5 — TODO-7.1 : espace administrateur : sessions distinctes (RG-ADM-01),
	// journal des actions gardé 3 ans (RG-ADM-03, RG-DON-02), annonces en
	// bandeau et leur fermeture par l'utilisateur (RG-ADM-06).
	`CREATE TABLE sessions_admin (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		utilisateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		jeton bytea NOT NULL UNIQUE,
		creee_le timestamptz NOT NULL DEFAULT now(),
		derniere_utilisation timestamptz NOT NULL DEFAULT now()
	);
	CREATE TABLE journal_admin (
		id bigserial PRIMARY KEY,
		le timestamptz NOT NULL DEFAULT now(),
		admin_id uuid,
		admin_email text NOT NULL,
		action text NOT NULL,
		ressource text NOT NULL,
		cible text NOT NULL DEFAULT '',
		details jsonb
	);
	CREATE INDEX journal_admin_le ON journal_admin (le);
	CREATE TABLE annonces (
		id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
		texte text NOT NULL,
		fin_le timestamptz,
		creee_par text NOT NULL,
		creee_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE TABLE annonces_fermees (
		annonce_id uuid NOT NULL REFERENCES annonces ON DELETE CASCADE,
		utilisateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		fermee_le timestamptz NOT NULL DEFAULT now(),
		PRIMARY KEY (annonce_id, utilisateur_id)
	);`,

	// 6 — LOT-9 (TODO-4.5 à TODO-4.8) : navigations (heures enregistrées par
	// le téléphone et heures affichées, clôture automatique, corbeille),
	// journal de bord, fichiers, retraits d'une seule navigation, cache des
	// noms de lieux, abonnements, alertes SOS et statuts de leurs SMS.
	// Une navigation est en cours tant que fin_enregistree est vide.
	`CREATE TABLE navigations (
		id uuid PRIMARY KEY,
		navigateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		bateau_id uuid NOT NULL REFERENCES bateaux ON DELETE CASCADE,
		appareil_id uuid NOT NULL,
		nom text NOT NULL,
		destination jsonb,
		frequence_minutes integer NOT NULL,
		parametres jsonb,
		personnes_a_bord integer NOT NULL,
		personnes_alertees uuid[],
		debut_enregistre timestamptz NOT NULL,
		fin_enregistree timestamptz,
		debut timestamptz NOT NULL,
		fin timestamptz,
		meteo_depart jsonb,
		meteo_arrivee jsonb,
		epuise_le timestamptz,
		cloture_automatique_le timestamptz,
		supprimee_le timestamptz,
		empreinte bytea NOT NULL,
		version integer NOT NULL DEFAULT 1,
		creee_le timestamptz NOT NULL DEFAULT now(),
		modifiee_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE INDEX navigations_navigateur ON navigations (navigateur_id, debut_enregistre);
	CREATE UNIQUE INDEX navigations_bateau_en_cours ON navigations (bateau_id) WHERE fin_enregistree IS NULL;
	CREATE UNIQUE INDEX navigations_appareil_en_cours ON navigations (appareil_id) WHERE fin_enregistree IS NULL;
	CREATE TABLE evenements (
		id uuid PRIMARY KEY,
		navigation_id uuid NOT NULL REFERENCES navigations ON DELETE CASCADE,
		type text NOT NULL,
		heure_acquisition timestamptz NOT NULL,
		numero_ordre integer,
		latitude double precision,
		longitude double precision,
		precision_metres double precision,
		heure_position timestamptz,
		gps_disponible boolean,
		lieu text,
		lieu_cherche boolean NOT NULL DEFAULT false,
		texte text,
		fichier_type text,
		fichier_taille integer,
		fichier_duree integer,
		origine text,
		alerte_sos_id uuid,
		empreinte bytea NOT NULL,
		recu_le timestamptz NOT NULL DEFAULT now(),
		modification bigint NOT NULL DEFAULT nextval('modifications'),
		supprime_le timestamptz
	);
	CREATE INDEX evenements_navigation ON evenements (navigation_id, heure_acquisition);
	CREATE INDEX evenements_modification ON evenements (navigation_id, modification);
	CREATE INDEX evenements_lieu ON evenements (id) WHERE latitude IS NOT NULL AND NOT lieu_cherche;
	CREATE TABLE fichiers (
		evenement_id uuid PRIMARY KEY REFERENCES evenements ON DELETE CASCADE,
		type_media text NOT NULL,
		contenu bytea NOT NULL,
		recu_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE TABLE retraits_navigation (
		navigation_id uuid NOT NULL REFERENCES navigations ON DELETE CASCADE,
		suiveur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		retire_le timestamptz NOT NULL DEFAULT now(),
		PRIMARY KEY (navigation_id, suiveur_id)
	);
	CREATE TABLE lieux (
		latitude integer NOT NULL,
		longitude integer NOT NULL,
		nom text,
		cherche_le timestamptz NOT NULL DEFAULT now(),
		PRIMARY KEY (latitude, longitude)
	);
	CREATE TABLE abonnements (
		utilisateur_id uuid PRIMARY KEY REFERENCES utilisateurs ON DELETE CASCADE,
		canal text NOT NULL,
		debut timestamptz NOT NULL,
		fin timestamptz NOT NULL,
		reference text NOT NULL DEFAULT ''
	);
	CREATE TABLE alertes_sos (
		id uuid PRIMARY KEY,
		navigateur_id uuid NOT NULL REFERENCES utilisateurs ON DELETE CASCADE,
		bateau_id uuid NOT NULL REFERENCES bateaux ON DELETE CASCADE,
		navigation_id uuid REFERENCES navigations ON DELETE SET NULL,
		appareil_id uuid,
		heure_declenchement timestamptz NOT NULL,
		latitude double precision,
		longitude double precision,
		precision_metres double precision,
		heure_position timestamptz,
		nature_position text NOT NULL,
		probleme text,
		personnes_a_bord integer,
		emails_envoyes_a text[] NOT NULL DEFAULT '{}',
		empreinte bytea NOT NULL,
		recue_le timestamptz NOT NULL DEFAULT now()
	);
	CREATE INDEX alertes_sos_bateau ON alertes_sos (bateau_id, heure_declenchement);
	CREATE TABLE statuts_sms (
		alerte_id uuid NOT NULL REFERENCES alertes_sos ON DELETE CASCADE,
		telephone text NOT NULL,
		rang integer NOT NULL,
		contact_id uuid,
		statut text NOT NULL,
		essais integer NOT NULL DEFAULT 0,
		mis_a_jour_le timestamptz NOT NULL DEFAULT now(),
		PRIMARY KEY (alerte_id, telephone, rang)
	);`,

	// 7 — RG-PAR-09 (D-111) : périmètre navigateur limité aux navigations
	// commencées depuis qu'il a pris effet ; la navigation partagée avant un
	// passage du périmètre navigation au périmètre navigateur reste visible.
	`ALTER TABLE acces ADD COLUMN navigateur_depuis timestamptz;
	ALTER TABLE acces ADD COLUMN navigation_conservee uuid;
	UPDATE acces SET navigateur_depuis = accorde_le WHERE perimetre = 'navigateur';`,
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
