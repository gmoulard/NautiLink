# Serveur NautiLink

Serveur central de NautiLink : API, plateforme Web et espace administrateur, en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance ([D-62](../docs/07-decisions.md#d-62)). L'API suit [`docs/api/openapi.yaml`](../docs/api/openapi.yaml).

Réalisé :

- comptes (TODO-4.1) : création par e-mail avec acceptation de l'avertissement bêta, vérification de l'adresse par e-mail, connexion, sessions (90 jours sans usage, RG-CPT-08), profil ; Google et Apple prêts, désactivés sans identifiants clients ;
- bateaux (TODO-4.2) : téléphones des utilisateurs, fiches des bateaux, photo, téléphone associé ;
- plateforme Web minimale (pages servies par le serveur, en français, sans JavaScript) : inscription, connexion, déconnexion, « Mon compte », « Bateaux » ;
- espace administrateur : vide (TODO-7.1).

## Lancer en local

```bash
cd server
go vet ./... && go test ./...
NAUTILINK_CHEMIN=/nautilink go run .
# http://localhost:8080/nautilink/  et  http://localhost:8080/nautilink/api/sante
```

Sans base (`NAUTILINK_BASE` vide), seules la page d'accueil et le point de santé répondent ; le reste dit « service momentanément indisponible ». Avec la base de l'environnement de test :

```bash
GARDER=1 ./essai-test.sh   # PostgreSQL sur 127.0.0.1:5432, Mailpit sur http://127.0.0.1:8025
NAUTILINK_CHEMIN=/nautilink NAUTILINK_ADRESSE=:8081 \
  NAUTILINK_BASE='postgres://nautilink:essai@127.0.0.1:5432/nautilink?sslmode=disable' \
  NAUTILINK_SMTP_HOTE=127.0.0.1 NAUTILINK_SMTP_PORT=1025 go run .
```

## Essais

- `go test ./...` : essais sans base, toujours joués.
- Essais avec PostgreSQL : poser `NAUTILINK_BASE_TEST` sur une base **jetable** (elle est vidée à chaque essai), par exemple `NAUTILINK_BASE_TEST='postgres://nautilink:essai@127.0.0.1:5432/nautilink?sslmode=disable' go test ./...` avec l'environnement de test lancé. Sans cette variable, ils sont sautés. Le workflow « Serveur » les joue avec un service PostgreSQL.
- `./essai-test.sh` : déploiement de test complet (ci-dessous).

## Environnement de test

```bash
cd server
./essai-test.sh          # construit, lance, vérifie santé, e-mail, création de compte, arrête
GARDER=1 ./essai-test.sh # garde l'environnement lancé
```

[`compose.test.yaml`](compose.test.yaml) : image construite depuis ce dossier, PostgreSQL jetable, e-mails capturés par Mailpit. Les trois environnements : [08-architecture.md §6](../docs/08-architecture.md#6-environnements).

## Réglages (variables d'environnement)

| Variable | Rôle | Par défaut |
|----------|------|------------|
| `NAUTILINK_ADRESSE` | Adresse d'écoute | `:8080` |
| `NAUTILINK_CHEMIN` | Chemin sous lequel tout est servi (`/nautilink` sur pi-appliance) | racine |
| `NAUTILINK_ADRESSE_PUBLIQUE` | Adresse vue des utilisateurs, chemin compris, pour les liens des e-mails (`https://vdl.moulard.org/nautilink`) | déduite de la requête |
| `NAUTILINK_BASE` | URL PostgreSQL (`postgres://…`) ; vide : pas de base. Sur le Pi : `${PI_DATABASE_URL}` | vide |
| `NAUTILINK_SMTP_HOTE`, `NAUTILINK_SMTP_PORT` | Relais d'e-mails, sans mot de passe. Sur le Pi : `${PI_SMTP_HOST}`, `${PI_SMTP_PORT}` (2525) | vide, `25` |
| `NAUTILINK_EXPEDITEUR` | Adresse de l'expéditeur | `nautilink@moulard.org` |
| `NAUTILINK_GOOGLE_CLIENTS` | Identifiants clients OAuth Google acceptés (Web, Android, iPhone), séparés par des virgules ; vide : connexion Google désactivée | vide |
| `NAUTILINK_APPLE_CLIENTS` | Identifiants clients Apple acceptés (identifiant de l'application, Services ID), séparés par des virgules ; vide : connexion Apple désactivée | vide |

## Base de données

Le schéma est créé puis mis à jour au démarrage ([`migrations.go`](migrations.go)) : migrations numérotées, appliquées une seule fois chacune (table `schema_migrations`), sous un verrou PostgreSQL ; une migration publiée n'est jamais modifiée, on en ajoute une à la fin, sans perte de données. Si la base n'est pas joignable au démarrage, le serveur réessaie toutes les 5 secondes ; le point de santé dit `"base":"erreur"` tant que le schéma n'est pas à jour.

## Adresses

| Adresse | Contenu |
|---------|---------|
| `<chemin>/` | Accueil de la plateforme Web (tableau de bord une fois connecté) |
| `<chemin>/inscription`, `<chemin>/connexion`, `<chemin>/deconnexion` | Création de compte, connexion, déconnexion |
| `<chemin>/verification?jeton=…` | Lien de vérification de l'adresse e-mail |
| `<chemin>/compte` | « Mon compte » : nom, téléphone, langue, e-mails et notifications |
| `<chemin>/bateaux`, `<chemin>/bateaux/<id>` | Bateaux : liste, ajout, fiche, photo, téléphone associé |
| `<chemin>/api/v1/…` | API ([`openapi.yaml`](../docs/api/openapi.yaml)) |
| `<chemin>/admin/` | Espace administrateur (vide, TODO-7.1) |
| `<chemin>/api/sante` | État en JSON : `etat`, `version`, `base` (`ok`, `absente`, `erreur`) |
| `/` | Renvoi vers `<chemin>/` |

## Sécurité

Mots de passe hachés par argon2id ; jetons tirés au hasard, seule leur empreinte est gardée ; protection contre les essais répétés ; cookie de session `HttpOnly`, `Secure`, `SameSite=Lax` et refus des formulaires venus d'un autre site ; en-têtes de sécurité (CSP sans script). Détail : [08-architecture.md §4](../docs/08-architecture.md#4-api-et-synchronisation).

## Commandes

- `nautilink-server sante` : vérifie le serveur local (healthcheck de l'image, qui n'a pas de shell) ;
- `nautilink-server mail-essai <adresse>` : envoie un e-mail d'essai par le relais (sur le Pi : `docker exec <conteneur> /nautilink-server mail-essai …`) ;
- `nautilink-server version`.

## Image et déploiement

L'image `ghcr.io/gmoulard/nautilink-serveur` (`arm64` et `amd64`) est construite par le workflow « Serveur » (`.github/workflows/serveur.yml`) à chaque push sur `main` qui touche `server/`. Sur le Pi, NautiLink s'installe par « Docker Compose libre » avec [`compose.yaml`](compose.yaml), dont l'en-tête dit quoi cocher dans le panneau « Hébergement » de la console pi-appliance (chemin `/nautilink/`, base PostgreSQL, envoi d'e-mails, domaine `nautilink.moulard.org`). Pour passer à une nouvelle version : dans la console, mettre à jour le service (nouvelle image `latest`), ou `docker compose pull && docker compose up -d` ; les migrations de la base se font au démarrage.
