# NautiLink — prototype de démonstration

Application Flutter, un seul code pour Android, iPhone et la démonstration Web ([D-57](../docs/07-decisions.md#d-57), [D-58](../docs/07-decisions.md#d-58)).

**Démonstration seulement** : données d'exemple, aucun serveur, rien n'est réellement envoyé (ni SMS, ni e-mail, ni position). La spécification fait foi : [`docs/02-regles-metier.md`](../docs/02-regles-metier.md).

## Ce que montre le prototype

- avertissement bêta à accepter (RG-CPT-06) et rappel avant la première navigation (RG-NAV-23) ;
- accueil mobile : « Démarrer navigation », « Reprendre la dernière navigation », « Navigations enregistrées », bouton SOS ;
- démarrage : bateau, destination facultative, nombre de personnes à bord, personnes alertées (cochées, ajout d'un contact), fréquence de 15 minutes à 10 jours, paramètres de la navigation ;
- note vocale enregistrée (simulée), sans transcription ; SOS avec « Problème rencontré » ;
- après la fin : page détaillée de la navigation (météo au départ et à l'arrivée, lieux, carte OpenStreetMap et OpenSeaMap, journal avec photos et écoute) ;
- navigation en cours : deux chronomètres (le second remis à zéro par chaque envoi), position, NOTE, Photo, Vocal, SOS avec confirmation, fin ; résultat de chaque envoi dans une fenêtre « OK » fermée au bout d'une minute ;
- proposition de terminer une navigation immobile depuis 2 heures (menu « Démo : simuler 2 h sans bouger ») ;
- lien « Version gratuite - abonnement » sur l'accueil, puis lien vers la page d'information sur l'abonnement du site ;
- contacts (cases « Suiveur » et « Contact SOS »), paramètres SMS, quota ;
- tableau de bord Web : navigations en cours et historique, filtre navigateur / suiveur, carte du tracé, journal.

Sur le Web, un premier écran propose de jouer le navigateur (dans un cadre de téléphone) ou le suiveur.

## Langues

Textes des écrans dans `lib/l10n/` (TODO-9.2, [Q-27](../docs/06-questions-ouvertes.md#q-27)) : `app_fr.arb`, langue de référence, dont les libellés sont ceux que cite la spécification (à modifier ensemble) ; `app_en.arb`, traduction d'essai non relue. `flutter pub get` régénère `app_localizations*.dart` (configuration : `l10n.yaml`). Le français est la langue par défaut ; essai en anglais : `flutter run --dart-define=NAUTILINK_LANG=en`. Restent en français dans le code : le contenu des SMS et du journal, et les textes de `lib/data.dart` (types d'événements, fréquences, dates).

## Commandes

Flutter 3.47.9 (version fixée aussi dans `.github/workflows/pages.yml`).

```bash
flutter test                                  # parcours avertissement → SOS → fin
flutter analyze
flutter build web --release --base-href /NautiLink/app/ --no-web-resources-cdn
flutter build apk --release                   # APK de démonstration (signature de débogage)
```

Le workflow « Site GitHub Pages » construit et publie sur le site, sans passer par les stores : la démonstration Web (`app/`), l'APK Android (`downloads/nautilink-demo.apk`), l'IPA iPhone non signé (`downloads/nautilink-demo-ios-non-signe.ipa`, construit sur macOS) et `downloads/SHA256SUMS.txt`. Mode d'emploi : `site/telecharger.html`.

Paramètres du workflow : en lancement manuel (« Actions » → « Site GitHub Pages » → « Run workflow »), les cases « website » (pages du site et démonstration Web), « android » et « iphone », cochées par défaut, choisissent les livrables à reconstruire ; sur un push dans `main`, le site est toujours reconstruit, les applications Android et iPhone seulement si `app/` ou le workflow ont changé. Un site non reconstruit reprend l'artefact `site-source` de la dernière exécution réussie (conservé 90 jours). Une application non reconstruite reprend le fichier déjà publié sur le site, avec son commit (`downloads/COMMITS.txt`). Versions ([docs/09-versions.md](../docs/09-versions.md), D-128) : application selon `version:` de `pubspec.yaml`, site selon `site/VERSION`, build = numéro d'exécution du workflow. Le pied de page de tous les écrans de l'application (`AppFrame` dans `lib/theme.dart`) et de chaque page du site donne : « Tous droits réservés · https://github.com/gmoulard/NautiLink · V0.0.1 · build n · commit abcdef0 » (`--dart-define=NAUTILINK_VERSION`, `NAUTILINK_BUILD`, `NAUTILINK_COMMIT` ; « version locale » en local) ; sur `telecharger.html`, la version, le build et le commit de chaque application sont sous son bouton.
