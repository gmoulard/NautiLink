# NautiLink — application mobile et démonstration

Application Flutter, un seul code pour Android, iPhone et la démonstration Web ([D-57](../docs/07-decisions.md#d-57), [D-58](../docs/07-decisions.md#d-58)).

Le prototype devient la vraie application, dans le même projet ([D-127](../docs/07-decisions.md#d-127)) : les écrans sont gardés, les données d'exemple remplacées par le serveur. Le mode est choisi à la construction :

| Mode | Construction | Données |
|------|--------------|---------|
| Démonstration (par défaut) | `flutter build …` ou `--dart-define=NAUTILINK_MODE=demo` | données d'exemple, aucun serveur, rien n'est réellement envoyé (ni SMS, ni e-mail, ni position) ; publiée sur le site (`nautilink-demo.apk`, IPA, démonstration Web) ; sur Android : `fr.nautilink.nautilink.demo`, « NautiLink démo » |
| Vraie application | `--dart-define=NAUTILINK_MODE=reel` | serveur central, adresse `--dart-define=NAUTILINK_API=…` (par défaut `https://vdl.moulard.org/nautilink/api`) ; publiée sur le site (`nautilink.apk`, `nautilink-ios-non-signe.ipa`, D-129) ; sur Android : `fr.nautilink.nautilink`, « NautiLink » |

La spécification fait foi : [`docs/02-regles-metier.md`](../docs/02-regles-metier.md).

## Organisation du code

- `lib/depot/` : dépôt de données commun aux deux modes (`Depot` : navigations, bateaux, contacts, paramètres, quota, alertes SOS, session), avec les interfaces prévues pour la suite : `Envois` (file d'attente : démarrage, événement, fin, alerte SOS, statuts des SMS, fichier ; flux `reussis` pour le chronomètre du dernier envoi, RG-NAV-10) et `SourcePosition` (GPS). `DepotDemo` présente les données d'exemple de `lib/data.dart`, que les écrans de la démonstration continuent d'utiliser.
- `lib/reel/` : vraie application. `ClientApi` (package `http`) : jeton d'accès en `Authorization: Bearer`, renouvellement unique par `POST /v1/sessions/renouvellement` sur 401, erreurs JSON du serveur (`ErreurApi`), `HorsConnexion` sans réponse ; `StockageSession` : jetons et identifiant du téléphone dans les préférences, sans chiffrement matériel (RG-CPT-12) ; `BaseSqlite` (sqflite) : file d'attente, numéros d'ordre et dernières copies reçues, pour l'usage hors connexion (RG-COM-06) — en mémoire sur le Web, où sqflite n'existe pas ; `FileAttente` : RG-COM-05 et [08-architecture.md §5](../docs/08-architecture.md#5-file-dattente-et-doublons) ; `DepotReel` : connexion, création du compte, « Mot de passe oublié ? », association du téléphone, relecture de l'accueil ; `GestionCompte` (`compte.dart`) : contacts, invitations, accès et paramètres généraux, modifications gardées hors connexion et envoyées au retour (Q-86).
- `lib/screens/compte.dart` : autres écrans du cahier des charges §5.5, communs aux deux modes (ce qui n'existe que dans la vraie application n'est pas montré dans la démonstration).
- `lib/screens/connexion.dart` : connexion, création du compte avec l'avertissement bêta, nouvelle version de l'avertissement, « Mot de passe oublié ? » ; `lib/screens/memo.dart` : mémo sécurité en mer intégré.

## Vraie application : état (TODO-5.1, TODO-5.7)

- connexion par e-mail et mot de passe ; les boutons « Continuer avec Google » et « Continuer avec Apple » sont présents mais **désactivés** : il faut créer les identifiants clients OAuth (Google : Android, iPhone, Web ; Apple : identifiant de l'application et Services ID), les déclarer au serveur (`NAUTILINK_GOOGLE_CLIENTS`, `NAUTILINK_APPLE_CLIENTS`, voir `server/README.md`) et ajouter les paquets de connexion à l'application ;
- à chaque connexion, le téléphone est enregistré (`PUT /v1/appareils/{id}`, identifiant tiré une fois et gardé) puis associé aux bateaux du compte qui n'en ont pas (Q-81) ;
- accueil : navigation en cours, quota (avec l'heure du dernier état reçu hors connexion), adresse à confirmer (« Recevoir un nouveau lien »), « Navigations enregistrées » ; relu à l'ouverture, au retour au premier plan et en tirant la liste vers le bas (Q-84) ; « Démarrer navigation », « Reprendre la dernière navigation » et le SOS affichent pour l'instant un message d'attente (TODO-5.2, TODO-5.3, TODO-5.5) ;
- menu de l'accueil (TODO-5.7) : « Contacts » : cases « Suiveur » et « Contact SOS », ajout, modification, suppression, périmètre *navigateur* ou *navigation*, invitation par e-mail ou par téléphone (lien affiché, « Envoyer par SMS » prérempli sur Android, « Copier le lien » sur iPhone : Q-87), annulation, changement de périmètre, retrait ; liste gardée sur le téléphone et modifiable hors connexion, envoyée au retour (Q-86) ;
- « Paramètres » : fréquence par défaut, SMS, types de SMS, photo en MMS, synchronisés champ par champ avec le Web ; sur iPhone, mention que les SMS sont sans effet (Q-87) ;
- « Alertes SOS » (historique, statuts des SMS, e-mails ; alertes encore en file hors connexion), « Assistance » (« Écrire à l'équipe NautiLink » vers la page de suivi du projet en attendant une adresse : Q-88 ; avertissement bêta ; mémo), « Quota et abonnement » (« Souscrire l'abonnement » : achat Google Play et App Store pas encore ouvert, TODO-5.8, TODO-10.6) ;
- mémo sécurité en mer : copie de `site/securite.html` dans `assets/memo/`, faite par `outils/copier-memo.sh` (lancé par le workflow avant les essais et les constructions ; `test/memo_test.dart` échoue si la copie est périmée) ; ouvert dans l'application sur Android et iPhone, dans les deux modes, et sur le site depuis la démonstration Web (RG-SOS-22).

## Ce que montre la démonstration

- avertissement bêta à accepter (RG-CPT-06) et rappel avant la première navigation (RG-NAV-23) ;
- accueil mobile : « Démarrer navigation », « Reprendre la dernière navigation », « Navigations enregistrées », bouton SOS ;
- démarrage : bateau, destination facultative, nombre de personnes à bord, personnes alertées (cochées, ajout d'un contact), fréquence de 15 minutes à 10 jours, paramètres de la navigation ;
- note vocale enregistrée (simulée), sans transcription ; SOS avec « Problème rencontré » ;
- après la fin : page détaillée de la navigation (météo au départ et à l'arrivée, lieux, carte OpenStreetMap et OpenSeaMap, journal avec photos et écoute) ;
- navigation en cours : deux chronomètres (le second remis à zéro par chaque envoi), position, NOTE, Photo, Vocal, SOS avec confirmation, fin ; résultat de chaque envoi dans une fenêtre « OK » fermée au bout d'une minute ;
- proposition de terminer une navigation immobile depuis 2 heures (menu « Démo : simuler 2 h sans bouger ») ;
- lien « Version gratuite » (« Version abonné » avec un abonnement) en bas de l'accueil, entre le guidon de la SRT et le mémo sécurité (D-131), puis lien vers la page d'information sur l'abonnement du site ;
- lien « Mémo sécurité en mer » sur l'accueil : mémo intégré, lisible hors connexion, sur Android et iPhone ; page du site depuis la démonstration Web (TODO-3.12, RG-SOS-22) ;
- sous le bandeau du sponsor, petit lien « Site de NautiLink » vers le site de présentation (TODO-3.13) ;
- contacts (cases « Suiveur » et « Contact SOS »), paramètres SMS, quota ;
- tableau de bord Web : navigations en cours et historique, filtre navigateur / suiveur, carte du tracé, journal.

Sur le Web, un premier écran propose de jouer le navigateur (dans un cadre de téléphone) ou le suiveur.

## Langues

Textes des écrans dans `lib/l10n/` (TODO-9.2, [Q-27](../docs/06-questions-ouvertes.md#q-27)) : `app_fr.arb`, langue de référence, dont les libellés sont ceux que cite la spécification (à modifier ensemble) ; `app_en.arb`, traduction d'essai non relue. `flutter pub get` régénère `app_localizations*.dart` (configuration : `l10n.yaml`). Le français est la langue par défaut ; essai en anglais : `flutter run --dart-define=NAUTILINK_LANG=en`. Restent en français dans le code : le contenu des SMS et du journal, et les textes de `lib/data.dart` (types d'événements, fréquences, dates).

## Commandes

Flutter 3.47.9 (version fixée aussi dans `.github/workflows/pages.yml`).

```bash
./outils/copier-memo.sh                       # après une modification de site/securite.html
flutter test                                  # démonstration, client de l'API, file d'attente, mode réel (faux serveur)
flutter analyze
flutter run --dart-define=NAUTILINK_MODE=reel --dart-define=NAUTILINK_API=http://10.0.2.2:8080/nautilink/api   # émulateur Android, serveur local
flutter build web --release --base-href /NautiLink/app/ --no-web-resources-cdn
flutter build apk --release                   # APK de démonstration (signature de débogage)
```

Essai de bout en bout contre le serveur local (`server/`, voir `server/README.md`), sauté sans `NAUTILINK_API_ESSAI` ; `NAUTILINK_BASE_ESSAI` (facultatif, `psql` requis) confirme l'adresse du compte créé pour essayer aussi la file d'attente :

```bash
NAUTILINK_API_ESSAI=http://127.0.0.1:8080/nautilink/api \
NAUTILINK_BASE_ESSAI='postgres://nautilink@127.0.0.1:5432/nautilink' \
  flutter test test/essai_serveur_test.dart
```

Le workflow « Site GitHub Pages » construit et publie sur le site, sans passer par les stores : la démonstration Web (`app/`), l'APK Android (`downloads/nautilink-demo.apk`), l'IPA iPhone non signé (`downloads/nautilink-demo-ios-non-signe.ipa`, construit sur macOS) et `downloads/SHA256SUMS.txt`. Mode d'emploi : `site/telecharger.html`.

Paramètres du workflow : en lancement manuel (« Actions » → « Site GitHub Pages » → « Run workflow »), les cases « website » (pages du site et démonstration Web), « android » et « iphone », cochées par défaut, choisissent les livrables à reconstruire ; sur un push dans `main`, le site est toujours reconstruit, les applications Android et iPhone seulement si `app/`, le mémo `site/securite.html` (intégré aux applications) ou le workflow ont changé. Un site non reconstruit reprend l'artefact `site-source` de la dernière exécution réussie (conservé 90 jours). Une application non reconstruite reprend le fichier déjà publié sur le site, avec son commit (`downloads/COMMITS.txt`). Versions ([docs/09-versions.md](../docs/09-versions.md), D-128) : application selon `version:` de `pubspec.yaml`, site selon `site/VERSION`, build = numéro d'exécution du workflow. Le pied de page de tous les écrans de l'application (`AppFrame` dans `lib/theme.dart`) et de chaque page du site donne : « Tous droits réservés · https://github.com/gmoulard/NautiLink · V0.0.1 · build n · commit abcdef0 » (`--dart-define=NAUTILINK_VERSION`, `NAUTILINK_BUILD`, `NAUTILINK_COMMIT` ; « version locale » en local) ; sur `telecharger.html`, la version, le build et le commit de chaque application sont sous son bouton.
