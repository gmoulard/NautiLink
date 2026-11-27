# Étude : renommer NautiLink en NaviLink — inventaire, étapes, partage du travail

Action : [TODO-8.7](../TODO.md) · Question : [Q-26](../06-questions-ouvertes.md#q-26) · Étude liée : [disponibilité du nom NautiLink](nom-nautilink.md).

**Statut : étude faite le 2026-11-27 sur le commit `fdfc2de` de `main`.** Rien n'est décidé : le nom reste NautiLink ([D-87](../07-decisions.md#d-87)) tant qu'une décision `D-nn` n'a pas tranché le renommage. Les propositions de cette étude ne sont pas validées.

Le renommage se fait en trois temps : l'utilisateur vérifie que « NaviLink » est libre et réserve ce qui est à son nom (marque, domaines, comptes) ; Claude modifie le dépôt en une série de commits ; l'utilisateur renomme ce qui vit hors du dépôt (GitHub, serveur pi-appliance, consoles Google, Apple, Stripe).

Le nom apparaît dans 175 fichiers du dépôt (environ 1 000 occurrences) et dans 40 noms de fichiers. Une partie est du texte visible ; une autre sert d'identifiant technique (applicationId Android, bundle iOS, image Docker, base PostgreSQL, clés de stockage du téléphone). Changer ces identifiants a des conséquences pour les installations existantes : c'est le principal choix à faire avant de commencer (§ 5).

**Point d'alerte :** l'[étude du nom](nom-nautilink.md) § 1 a déjà repéré **Navlink**, une application de navigation pour iPhone et iPad. NaviLink en est très proche, dans le même secteur : la recherche d'antériorité est à refaire pour NaviLink avant tout changement.

## 1. Où apparaît le nom

La colonne « Effet du changement » dit ce qui casse si l'on renomme.

| Endroit | Exemples | Effet du changement |
|---------|----------|---------------------|
| Texte des documents (`docs/`, `README.md`, `CLAUDE.md`) | « NautiLink » dans les règles, décisions, études, scénarios de test | Aucun ; les `D-nn` passés restent tels quels (historique) |
| Site (`site/`) | titres, textes, `logo-nautilink.png`, liens `gmoulard.github.io/NautiLink/` | Les liens changent si le dépôt GitHub est renommé |
| Logos (`docs/assets/logo/`, `app/assets/`, `site/assets/`, `server/web/static/`) | 30 fichiers `nautilink-*.svg/png`, dessin du mot « NautiLink » | Le mot dessiné est à refaire, pas seulement le nom de fichier |
| Prototype Flutter (`app/`) | `name: nautilink` du `pubspec.yaml`, 16 fichiers `package:nautilink/`, titre de l'application | Aucun pour l'utilisateur |
| Identifiant Android | `fr.nautilink.nautilink`, dossier `kotlin/fr/nautilink/nautilink` | Nouvelle application : l'ancienne reste installée, pas de mise à jour ; Google Play la voit comme une autre fiche |
| Identifiant iPhone | bundle `fr.nautilink.nautilink` | Nouvel identifiant à créer chez Apple ; connexion Apple à reconfigurer |
| Clés de stockage du téléphone | `nautilink.jetonAcces`, `nautilink.compteEmail`, `nautilink.langue`… | Utilisateurs déconnectés, réglages perdus, sauf reprise des anciennes clés |
| Produit d'abonnement | `nautilink_abonnement_10_ans` | Doit correspondre au produit déclaré dans Google Play et l'App Store |
| Serveur Go (`server/`) | module `github.com/gmoulard/nautilink/server`, une trentaine de variables `NAUTILINK_*` | Le `.env` du Pi doit suivre les nouveaux noms |
| Déploiement | image `ghcr.io/gmoulard/nautilink-serveur`, chemin `/nautilink/`, `vdl.moulard.org/nautilink`, domaine `nautilink.moulard.org`, expéditeur `nautilink@moulard.org` | Liens des e-mails déjà envoyés et adresse du serveur dans l'application installée |
| Base PostgreSQL | utilisateur et base `nautilink`, volume `nautilink-base` | Renommer le volume sans migration = base vide |
| Workflows (`.github/workflows/`) | `nautilink.apk`, `nautilink-demo.apk`, `.ipa`, clé `nautilink-production.jks` | Liens de téléchargement du site |
| Noms de fichiers | `docs/etudes/nom-nautilink.md`, `Nautilinkimages261126.png/.pptx` | Liens internes à mettre à jour |

## 2. À faire par l'utilisateur

Ces actions demandent ses comptes, un paiement ou une décision juridique ; Claude ne peut pas les faire depuis une session.

**Avant le renommage**

- [ ] Chercher « NAVILINK », « NAVI-LINK », « NAVLINK » dans les bases INPI, EUIPO, TMview et OMPI, classes 9, 38 et 42 (adresses dans [nom-nautilink.md](nom-nautilink.md) § 2).
- [ ] Regarder l'App Store et Google Play pour « NaviLink » et « Navlink » (application de navigation déjà connue).
- [ ] Faire relire par un juriste en propriété intellectuelle si une antériorité proche apparaît.
- [ ] Vérifier et réserver les domaines `navilink.fr`, `navilink.com`, `navilink.app`, `navilink.eu`.
- [ ] Vérifier et réserver les comptes Instagram, Facebook, X, LinkedIn, YouTube, TikTok et l'organisation GitHub `navilink`.
- [ ] Faire les choix du § 5 (identifiants techniques, domaine, adresse du serveur).

**Après les commits de Claude**

- [ ] Renommer le dépôt GitHub `gmoulard/NautiLink` en `gmoulard/NaviLink` (Settings, General, Repository name). GitHub redirige les anciens liens du dépôt, pas ceux de GitHub Pages : l'adresse du site devient `gmoulard.github.io/NaviLink/`.
- [ ] Vérifier que la publication de la nouvelle image `ghcr.io/gmoulard/navilink-serveur` a réussi (onglet Actions), et la rendre publique si l'ancienne l'était.
- [ ] Sur pi-appliance : sauvegarder la base, installer le nouveau `compose.yaml`, chemin `/navilink/`, domaine `navilink.moulard.org`, renommer les variables `NAUTILINK_*` du `.env` en `NAVILINK_*`, créer l'adresse d'expédition `navilink@moulard.org`.
- [ ] Faire pointer `navilink.moulard.org` (DNS) vers le Pi.
- [ ] Google Cloud : renommer l'écran de consentement OAuth et créer les identifiants clients pour le nouvel applicationId (connexion Google).
- [ ] Apple Developer : créer le bundle `fr.navilink.navilink` (ou celui choisi), le Services ID de « Se connecter avec Apple » et le profil de signature.
- [ ] Google Play Console et App Store Connect : nouvelle fiche, produit `navilink_abonnement_10_ans` si le produit change de nom.
- [ ] Stripe : renommer le produit et le nom affiché sur les reçus ; vérifier l'adresse du webhook si le chemin `/nautilink/` change.
- [ ] Météo-France : renommer l'application déclarée sur le portail de l'API si son nom y figure.
- [ ] Prévenir les testeurs : désinstaller l'ancienne application et installer la nouvelle si l'identifiant change.

## 3. À faire par Claude

Tout se passe dans le dépôt, une étape par commit, avec les vérifications de `CLAUDE.md` (`flutter analyze`, `flutter test`, `gofmt -l .`, `go vet ./...`, `go test ./...`, identifiants cités mais non définis) avant chaque commit.

1. **Tracer la décision** : nouvelle décision `D-nn` dans `07-decisions.md` (nouveau nom, raisons, identifiants gardés ou changés), mise à jour de Q-26, action dans `TODO.md`. D-87 reste telle quelle et renvoie vers la nouvelle décision.
2. **Documents** : remplacer « NautiLink » par « NaviLink » dans `docs/`, `README.md`, `CLAUDE.md` et le glossaire ; renommer `nom-nautilink.md` en `nom-navilink.md` et y ajouter la recherche d'antériorité sur NaviLink ; mettre à jour l'OpenAPI.
3. **Logos** : redessiner les 15 SVG avec le mot « NaviLink » (le symbole ne change pas), régénérer les PNG, renommer les fichiers `navilink-*`, recopier `logo-navilink.png` dans `app/`, `site/` et `server/`.
4. **Site** : textes, titres, liens vers `gmoulard.github.io/NaviLink/`, noms des fichiers à télécharger (`navilink.apk`, `navilink-demo.apk`, `.ipa`).
5. **Prototype Flutter** : nom du paquet (`name: navilink`, imports `package:navilink/`), titre de l'application, libellés ; si décidé, applicationId, bundle iOS, dossier Kotlin et produit d'abonnement.
6. **Clés de stockage** : si elles changent, lire une fois les anciennes clés `nautilink.*` puis les recopier sous `navilink.*`, pour ne déconnecter personne ; test associé.
7. **Serveur Go** : module `github.com/gmoulard/navilink/server`, variables `NAVILINK_*` avec lecture des anciennes `NAUTILINK_*` en secours pendant une version, textes des e-mails et des pages, `compose.yaml`, `README.md`.
8. **Workflows** : nom de l'image `navilink-serveur`, des APK et IPA, du fichier de clé.
9. **Versions** : monter la version du serveur, de l'application et du site, et ajouter la ligne correspondante à `docs/09-versions.md` (D-128).
10. **Contrôle final** : `grep -rni nautilink` ne doit plus rien rendre hors historique (décisions passées, `Todo-done.md`) et hors compatibilité voulue (anciennes clés et variables).

## 4. Ordre conseillé

1. Vérification du nom (utilisateur).
2. Choix du § 5 (utilisateur), tracés en `D-nn`.
3. Commits dans le dépôt (Claude, § 3).
4. Relecture et fusion sur `main` (utilisateur).
5. Renommage du dépôt GitHub, puis du serveur, puis des consoles (utilisateur, § 2).

Renommer le dépôt GitHub après la fusion évite que les liens du site pointent vers une adresse qui n'existe pas encore.

## 5. Choix à faire (propositions non validées)

| Choix | Proposition | Pourquoi |
|-------|-------------|----------|
| Identifiants Android et iPhone (`fr.nautilink.nautilink`) | Les changer maintenant en `fr.navilink.navilink` | Aucune version n'est publiée sur Google Play ni sur l'App Store (TODO-8.4 et TODO-10.7 non faites) ; après publication, ce ne sera plus possible sans perdre les utilisateurs |
| Clés de stockage `nautilink.*` | Les changer, avec reprise des anciennes clés | Évite de déconnecter les testeurs |
| Variables `NAUTILINK_*` du serveur | Les changer, anciennes lues en secours une version | Le `.env` du Pi continue de marcher le temps de la bascule |
| Base PostgreSQL et volume `nautilink-base` | Les garder tels quels | Nom interne, invisible ; le renommer demande une migration pour rien |
| Adresse du serveur `vdl.moulard.org/nautilink` | Passer à `/navilink/`, avec une redirection de l'ancien chemin | Les applications déjà installées et les liens déjà envoyés par e-mail continuent de marcher |
| Domaine principal | À choisir après la vérification des domaines | Dépend de ce qui est libre |
| Logo | Garder le symbole, changer le seul mot | Le symbole ne porte pas le nom |

Une fois ces choix faits, demander à Claude « Renomme NautiLink en NaviLink » : il commence par l'étape 1 du § 3.
