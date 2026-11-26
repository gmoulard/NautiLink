package main

import (
	"embed"
	"encoding/json"
	"html/template"
	"io/fs"
	"net/http"
)

//go:embed web
var fichiersWeb embed.FS

var pages = template.Must(template.New("").Funcs(fonctionsPages).ParseFS(fichiersWeb, "web/*.html", "web/admin/*.html"))

// nouveauRouteur : tout est servi sous cfg.Chemin (ex. /nautilink), car
// pi-appliance publie le service sous https://vdl.moulard.org/nautilink/
// et Traefik garde le chemin (D-62). Les liens des pages sont relatifs.
func nouveauRouteur(cfg config, b *base) http.Handler {
	return nouvelleApp(cfg, b).routeur()
}

func (a *app) routeur() http.Handler {
	cfg, b := a.cfg, a.b
	c := cfg.Chemin
	mux := http.NewServeMux()

	statiques, _ := fs.Sub(fichiersWeb, "web/static")
	mux.Handle("GET "+c+"/static/", http.StripPrefix(c+"/static/", http.FileServerFS(statiques)))

	mux.HandleFunc("GET "+c+"/api/sante", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"etat":    "ok",
			"version": version,
			"build":   build,
			"commit":  commit,
			"base":    b.etat(r.Context()),
		})
	})

	a.routesComptes(mux, c+"/api/v1")
	a.routesWebComptes(mux, c)
	a.routesBateaux(mux, c+"/api/v1")
	a.routesWebBateaux(mux, c)
	a.routesContacts(mux, c+"/api/v1")
	a.routesWebContacts(mux, c)
	a.routesParametres(mux, c+"/api/v1")
	a.routesWebParametres(mux, c)
	a.routesNavigations(mux, c+"/api/v1")
	a.routesCorbeille(mux, c+"/api/v1")
	a.routesWebCorbeille(mux, c)
	a.routesWebAlertes(mux, c)
	a.routesWebNavigations(mux, c)
	a.routesWebJournal(mux, c)
	a.routesWebConduite(mux, c)
	a.routesWebDemarrage(mux, c)
	a.routesWebPDF(mux, c)
	a.routesQuota(mux, c+"/api/v1")
	a.routesAchats(mux, c+"/api/v1")
	a.routesStripe(mux, c+"/api/v1")
	a.routesWebQuota(mux, c)
	a.routesSos(mux, c+"/api/v1")

	a.routesAdmin(mux, c+"/api/v1")
	a.routesWebAdmin(mux, c)

	if c != "" {
		// Adresse sans chemin (à la maison, ou sans la barre finale) : renvoi
		// vers la page d'accueil.
		mux.HandleFunc("GET /{$}", rediriger(c+"/"))
		mux.HandleFunc("GET "+c, rediriger(c+"/"))
	}
	return entetes(mux)
}

func rediriger(vers string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, vers, http.StatusFound)
	}
}

// entetes : en-têtes de sécurité communs à toutes les réponses.
func entetes(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "same-origin")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; img-src 'self' data: "+sourcesCarte+"; frame-ancestors 'none'; form-action 'self'; base-uri 'none'")
		h.ServeHTTP(w, r)
	})
}
