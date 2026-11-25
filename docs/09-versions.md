# NautiLink — Versions et compatibilité

Gestion des versions des trois composants de NautiLink et matrice de compatibilité ([D-128](07-decisions.md#d-128)). Mise à jour : 2026-11-25.

## 1. Composants et numéro de version

| Composant | Contenu | Version dans | Construit par |
|-----------|---------|--------------|---------------|
| **Serveur** | API, plateforme Web, espace administrateur (`server/`) | [`server/VERSION`](../server/VERSION) | workflow « Serveur » (`.github/workflows/serveur.yml`) |
| **Application** | Application Flutter : Android (APK), iPhone (IPA), démonstration Web (`app/`) | `version:` de [`app/pubspec.yaml`](../app/pubspec.yaml), partie avant « + » | workflow « Site GitHub Pages » (`.github/workflows/pages.yml`) |
| **Site** | Site de présentation (`site/`) | [`site/VERSION`](../site/VERSION) | workflow « Site GitHub Pages » |

Les trois composants partent de la version **0.0.1** (2026-11-25).

- **Format** : `MAJEUR.MINEUR.CORRECTIF` ([versionnage sémantique](https://semver.org/lang/fr/)) :
  - **correctif** : correction sans changement de comportement attendu ;
  - **mineur** : nouvelle fonction compatible avec les autres composants de la matrice ;
  - **majeur** : rupture de compatibilité (API, format de données) ; tant que le majeur vaut 0, une rupture peut aussi passer par le mineur.
- **Changer de version** : un commit qui modifie le fichier de version du composant **et** la [matrice](#3-matrice-de-compatibilite) (nouvelle ligne).
- **Build** : numéro d'exécution du workflow qui a construit le livrable (`github.run_number`), propre à chaque workflow. Deux constructions de la même version se distinguent par leur build et leur commit.
- **Commit** : SHA du commit construit, affiché sur 7 caractères avec un lien vers GitHub.

## 2. Affichage

Pied de page de toutes les pages du site, de la plateforme Web, de l'espace administrateur et de tous les écrans de l'application (Android, iPhone, démonstration Web) :

> Tous droits réservés · https://github.com/gmoulard/NautiLink · V0.0.1 · build 12 · commit 93b0f97

- **Licence** : tous droits réservés ([`LICENSE`](../LICENSE)).
- **Site** : version de `site/VERSION`, build et commit de l'exécution qui a reconstruit le site. La page « Télécharger » donne en plus la version, le build et le commit de l'APK et de l'IPA publiés (`downloads/COMMITS.txt` : `fichier commit version build`).
- **Application** : valeurs fournies à la construction (`--dart-define=NAUTILINK_VERSION`, `NAUTILINK_BUILD`, `NAUTILINK_COMMIT`) ; « version locale » pour une construction sur un poste. Le numéro de build sert aussi de `versionCode` Android et de `CFBundleVersion` iPhone (`--build-number`).
- **Serveur** : valeurs posées dans le binaire par l'image Docker (`-ldflags`), « build local » hors image ; aussi données par `nautilink-server version`, `GET <chemin>/api/sante` (`version`, `build`, `commit`) et la supervision de l'espace administrateur.

## 3. Matrice de compatibilité

Une ligne par combinaison publiée ; la plus récente en haut. L'API est décrite par [`api/openapi.yaml`](api/openapi.yaml), dont la version (`info.version`) est celle du contrat, distincte de celle du serveur.

| Date | Serveur | API | Application | Site | Compatibilité |
|------|---------|-----|-------------|------|---------------|
| 2026-11-25 | 0.0.1 | 0.1.0 (proposition) | 0.0.1 | 0.0.1 | Point de départ. L'application 0.0.1 est le prototype de démonstration sur données d'exemple : elle n'appelle pas le serveur, toute version du serveur convient. Le site 0.0.1 publie l'application 0.0.1 (APK, IPA, démonstration Web). |

Quand l'application appellera le serveur, la colonne « Compatibilité » donnera la version minimale du serveur exigée par chaque version de l'application, et inversement la plus ancienne application que le serveur accepte encore.

## 4. Images du serveur

Le workflow « Serveur » publie `ghcr.io/gmoulard/nautilink-serveur` avec quatre étiquettes à chaque construction :

| Étiquette | Exemple | Usage |
|-----------|---------|-------|
| `<version>-<build>` | `0.0.1-13` | Immuable : une construction précise ; étiquette posée dans [`server/compose.yaml`](../server/compose.yaml). |
| `<version>` | `0.0.1` | Dernière construction de cette version ; à éviter sur le Pi, qui garde en cache l'image déjà téléchargée (build 12 gardé après la publication du 13). |
| `<sha court>` | `93b0f97` | Construction d'un commit. |
| `latest` | | Dernière construction ; à éviter sur le Pi, qui garde en cache l'image déjà téléchargée. |

Pour déployer une nouvelle version : changer `server/VERSION`, la matrice et l'étiquette de `server/compose.yaml` dans le même commit ; pour déployer une nouvelle construction de la même version, changer seulement le build de l'étiquette (`0.0.1-13` → `0.0.1-14`) ; sur le Pi, `docker compose pull && docker compose up -d`.
