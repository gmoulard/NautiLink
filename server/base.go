package main

import (
	"context"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// base : connexion à PostgreSQL (PostgreSQL partagé de pi-appliance, D-62).
// Le serveur démarre même sans base : le point de santé dit alors pourquoi.
type base struct {
	pool *pgxpool.Pool
	err  error
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
	return &base{pool: pool}
}

// etat : "absente" (pas réglée), "ok" ou "erreur".
func (b *base) etat(ctx context.Context) string {
	if b == nil || (b.pool == nil && b.err == nil) {
		return "absente"
	}
	if b.err != nil {
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
