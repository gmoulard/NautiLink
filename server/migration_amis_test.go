package main

import (
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// TestMigrationAmis : avec PostgreSQL : la migration 16 (D-187, D-188)
// renomme les colonnes des anciens rôles sans perdre de données : base à
// l'état de la migration 15, quelques lignes, puis migration.
func TestMigrationAmis(t *testing.T) {
	adresse := os.Getenv("NAUTILINK_BASE_TEST")
	if adresse == "" {
		t.Skip("NAUTILINK_BASE_TEST absente : essai avec PostgreSQL sauté")
	}
	ctx := t.Context()
	pool, err := pgxpool.New(ctx, adresse)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	executer := func(sql string, args ...any) {
		t.Helper()
		if _, err := pool.Exec(ctx, sql, args...); err != nil {
			t.Fatalf("%s : %v", sql, err)
		}
	}
	executer("DROP SCHEMA public CASCADE; CREATE SCHEMA public")
	executer(`CREATE TABLE schema_migrations (version integer PRIMARY KEY, appliquee_le timestamptz NOT NULL DEFAULT now())`)
	const avant = 15
	for i := 0; i < avant; i++ {
		executer(migrations[i])
		executer("INSERT INTO schema_migrations (version) VALUES ($1)", i+1)
	}
	// État d'avant : noms de colonnes de la migration 3.
	const nav, ami, contact = "11111111-0000-4000-8000-000000000001", "11111111-0000-4000-8000-000000000002",
		"11111111-0000-4000-8000-000000000003"
	for _, u := range [][2]string{{nav, "nav@exemple.org"}, {ami, "ami@exemple.org"}} {
		executer(`INSERT INTO utilisateurs (id, email, nom, avertissement_version, avertissement_accepte_le)
			VALUES ($1, $2, 'X', 'v1', now())`, u[0], u[1])
	}
	executer(`INSERT INTO contacts (id, navigateur_id, nom, telephone, suiveur, contact_sos, utilisateur_id)
		VALUES ($1, $2, 'Léa', '+33611223344', false, true, $3)`, contact, nav, ami)
	executer(`INSERT INTO acces (navigateur_id, suiveur_id, perimetre, contact_id) VALUES ($1, $2, 'navigateur', $3)`, nav, ami, contact)

	if err := migrer(ctx, pool); err != nil {
		t.Fatal(err)
	}
	var invite, avecTelephone bool
	var nom string
	if err := pool.QueryRow(ctx, "SELECT nom, invite, avec_telephone FROM contacts WHERE id = $1", contact).
		Scan(&nom, &invite, &avecTelephone); err != nil || nom != "Léa" || invite || !avecTelephone {
		t.Fatalf("contact après migration : %v %q %v %v", err, nom, invite, avecTelephone)
	}
	var amiID string
	if err := pool.QueryRow(ctx, "SELECT ami_id FROM acces WHERE navigateur_id = $1", nav).Scan(&amiID); err != nil || amiID != ami {
		t.Fatalf("accès après migration : %v %q", err, amiID)
	}
	var colonne string
	if err := pool.QueryRow(ctx, `SELECT column_name FROM information_schema.columns
		WHERE table_name = 'retraits_navigation' AND column_name = 'ami_id'`).Scan(&colonne); err != nil {
		t.Fatalf("retraits_navigation.ami_id absente : %v", err)
	}
	var version int
	if err := pool.QueryRow(ctx, "SELECT max(version) FROM schema_migrations").Scan(&version); err != nil || version != len(migrations) {
		t.Fatalf("version : %v %d", err, version)
	}
}
