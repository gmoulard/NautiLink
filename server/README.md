# Serveur NautiLink

Serveur central de NautiLink : API, plateforme Web et espace administrateur, en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance ([D-62](../docs/07-decisions.md#d-62)). Ce dossier n'est encore qu'un **squelette** (TODO-3.7) : page d'accueil, espace administrateur vide, point de santé, connexion à la base, e-mail d'essai.

## Lancer en local

```bash
cd server
go vet ./... && go test ./...
NAUTILINK_CHEMIN=/nautilink go run .
# http://localhost:8080/nautilink/  et  http://localhost:8080/nautilink/api/sante
```

## Réglages (variables d'environnement)

| Variable | Rôle | Par défaut |
|----------|------|------------|
| `NAUTILINK_ADRESSE` | Adresse d'écoute | `:8080` |
| `NAUTILINK_CHEMIN` | Chemin sous lequel tout est servi (`/nautilink` sur pi-appliance) | racine |
| `NAUTILINK_BASE` | URL PostgreSQL (`postgres://…`) ; vide : pas de base | vide |
| `NAUTILINK_SMTP_HOTE`, `NAUTILINK_SMTP_PORT` | Relais d'e-mails de pi-appliance, sans mot de passe | vide, `25` |
| `NAUTILINK_EXPEDITEUR` | Adresse de l'expéditeur | `nautilink@moulard.org` |

## Adresses

| Adresse | Contenu |
|---------|---------|
| `<chemin>/` | Page d'accueil de la plateforme Web |
| `<chemin>/admin/` | Espace administrateur (vide, TODO-7.1) |
| `<chemin>/api/sante` | État en JSON : `etat`, `version`, `base` (`ok`, `absente`, `erreur`) |
| `/` | Renvoi vers `<chemin>/` |

## Commandes

- `nautilink-server sante` : vérifie le serveur local (healthcheck de l'image, qui n'a pas de shell) ;
- `nautilink-server mail-essai <adresse>` : envoie un e-mail d'essai par le relais (sur le Pi : `docker exec <conteneur> /nautilink-server mail-essai …`) ;
- `nautilink-server version`.

## Image et déploiement

L'image `ghcr.io/gmoulard/nautilink-serveur` (`arm64` et `amd64`) est construite par le workflow « Serveur » (`.github/workflows/serveur.yml`) à chaque push sur `main` qui touche `server/`. Sur le Pi, NautiLink s'installe par « Docker Compose libre » avec [`compose.yaml`](compose.yaml) ; les fonctions de pi-appliance qui manquent encore y sont listées.
