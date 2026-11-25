package main

import (
	"context"
	"log"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// base : connexion à PostgreSQL (service « base » de compose.yaml sur le Pi, D-130).
// Le serveur démarre même sans base : le point de santé dit alors pourquoi.
// Les migrations (migrations.go) sont appliquées au démarrage, puis
// réessayées toutes les 5 secondes tant que la base n'est pas joignable.
type base struct {
	pool *pgxpool.Pool
	err  error
	pret atomic.Bool
}

func ouvrirBase(ctx context.Context, url string) *base {
	if url == "" {
		return &base{}
	}
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		log.Printf("base : réglage refusé : %v", err)
		return &base{err: err}
	}
	b := &base{pool: pool}
	go b.migrerEnBoucle(ctx)
	return b
}

func (b *base) migrerEnBoucle(ctx context.Context) {
	for {
		essai, annuler := context.WithTimeout(ctx, time.Minute)
		err := migrer(essai, b.pool)
		annuler()
		if err == nil {
			b.pret.Store(true)
			log.Printf("base : schéma à jour (%d migrations)", len(migrations))
			return
		}
		log.Printf("base : migrations non appliquées : %v", err)
		select {
		case <-ctx.Done():
			return
		case <-time.After(5 * time.Second):
		}
	}
}

// prete : base joignable et schéma à jour.
func (b *base) prete() bool {
	return b != nil && b.pool != nil && b.pret.Load()
}

// etat : "absente" (pas réglée), "ok" (joignable et schéma à jour) ou "erreur".
func (b *base) etat(ctx context.Context) string {
	if b == nil || (b.pool == nil && b.err == nil) {
		return "absente"
	}
	if b.err != nil || !b.pret.Load() {
		return "erreur"
	}
	ctx, annuler := context.WithTimeout(ctx, 2*time.Second)
	defer annuler()
	if err := b.pool.Ping(ctx); err != nil {
		return "erreur"
	}
	return "ok"
}

func (b *base) fermer() {
	if b != nil && b.pool != nil {
		b.pool.Close()
	}
}
