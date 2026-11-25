// Serveur NautiLink : API, plateforme Web et espace administrateur
// (D-62) : comptes (TODO-4.1), point de santé, base PostgreSQL et ses
// migrations, envoi d'e-mails par le relais de pi-appliance.
//
// Commandes :
//
//	nautilink-server                    lance le serveur
//	nautilink-server sante              vérifie le serveur local (healthcheck Docker)
//	nautilink-server mail-essai <adr>   envoie un e-mail d'essai par le relais
//	nautilink-server version            affiche la version
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	cfg := configDepuisEnv()
	args := os.Args[1:]
	if len(args) == 0 {
		if err := servir(cfg); err != nil {
			log.Fatal(err)
		}
		return
	}
	switch args[0] {
	case "version":
		fmt.Println(constructionServeur())
	case "sante":
		os.Exit(sante(cfg))
	case "mail-essai":
		if len(args) != 2 {
			fmt.Fprintln(os.Stderr, "usage : nautilink-server mail-essai <adresse e-mail>")
			os.Exit(2)
		}
		if err := envoyerMail(cfg, args[1], "NautiLink : e-mail d'essai",
			"Cet e-mail d'essai a été envoyé par le serveur NautiLink.\n"); err != nil {
			fmt.Fprintln(os.Stderr, "échec :", err)
			os.Exit(1)
		}
		fmt.Println("e-mail envoyé à", args[1])
	default:
		fmt.Fprintf(os.Stderr, "commande inconnue : %s\n", args[0])
		os.Exit(2)
	}
}

func servir(cfg config) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	base := ouvrirBase(ctx, cfg.BaseDeDonnees)
	defer base.fermer()

	a := nouvelleApp(cfg, base)
	go a.tachesDeFond(ctx)
	srv := &http.Server{
		Addr:              cfg.Adresse,
		Handler:           a.routeur(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	go func() {
		<-ctx.Done()
		arret, annuler := context.WithTimeout(context.Background(), 10*time.Second)
		defer annuler()
		_ = srv.Shutdown(arret)
	}()
	log.Printf("NautiLink %s à l'écoute sur %s, chemin %q", constructionServeur(), cfg.Adresse, cfg.Chemin+"/")
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

// sante interroge le point de santé du serveur local : 0 si le serveur
// répond, 1 sinon. Sert au healthcheck de Docker (image sans shell).
func sante(cfg config) int {
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://127.0.0.1" + portDe(cfg.Adresse) + cfg.Chemin + "/api/sante")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
