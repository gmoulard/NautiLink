# NautiLink — Versions et compatibilité

Gestion des versions des trois composants de NautiLink et matrice de compatibilité ([D-128](07-decisions.md#d-128)). Mise à jour : 2026-11-26.

## 1. Composants et numéro de version

| Composant | Contenu | Version dans | Construit par |
|-----------|---------|--------------|---------------|
| **Serveur** | API, Application web, espace administrateur (`server/`) | [`server/VERSION`](../server/VERSION) | workflow « Serveur » (`.github/workflows/serveur.yml`) |
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

- **Production pendant la bêta** ([D-145](07-decisions.md#d-145)) : la dernière construction de la vraie application publiée sur le site (version de `app/pubspec.yaml`, build du workflow).
- **Démonstration V0** ([D-144](07-decisions.md#d-144)) : terminée, figée au commit `8ac9c1a`, en version 0.0.1 ; le workflow « Site GitHub Pages » la reconstruit toujours depuis ce commit (`DEMO_V0_COMMIT`), quel que soit l'état de `app/`. Sa version ne change plus ; la version de `app/pubspec.yaml` est celle de la vraie application.

## 2. Affichage

Pied de page de toutes les pages du site et de l'espace administrateur (et de la démonstration V0, figée : D-144) :

> Tous droits réservés · https://github.com/gmoulard/NautiLink · V0.0.1 · build 12 · commit 93b0f97

Pied de page de l'Application web et de tous les écrans de l'application mobile (Android, iPhone) : l'adresse du dépôt est remplacée par le lien « NautiLink » vers le site de présentation <https://gmoulard.github.io/NautiLink/> ([D-149](07-decisions.md#d-149) ; fait sur l'application mobile, reste l'Application web : TODO-3.19). Sur l'application mobile, ce pied de page suit le contenu de la page, sous les boutons, avec le lien « Mémo sécurité en mer » (TODO-5.12, [Q-102](06-questions-ouvertes.md#q-102)) :

> Tous droits réservés · [NautiLink](https://gmoulard.github.io/NautiLink/) · V0.0.1 · build 13 · commit 7ace1f5

- **Licence** : tous droits réservés ([`LICENSE`](../LICENSE)).
- **Site** : version de `site/VERSION`, build et commit de l'exécution qui a reconstruit le site. La page « Télécharger » donne en plus la version, le build et le commit de l'APK et de l'IPA publiés (`downloads/COMMITS.txt` : `fichier commit version build`).
- **Application** : valeurs fournies à la construction (`--dart-define=NAUTILINK_VERSION`, `NAUTILINK_BUILD`, `NAUTILINK_COMMIT`) ; « version locale » pour une construction sur un poste. Le numéro de build sert aussi de `versionCode` Android et de `CFBundleVersion` iPhone (`--build-number`).
- **Serveur** : valeurs posées dans le binaire par l'image Docker (`-ldflags`), « build local » hors image ; aussi données par `nautilink-server version`, `GET <chemin>/api/sante` (`version`, `build`, `commit`) et la supervision de l'espace administrateur.

## 3. Matrice de compatibilité

Une ligne par combinaison publiée ; la plus récente en haut. L'API est décrite par [`api/openapi.yaml`](api/openapi.yaml), dont la version (`info.version`) est celle du contrat, distincte de celle du serveur.

| Date | Serveur | API | Application | Site | Compatibilité |
|------|---------|-----|-------------|------|---------------|
| 2026-11-26 | 0.0.1 | 0.1.0 (proposition) | 0.2.0 (vraie application) ; démonstration 0.0.1 figée | 0.0.2 | Remarques de relecture de l'application Android (TODO-5.12) : écrans seulement, mêmes routes du serveur ; le sélecteur « SMS » du démarrage reste sur le téléphone. Compatible avec le serveur 0.0.1. |
| 2026-11-26 | 0.0.1 | 0.1.0 (proposition) | 0.1.0 (vraie application) ; démonstration 0.0.1 figée | 0.0.2 | Vraie application complète (SMS, vue suiveur, notifications push, achats, connexion Google et Apple), branchée sur le serveur : routes de navigation, contacts, SOS et synchronisation du serveur 0.0.1 ; notifications push, achats intégrés et reprise d'un téléphone par un autre compte demandent le serveur du même commit (pas encore de nouvelle version publiée du serveur). Démonstration V0 terminée, figée au commit `8ac9c1a` en version 0.0.1 et toujours publiée par le site (D-144). Le site 0.0.2 présente les deux. |
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
