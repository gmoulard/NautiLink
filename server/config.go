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
	// AdressePublique : NAUTILINK_ADRESSE_PUBLIQUE, adresse vue des
	// utilisateurs, chemin compris (ex. https://vdl.moulard.org/nautilink),
	// pour les liens des e-mails ; vide : déduite de la requête.
	AdressePublique string
	// Identifiants clients OAuth (NAUTILINK_GOOGLE_CLIENTS,
	// NAUTILINK_APPLE_CLIENTS, séparés par des virgules) : vides, la
	// connexion par Google ou par Apple est désactivée.
	GoogleClients []string
	AppleClients  []string
	// Admins : NAUTILINK_ADMINS, adresses e-mail des administrateurs,
	// séparées par des virgules (RG-ADM-07) ; vide : espace
	// administrateur fermé.
	Admins []string
	// Nominatim : NAUTILINK_NOMINATIM, adresse du service de géocodage
	// inverse (D-96), ex. https://nominatim.openstreetmap.org ; vide : pas de
	// nom de lieu, les coordonnées en tiennent lieu (RG-NAV-16, RG-JRN-10).
	Nominatim string
}

func configDepuisEnv() config {
	return config{
		Adresse:       env("NAUTILINK_ADRESSE", ":8080"),
		Chemin:        normaliserChemin(os.Getenv("NAUTILINK_CHEMIN")),
		BaseDeDonnees: os.Getenv("NAUTILINK_BASE"),
		SMTPHote:      os.Getenv("NAUTILINK_SMTP_HOTE"),
		SMTPPort:      env("NAUTILINK_SMTP_PORT", "25"),
		Expediteur:    env("NAUTILINK_EXPEDITEUR", "nautilink@moulard.org"),

		AdressePublique: strings.TrimRight(strings.TrimSpace(os.Getenv("NAUTILINK_ADRESSE_PUBLIQUE")), "/"),
		GoogleClients:   liste(os.Getenv("NAUTILINK_GOOGLE_CLIENTS")),
		AppleClients:    liste(os.Getenv("NAUTILINK_APPLE_CLIENTS")),
		Admins:          liste(strings.ToLower(os.Getenv("NAUTILINK_ADMINS"))),
		Nominatim:       strings.TrimRight(strings.TrimSpace(os.Getenv("NAUTILINK_NOMINATIM")), "/"),
	}
}

func env(nom, defaut string) string {
	if v := os.Getenv(nom); v != "" {
		return v
	}
	return defaut
}

func liste(v string) []string {
	var l []string
	for _, e := range strings.Split(v, ",") {
		if e = strings.TrimSpace(e); e != "" {
			l = append(l, e)
		}
	}
	return l
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
