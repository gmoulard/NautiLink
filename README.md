# NautiLink

*Your sea, your safety, your story.*

**Site : <https://nautilink.moulard.org/>**

NautiLink est une solution connectée pour les plaisanciers : une application Android pour le navigateur à bord (positions, journal de bord, SOS par SMS), une application iPhone équivalente sans SMS, et une Application web pour suivre, consulter et gérer les navigations avec ses proches.

NautiLink est sponsorisée par la SRT ([srtoulon.fr](https://srtoulon.fr/)).

Ce dépôt contient la **spécification fonctionnelle**, le **site de présentation** et le **serveur** (Go) et l'**application mobile** (Flutter, Android et iPhone).

## Site et téléchargements

| | Adresse |
|---|---|
| **Site de présentation** | **<https://nautilink.moulard.org/index.html>** |
| Installer l'application (Android, iPhone) | <https://nautilink.moulard.org/index.html#installer> |
| Version gratuite et abonnement | <https://nautilink.moulard.org/index.html#tarifs> |
| Propositions de design (11 maquettes) | <https://nautilink.moulard.org/designs/> |
| Maquettes de l'application Android et Web (design « Radar de pluie ») | <https://nautilink.moulard.org/designs/app.html> |
| Variantes du design « Météo marine » (10 maquettes) | <https://nautilink.moulard.org/designs/meteo.html> |
| Mémo sécurité en mer | <https://nautilink.moulard.org/index.html#securite> |
| Mémo sécurité en mer, page à part des applications ([D-193](docs/07-decisions.md#d-193)) | <https://nautilink.moulard.org/memo.html> |
| Questions fréquentes | <https://nautilink.moulard.org/index.html#faq> |
| À propos | <https://nautilink.moulard.org/index.html#a-propos> |
| Avertissement bêta | <https://nautilink.moulard.org/index.html#avertissement> |

Le site tient sur une seule page à sections ([D-192](docs/07-decisions.md#d-192)) ; les anciennes adresses (`telecharger.html`, `abonnement.html`, `securite.html`, `faq.html`, `a-propos.html`, `avertissement.html`) restent valables et renvoient à leur section (`securite.html` à `memo.html`).

Pas de publication sur Google Play ; l'application iPhone est en préparation pour l'App Store ([D-194](docs/07-decisions.md#d-194), [guide](docs/etudes/app-store.md)) : le même workflow l'envoie à App Store Connect quand les secrets Apple sont posés. Le site est construit et publié par le workflow « Site GitHub Pages » à chaque modification de `site/` ou `app/` sur `main` ; il faut que GitHub Pages soit activé (Settings → Pages → Source : GitHub Actions).

## Documents

| Fichier | Contenu |
|---------|---------|
| [`docs/00-glossaire.md`](docs/00-glossaire.md) | Vocabulaire commun à tous les documents. |
| [`docs/01-cahier-des-charges.md`](docs/01-cahier-des-charges.md) | Périmètre, architecture, fonctionnalités écran par écran. |
| [`docs/02-regles-metier.md`](docs/02-regles-metier.md) | Règles détaillées numérotées `RG-…`. **Fait foi en cas d'écart.** |
| [`docs/03-parcours-utilisateur.md`](docs/03-parcours-utilisateur.md) | Parcours pas à pas du navigateur et de ses amis. |
| [`docs/04-modele-economique.md`](docs/04-modele-economique.md) | Offre gratuite, quota glissant, abonnement. |
| [`docs/05-identite-marque.md`](docs/05-identite-marque.md) | Nom, signature, logo, couleurs, typographie, ton. |
| [`docs/06-questions-ouvertes.md`](docs/06-questions-ouvertes.md) | Tout ce qui n'est pas décidé, numéroté `Q-…`. |
| [`docs/07-decisions.md`](docs/07-decisions.md) | Journal des arbitrages, numérotés `D-…`. |
| [`docs/08-architecture.md`](docs/08-architecture.md) | Architecture technique : applications Flutter, serveur Go, PostgreSQL, fichiers, e-mails, notifications push ; décisions et propositions. |
| [`docs/09-versions.md`](docs/09-versions.md) | Versions du serveur, de l'application et du site, numéros de build, matrice de compatibilité. |
| [`docs/api/openapi.yaml`](docs/api/openapi.yaml) | Description de l'API du serveur (OpenAPI 3.1) : chaque opération cite les règles `RG-…` qu'elle sert ; proposition non validée. |
| [`docs/TODO.md`](docs/TODO.md) | Feuille de route : actions `TODO-x.y`, états, dépendances, critères d'acceptation. |
| [`docs/Todo-done.md`](docs/Todo-done.md) | Actions réalisées et validées. |
| [`docs/Todo-ithem-for-todo.md`](docs/Todo-ithem-for-todo.md) | Demandes notées en vrac, à reporter dans le TODO. |
| [`docs/tests/scenarios-fonctionnels.md`](docs/tests/scenarios-fonctionnels.md) | Scénarios de tests fonctionnels `TS-…`, un au moins par règle `RG-…`. |
| [`docs/etudes/sms-mms-android.md`](docs/etudes/sms-mms-android.md) | Étude : envoi de SMS et MMS sur Android, règles Google Play, voies possibles. |
| [`docs/etudes/gps-arriere-plan-android.md`](docs/etudes/gps-arriere-plan-android.md) | Étude : GPS en arrière-plan sur Android, batterie, constructeurs, reprise après redémarrage. |
| [`docs/etudes/autorisations-android.md`](docs/etudes/autorisations-android.md) | Étude : autorisations Android, versions concernées, règles Google Play, parcours de demande. |
| [`docs/etudes/localisation-arriere-plan-iphone.md`](docs/etudes/localisation-arriere-plan-iphone.md) | Étude : localisation en arrière-plan sur iPhone, batterie, règles de l'App Store. |
| [`docs/etudes/notes-vocales.md`](docs/etudes/notes-vocales.md) | Étude : notes vocales, formats audio, durée, transcription en français hors connexion. |
| [`docs/etudes/meteofrance-connexion.md`](docs/etudes/meteofrance-connexion.md) | Mode d'emploi : compte et codes d'accès de l'API Météo-France, utilisation par le serveur. |
| [`docs/etudes/nom-nautilink.md`](docs/etudes/nom-nautilink.md) | Étude : disponibilité du nom NautiLink, antériorité, domaines, réseaux sociaux. |
| [`docs/etudes/shom-cartes.md`](docs/etudes/shom-cartes.md) | Étude : données du SHOM sur la carte de l'Application web, licences, service WMTS. |
| [`docs/etudes/versions-web.md`](docs/etudes/versions-web.md) | Étude : plusieurs versions de l'Application web, déploiement et compatibilité. |
| [`docs/etudes/app-store.md`](docs/etudes/app-store.md) | Mode d'emploi : publier l'application iPhone sur l'App Store (identifiant, App Store Connect, clé d'API, secrets du workflow, fiche, relecture, lien du site). |
| [`docs/textes/avertissement-beta.md`](docs/textes/avertissement-beta.md) | Texte de l'avertissement : version bêta et responsabilité. |
| [`docs/assets/`](docs/assets/) | Logo et images ; fichiers du logo (vectoriels, déclinaisons, icônes) dans [`docs/assets/logo/`](docs/assets/logo/). |
| [`app/`](app/) | Application mobile Flutter (Android, iPhone), voir son [README](app/README.md). |
| [`server/`](server/) | Serveur central en Go (squelette, TODO-3.7), image Docker et `compose.yaml` pour pi-appliance, voir son [README](server/README.md). |
| [`site/`](site/) | Site de présentation publié sur GitHub Pages (accueil, mémo sécurité en mer, avertissement), par le workflow `.github/workflows/pages.yml`. |

## Statut des informations

- **Décidé** : écrit dans les règles métier ou le cahier des charges, sans renvoi à une question.
- **Ouvert** : renvoie à une question `Q-…` ; une « proposition » y est une suggestion non validée.
- **Évolution future** : listée au §9 du cahier des charges, sans engagement.

## Licence

Tous droits réservés : voir [`LICENSE`](LICENSE). Versions et compatibilité des composants : [`docs/09-versions.md`](docs/09-versions.md).

Pour travailler avec Claude Code sur ce dépôt, voir [`CLAUDE.md`](CLAUDE.md).
