# NautiLink

*Your sea, your safety, your story.*

**Site : <https://gmoulard.github.io/NautiLink/>**

NautiLink est une solution connectée pour les plaisanciers : une application Android pour le navigateur à bord (positions, journal de bord, SOS par SMS), une application iPhone équivalente sans SMS, et une plateforme Web pour suivre, consulter et gérer les navigations avec ses proches.

NautiLink est sponsorisée par la SRT ([srtoulon.fr](https://srtoulon.fr/)).

Ce dépôt contient la **spécification fonctionnelle**, le **site de présentation** et un **prototype de démonstration** (Flutter, données d'exemple, sans serveur).

## Site et démonstrations

| | Adresse |
|---|---|
| **Site de présentation** | **<https://gmoulard.github.io/NautiLink/>** |
| Télécharger les démonstrations (APK Android, IPA iPhone non signé) | <https://gmoulard.github.io/NautiLink/telecharger.html> |
| Démonstration Web (installable sur l'écran d'accueil) | <https://gmoulard.github.io/NautiLink/app/> |
| Version gratuite et abonnement | <https://gmoulard.github.io/NautiLink/abonnement.html> |
| Propositions de design (11 maquettes) | <https://gmoulard.github.io/NautiLink/designs/> |
| Maquettes de l'application Android et Web (design « Radar de pluie ») | <https://gmoulard.github.io/NautiLink/designs/app.html> |
| Variantes du design « Météo marine » (10 maquettes) | <https://gmoulard.github.io/NautiLink/designs/meteo.html> |
| Mémo sécurité en mer | <https://gmoulard.github.io/NautiLink/securite.html> |
| Avertissement bêta | <https://gmoulard.github.io/NautiLink/avertissement.html> |

Aucune publication dans les stores. Le site est construit et publié par le workflow « Site GitHub Pages » à chaque modification de `site/` ou `app/` sur `main` ; il faut que GitHub Pages soit activé (Settings → Pages → Source : GitHub Actions).

## Documents

| Fichier | Contenu |
|---------|---------|
| [`docs/00-glossaire.md`](docs/00-glossaire.md) | Vocabulaire commun à tous les documents. |
| [`docs/01-cahier-des-charges.md`](docs/01-cahier-des-charges.md) | Périmètre, architecture, fonctionnalités écran par écran. |
| [`docs/02-regles-metier.md`](docs/02-regles-metier.md) | Règles détaillées numérotées `RG-…`. **Fait foi en cas d'écart.** |
| [`docs/03-parcours-utilisateur.md`](docs/03-parcours-utilisateur.md) | Parcours pas à pas du navigateur et du suiveur. |
| [`docs/04-modele-economique.md`](docs/04-modele-economique.md) | Offre gratuite, quota glissant, abonnement. |
| [`docs/05-identite-marque.md`](docs/05-identite-marque.md) | Nom, signature, logo, couleurs, typographie, ton. |
| [`docs/06-questions-ouvertes.md`](docs/06-questions-ouvertes.md) | Tout ce qui n'est pas décidé, numéroté `Q-…`. |
| [`docs/07-decisions.md`](docs/07-decisions.md) | Journal des arbitrages, numérotés `D-…`. |
| [`docs/TODO.md`](docs/TODO.md) | Feuille de route : actions `TODO-x.y`, états, dépendances, critères d'acceptation. |
| [`docs/Todo-done.md`](docs/Todo-done.md) | Actions réalisées et validées. |
| [`docs/Todo-ithem-for-todo.md`](docs/Todo-ithem-for-todo.md) | Demandes notées en vrac, à reporter dans le TODO. |
| [`docs/tests/scenarios-fonctionnels.md`](docs/tests/scenarios-fonctionnels.md) | Scénarios de tests fonctionnels `TS-…`, un au moins par règle `RG-…`. |
| [`docs/etudes/sms-mms-android.md`](docs/etudes/sms-mms-android.md) | Étude : envoi de SMS et MMS sur Android, règles Google Play, voies possibles. |
| [`docs/etudes/gps-arriere-plan-android.md`](docs/etudes/gps-arriere-plan-android.md) | Étude : GPS en arrière-plan sur Android, batterie, constructeurs, reprise après redémarrage. |
| [`docs/etudes/autorisations-android.md`](docs/etudes/autorisations-android.md) | Étude : autorisations Android, versions concernées, règles Google Play, parcours de demande. |
| [`docs/etudes/localisation-arriere-plan-iphone.md`](docs/etudes/localisation-arriere-plan-iphone.md) | Étude : localisation en arrière-plan sur iPhone, batterie, règles de l'App Store. |
| [`docs/etudes/notes-vocales.md`](docs/etudes/notes-vocales.md) | Étude : notes vocales, formats audio, durée, transcription en français hors connexion. |
| [`docs/textes/avertissement-beta.md`](docs/textes/avertissement-beta.md) | Texte de l'avertissement : version bêta et responsabilité. |
| [`docs/assets/`](docs/assets/) | Logo et images. |
| [`app/`](app/) | Prototype de démonstration Flutter (Android, iPhone, Web), voir son [README](app/README.md). |
| [`server/`](server/) | Serveur central en Go (squelette, TODO-3.7), image Docker et `compose.yaml` pour pi-appliance, voir son [README](server/README.md). |
| [`site/`](site/) | Site de présentation publié sur GitHub Pages (accueil, mémo sécurité en mer, avertissement), par le workflow `.github/workflows/pages.yml`. |

## Statut des informations

- **Décidé** : écrit dans les règles métier ou le cahier des charges, sans renvoi à une question.
- **Ouvert** : renvoie à une question `Q-…` ; une « proposition » y est une suggestion non validée.
- **Évolution future** : listée au §9 du cahier des charges, sans engagement.

Pour travailler avec Claude Code sur ce dépôt, voir [`CLAUDE.md`](CLAUDE.md).
