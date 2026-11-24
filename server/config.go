package main

import (
	"os"
	"strings"
)

// config : réglages lus dans les variables d'environnement, posées par le
// fichier compose.yaml (aucun secret dans le dépôt).
type config struct {
	Adresse       string // NAUTILINK_ADRESSE, ex. ":8080"
	Chemin        string // NAUTILINK_CHEMIN, ex. "/nautilink" (vide : racine)
	BaseDeDonnees string // NAUTILINK_BASE, URL PostgreSQL (vide : pas de base)
	SMTPHote      string // NAUTILINK_SMTP_HOTE, relais d'e-mails de pi-appliance
	SMTPPort      string // NAUTILINK_SMTP_PORT, 25 par défaut
	Expediteur    string // NAUTILINK_EXPEDITEUR, adresse de l'expéditeur
}

func configDepuisEnv() config {
	return config{
		Adresse:       env("NAUTILINK_ADRESSE", ":8080"),
		Chemin:        normaliserChemin(os.Getenv("NAUTILINK_CHEMIN")),
		BaseDeDonnees: os.Getenv("NAUTILINK_BASE"),
		SMTPHote:      os.Getenv("NAUTILINK_SMTP_HOTE"),
		SMTPPort:      env("NAUTILINK_SMTP_PORT", "25"),
		Expediteur:    env("NAUTILINK_EXPEDITEUR", "nautilink@moulard.org"),
	}
}

func env(nom, defaut string) string {
	if v := os.Getenv(nom); v != "" {
		return v
	}
	return defaut
}

// normaliserChemin : "nautilink/", "/nautilink" → "/nautilink" ; "", "/" → "".
func normaliserChemin(c string) string {
	c = strings.Trim(strings.TrimSpace(c), "/")
	if c == "" {
		return ""
	}
	return "/" + c
}

// portDe : ":8080" ou "0.0.0.0:8080" → ":8080".
func portDe(adresse string) string {
	if i := strings.LastIndex(adresse, ":"); i >= 0 {
		return adresse[i:]
	}
	return ":" + adresse
}
