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
	// MeteoFrance : NAUTILINK_METEOFRANCE, identifiant d'application OAuth2
	// de Météo-France encodé pour « Authorization: Basic » (RG-NAV-38,
	// D-172), jamais écrit dans le dépôt ; vide : pas de météo relevée.
	MeteoFrance string

	// Achats intégrés (RG-ECO-11, TODO-5.8, TODO-10.6) ; vides : achat refusé
	// avec le code achat_non_configure.
	Produit          string // NAUTILINK_PRODUIT, identifiant de l'achat unique de 10 ans
	GooglePlayCompte string // NAUTILINK_GOOGLE_PLAY_COMPTE, fichier JSON du compte de service
	GooglePlayPaquet string // NAUTILINK_GOOGLE_PLAY_PAQUET, nom du paquet Android
	AppStoreCle      string // NAUTILINK_APP_STORE_CLE, fichier .p8 de l'App Store Server API
	AppStoreCleID    string // NAUTILINK_APP_STORE_CLE_ID
	AppStoreEmetteur string // NAUTILINK_APP_STORE_EMETTEUR, « Issuer ID »
	AppleBundle      string // NAUTILINK_APPLE_BUNDLE, identifiant de l'application iPhone
	AppStoreSandbox  bool   // NAUTILINK_APP_STORE_SANDBOX=1 : achats d'essai

	// Paiement Web par Stripe (RG-ECO-11, TODO-6.7) ; vides : achat refusé
	// (achat_non_configure), avis de Stripe refusés.
	StripeCle          string // NAUTILINK_STRIPE_CLE, clé secrète de l'API Stripe
	StripeSecretRappel string // NAUTILINK_STRIPE_SECRET_RAPPEL, secret de signature des avis

	// Notifications push (RG-IOS-06, RG-AND-08, D-86) ; vides : pas de push.
	FCMCompte   string // NAUTILINK_FCM_COMPTE, fichier JSON du compte de service Firebase
	APNsCle     string // NAUTILINK_APNS_CLE, fichier .p8 d'APNs
	APNsCleID   string // NAUTILINK_APNS_CLE_ID
	APNsEquipe  string // NAUTILINK_APNS_EQUIPE, « Team ID »
	APNsSandbox bool   // NAUTILINK_APNS_SANDBOX=1 : applications d'essai
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
		MeteoFrance:     strings.TrimSpace(os.Getenv("NAUTILINK_METEOFRANCE")),

		Produit:            env("NAUTILINK_PRODUIT", "nautilink_abonnement_10_ans"),
		GooglePlayCompte:   os.Getenv("NAUTILINK_GOOGLE_PLAY_COMPTE"),
		GooglePlayPaquet:   env("NAUTILINK_GOOGLE_PLAY_PAQUET", "fr.nautilink.nautilink"),
		AppStoreCle:        os.Getenv("NAUTILINK_APP_STORE_CLE"),
		AppStoreCleID:      os.Getenv("NAUTILINK_APP_STORE_CLE_ID"),
		AppStoreEmetteur:   os.Getenv("NAUTILINK_APP_STORE_EMETTEUR"),
		AppleBundle:        env("NAUTILINK_APPLE_BUNDLE", "org.moulard.nautilink"),
		AppStoreSandbox:    os.Getenv("NAUTILINK_APP_STORE_SANDBOX") == "1",
		StripeCle:          os.Getenv("NAUTILINK_STRIPE_CLE"),
		StripeSecretRappel: os.Getenv("NAUTILINK_STRIPE_SECRET_RAPPEL"),
		FCMCompte:          os.Getenv("NAUTILINK_FCM_COMPTE"),
		APNsCle:            os.Getenv("NAUTILINK_APNS_CLE"),
		APNsCleID:          os.Getenv("NAUTILINK_APNS_CLE_ID"),
		APNsEquipe:         os.Getenv("NAUTILINK_APNS_EQUIPE"),
		APNsSandbox:        os.Getenv("NAUTILINK_APNS_SANDBOX") == "1",
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
