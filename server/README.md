# Serveur NautiLink

Serveur central de NautiLink : API, Application web et espace administrateur, en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance ([D-62](../docs/07-decisions.md#d-62)). L'API suit [`docs/api/openapi.yaml`](../docs/api/openapi.yaml).

Réalisé :

- comptes (TODO-4.1) : création par e-mail avec acceptation de l'avertissement bêta, vérification de l'adresse par e-mail, connexion, mot de passe oublié (lien d'une heure, toutes les sessions fermées, RG-CPT-10), sessions (90 jours sans usage, RG-CPT-08), profil ; Google et Apple prêts (rattachement à un compte existant si l'adresse est garantie vérifiée, RG-CPT-11), désactivés sans identifiants clients ;
- bateaux (TODO-4.2) : téléphones des utilisateurs, fiches des bateaux, photo, téléphone associé ;
- contacts, invitations et accès des suiveurs (TODO-4.3) ;
- paramètres généraux synchronisés (TODO-4.4) ;
- Application web (pages servies par le serveur, en français, sans JavaScript sauf la mise à jour en direct de la page d'une navigation) : inscription, connexion, déconnexion, tableau de bord (TODO-6.1), « Mon compte », « Bateaux », « Contacts », « Paramètres », « Corbeille », page d'invitation ;
- espace administrateur (TODO-7.1, en cours) : `<chemin>/admin/`, session distincte, utilisateurs, contacts, bateaux et rattachement, annonces en bandeau, statistiques, supervision, journal de chaque action gardé 3 ans ; administrateurs désignés par `NAUTILINK_ADMINS` (RG-ADM-07).

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
| `NAUTILINK_BASE` | URL PostgreSQL (`postgres://…`) ; vide : pas de base. Sur le Pi : service `base` de `compose.yaml` (D-130) | vide |
| `NAUTILINK_SMTP_HOTE`, `NAUTILINK_SMTP_PORT` | Relais d'e-mails, sans mot de passe. Sur le Pi : `${PI_SMTP_HOST}`, `${PI_SMTP_PORT}`, par défaut `pi-appliance-mail` et 2525 | vide, `25` |
| `NAUTILINK_EXPEDITEUR` | Adresse de l'expéditeur | `nautilink@moulard.org` |
| `NAUTILINK_GOOGLE_CLIENTS` | Identifiants clients OAuth Google acceptés (Web, Android, iPhone), séparés par des virgules ; vide : connexion Google désactivée | vide |
| `NAUTILINK_ADMINS` | Adresses e-mail des administrateurs, séparées par des virgules (RG-ADM-07) ; le compte doit exister et son adresse être confirmée ; vide : espace administrateur fermé | vide |
| `NAUTILINK_APPLE_CLIENTS` | Identifiants clients Apple acceptés (identifiant de l'application, Services ID), séparés par des virgules ; vide : connexion Apple désactivée | vide |
| `NAUTILINK_NOMINATIM` | Service de géocodage inverse pour les noms de lieux (D-96), une requête par seconde au plus, avec cache. Sur le Pi : `https://nominatim.openstreetmap.org` ; vide : coordonnées à la place des noms | vide |
| `NAUTILINK_PRODUIT` | Identifiant de l'achat unique de 10 ans, le même sur Google Play et l'App Store (RG-ECO-06) | `nautilink_abonnement_10_ans` |
| `NAUTILINK_GOOGLE_PLAY_COMPTE` | Fichier JSON du compte de service Google qui a accès à la Google Play Developer API ; vide : achat Google Play refusé (`achat_non_configure`) | vide |
| `NAUTILINK_GOOGLE_PLAY_PAQUET` | Nom du paquet Android | `fr.nautilink.nautilink` |
| `NAUTILINK_APP_STORE_CLE`, `NAUTILINK_APP_STORE_CLE_ID`, `NAUTILINK_APP_STORE_EMETTEUR` | Clé `.p8`, identifiant de la clé et « Issuer ID » de l'App Store Server API ; vides : achat App Store refusé | vides |
| `NAUTILINK_APPLE_BUNDLE` | Identifiant de l'application iPhone (achats et notifications) | `fr.nautilink.nautilink` |
| `NAUTILINK_APP_STORE_SANDBOX` | `1` : achats d'essai (environnement « sandbox ») | vide |
| `NAUTILINK_FCM_COMPTE` | Fichier JSON du compte de service Firebase (notifications push Android, RG-AND-08) ; vide : pas de push Android | vide |
| `NAUTILINK_APNS_CLE`, `NAUTILINK_APNS_CLE_ID`, `NAUTILINK_APNS_EQUIPE` | Clé `.p8` d'APNs, identifiant de la clé, « Team ID » (notifications push iPhone, RG-IOS-06) ; vides : pas de push iPhone | vides |
| `NAUTILINK_APNS_SANDBOX` | `1` : applications d'essai (APNs « sandbox ») | vide |

## Base de données

Le schéma est créé puis mis à jour au démarrage ([`migrations.go`](migrations.go)) : migrations numérotées, appliquées une seule fois chacune (table `schema_migrations`), sous un verrou PostgreSQL ; une migration publiée n'est jamais modifiée, on en ajoute une à la fin, sans perte de données. Si la base n'est pas joignable au démarrage, le serveur réessaie toutes les 5 secondes ; le point de santé dit `"base":"erreur"` tant que le schéma n'est pas à jour.

## Adresses

| Adresse | Contenu |
|---------|---------|
| `<chemin>/` | Accueil de l'Application web ; une fois connecté, tableau de bord (TODO-6.1) : navigations en cours, historique filtrable (`?role=navigateur` ou `suiveur`, `?curseur=` pour les plus anciennes), aperçu |
| `<chemin>/inscription`, `<chemin>/connexion`, `<chemin>/deconnexion` | Création de compte, connexion, déconnexion |
| `<chemin>/verification?jeton=…` | Lien de vérification de l'adresse e-mail |
| `<chemin>/mot-de-passe-oublie`, `<chemin>/mot-de-passe?jeton=…` | « Mot de passe oublié ? » et lien reçu par e-mail pour choisir un nouveau mot de passe |
| `<chemin>/compte` | « Mon compte » : nom, téléphone, langue, e-mails et notifications |
| `<chemin>/bateaux`, `<chemin>/bateaux/<id>` | Bateaux : liste, ajout, fiche, photo, téléphone associé |
| `<chemin>/contacts`, `<chemin>/contacts/<id>` | Contacts, lien d'invitation, mes suiveurs, navigateurs suivis |
| `<chemin>/parametres` | Paramètres généraux : SMS envoyés aux suiveurs, fréquence des positions |
| `<chemin>/invitation?jeton=…` | Lien d'invitation : connexion ou création d'un compte, puis acceptation |
| `<chemin>/navigations/<id>` | Page d'une navigation (TODO-6.2) : informations, carte, alertes SOS, journal, bateau, suiveurs ; `…/direct` : partie relue toutes les 30 secondes pendant la navigation ; `…/suiveurs/<id>/retrait`, `…/suppression` (navigateur) |
| `<chemin>/corbeille` | Corbeille : navigations supprimées, « Restaurer » (TODO-4.8) |
| `<chemin>/api/v1/…` | API ([`openapi.yaml`](../docs/api/openapi.yaml)) |
| `<chemin>/admin/` | Espace administrateur : `connexion`, `utilisateurs`, `bateaux`, `annonces`, `journal` (TODO-7.1) |
| `<chemin>/api/sante` | État en JSON : `etat`, `version`, `build`, `commit`, `base` (`ok`, `absente`, `erreur`) |
| `/` | Renvoi vers `<chemin>/` |

## Sécurité

Mots de passe hachés par argon2id ; jetons tirés au hasard, seule leur empreinte est gardée ; protection contre les essais répétés ; cookie de session `HttpOnly`, `Secure`, `SameSite=Lax` et refus des formulaires venus d'un autre site ; en-têtes de sécurité (CSP sans script). Détail : [08-architecture.md §4](../docs/08-architecture.md#4-api-et-synchronisation).

## Commandes

- `nautilink-server sante` : vérifie le serveur local (healthcheck de l'image, qui n'a pas de shell) ;
- `nautilink-server mail-essai <adresse>` : envoie un e-mail d'essai par le relais (sur le Pi : `docker exec <conteneur> /nautilink-server mail-essai …`) ;
- `nautilink-server version` : version, build et commit, par exemple `0.0.1 (build 12, commit 93b0f97)`.

## Image et déploiement

L'image `ghcr.io/gmoulard/nautilink-serveur` (`arm64` et `amd64`) est construite par le workflow « Serveur » (`.github/workflows/serveur.yml`) à chaque push sur `main` qui touche `server/`. Sur le Pi, NautiLink s'installe par « Docker Compose libre » avec [`compose.yaml`](compose.yaml), dont l'en-tête dit quoi cocher dans le panneau « Hébergement » de la console pi-appliance (chemin `/nautilink/`, envoi d'e-mails, domaine `nautilink.moulard.org`) ; la base PostgreSQL est le service `base` du même fichier, données dans le volume `nautilink-base`, sur le réseau interne `base-interne` partagé avec le seul serveur, sans port publié, mot de passe « nautilink » par défaut remplaçable par `NAUTILINK_BASE_MOT_DE_PASSE` dans `.env` (D-130) ; administrateur : `gmoulard@gmail.com` par défaut, remplaçable par `NAUTILINK_ADMINS` dans `.env`. L'image porte la version de [`VERSION`](VERSION) (étiquettes `:<version>`, `:<version>-<build>`, `:<sha court>`, `:latest`, voir [docs/09-versions.md](../docs/09-versions.md)) ; `compose.yaml` pose l'étiquette `:<version>`, pas `:latest` qui resterait en cache sur le Pi. Pour passer à une nouvelle version : changer `VERSION`, l'étiquette de `compose.yaml` et la matrice de compatibilité, puis sur le Pi `docker compose pull && docker compose up -d` ; les migrations de la base se font au démarrage. Le pied de page de chaque page donne la licence, le dépôt, la version, le build et le commit.
