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
- `lib/reel/` : vraie application. `ConduiteNavigation` (`conduite.dart`) : navigation en cours du téléphone, gardée dans la base locale, et ses envois ; `GpsTelephone` (`gps.dart`, paquet `geolocator`) : positions du téléphone. `ClientApi` (package `http`) : jeton d'accès en `Authorization: Bearer`, renouvellement unique par `POST /v1/sessions/renouvellement` sur 401, erreurs JSON du serveur (`ErreurApi`), `HorsConnexion` sans réponse ; `StockageSession` : jetons et identifiant du téléphone dans les préférences, sans chiffrement matériel (RG-CPT-12) ; `BaseSqlite` (sqflite) : file d'attente, numéros d'ordre et dernières copies reçues, pour l'usage hors connexion (RG-COM-06) — en mémoire sur le Web, où sqflite n'existe pas ; `FileAttente` : RG-COM-05 et [08-architecture.md §5](../docs/08-architecture.md#5-file-dattente-et-doublons) ; `DepotReel` : connexion, création du compte, « Mot de passe oublié ? », association du téléphone, relecture de l'accueil ; `GestionCompte` (`compte.dart`) : contacts, invitations, accès et paramètres généraux, modifications gardées hors connexion et envoyées au retour (D-136).
- `lib/screens/compte.dart` : autres écrans du cahier des charges §5.5, communs aux deux modes (ce qui n'existe que dans la vraie application n'est pas montré dans la démonstration).
- `lib/screens/connexion.dart` : connexion, création du compte avec l'avertissement bêta, nouvelle version de l'avertissement, « Mot de passe oublié ? » ; `lib/screens/memo.dart` : mémo sécurité en mer intégré.

## Vraie application : état (TODO-5.1 à TODO-5.7)

- connexion par e-mail et mot de passe, par Google (`google_sign_in`) et par Apple sur iPhone (`sign_in_with_apple`), ces deux dernières actives avec leurs identifiants clients (section « Services externes ») ;
- « Mes amis en mer » sur Android et iPhone (`lib/screens/suivi_reel.dart`) ; notifications push (`firebase_messaging`, `lib/reel/notifications.dart`) qui ouvrent la navigation ; achat de l'abonnement (`in_app_purchase`, `lib/reel/achats.dart`) ;
- à chaque connexion, le téléphone est enregistré (`PUT /v1/appareils/{id}`, identifiant tiré une fois et gardé) puis associé aux bateaux du compte qui n'en ont pas (D-132) ;
- accueil : navigation en cours, quota (avec l'heure du dernier état reçu hors connexion), adresse à confirmer (« Recevoir un nouveau lien »), « Navigations enregistrées » ; relu à l'ouverture, au retour au premier plan et en tirant la liste vers le bas (D-135) ; les trois boutons et le SOS sont branchés (TODO-5.2 à TODO-5.6) ;
- démarrage (TODO-5.2, `lib/reel/conduite.dart`, `lib/screens/navigation_reel.dart`) : rappel avant la première navigation, écran de démarrage de la démonstration branché sur le serveur (bateau, destination en texte, personnes à bord, fréquence, paramètres de cette navigation, personnes alertées, avertissement sans ami), position acquise au démarrage, envoi par la file d'attente, refus affiché (quota épuisé d'après le dernier état reçu ou message du serveur, D-140), navigation gardée sur le téléphone ; restent le SMS de début, la carte de la destination et « Ajouter une personne » (TODO-5.7) ;
- positions automatiques (TODO-5.3, `lib/reel/gps.dart`) : GPS par le paquet `geolocator`, à la fréquence de la navigation, enregistrées sur le téléphone et envoyées par la file d'attente ; sur Android, service de premier plan de `geolocator` avec notification permanente pendant la navigation ; reprise à la réouverture ; sans réponse du GPS, position « GPS non disponible » (D-139) ; restent l'essai de 8 heures écran éteint, la batterie (RG-GPS-05), l'autorisation des notifications et la notification après redémarrage ;
- SMS (Android, TODO-5.4, TODO-5.5, `lib/reel/sms.dart`, `lib/reel/sms_navigation.dart`, canal natif `fr.nautilink/sms` de `android/.../MainActivity.kt`) : tous les SMS (SOS, positions, début, notes, photos avec le lien, notes vocales, fin, invitations) envoyés automatiquement par `SmsManager` avec la permission `SEND_SMS` (demandée au démarrage d'une navigation, D-158), états d'envoi et de réception, nouveaux essais (RG-SMS-07) ; sans la permission, SMS préremplis dans l'application SMS ; MMS prérempli pour la photo si prévu ; copie au navigateur ; aucun SMS sur iPhone ;
- batterie et redémarrage (Android, `lib/reel/telephone.dart`, `RedemarrageRecepteur.kt`) : exclusion de l'optimisation de la batterie au premier démarrage (RG-GPS-05), autorisation des notifications, notification après un redémarrage pendant une navigation (RG-NAV-12) ;
- iPhone : positions en arrière-plan (`UIBackgroundModes` `location`), avertissement au démarrage (RG-IOS-04), SOS sans Internet (RG-IOS-03) ;
- position manuelle, NOTE, Photo, Vocal (TODO-5.4, `lib/reel/medias.dart`) : appareil photo du téléphone (`image_picker`), notes vocales AAC d'une minute au plus (`record`), événements et fichiers envoyés par la file d'attente, résultat de chaque circuit dans la fenêtre « OK » ;
- SOS (TODO-5.5) : depuis l'accueil et l'écran de navigation, confirmation avec « Problème rencontré », position actuelle ou dernière connue, alerte envoyée au serveur en priorité (e-mails par le serveur), SMS SOS envoyés automatiquement, ou préremplis sans la permission (D-142, RG-SOS-16) ;
- fin et reprise (TODO-5.6) : « Terminer la navigation » avec confirmation, fin gardée avec son heure réelle et envoyée par la file, puis récapitulatif de la navigation dans l'application, avec « Retour à l'accueil » (`lib/screens/recapitulatif_reel.dart`, D-190 ; données du téléphone hors connexion) ; « Reprendre la dernière navigation » rouvre la navigation gardée sur le téléphone, ou celle que le serveur dit en cours (D-140) ; restent le SMS de fin et la notification après redémarrage ;
- menu de l'accueil (TODO-5.7) : « Contacts » : une seule liste d'amis, sans case de rôle ; ajout, modification, suppression, périmètre *navigateur* ou *navigation*, invitation par e-mail ou par téléphone (lien affiché, « Envoyer par SMS » prérempli sur Android, « Copier le lien » sur iPhone : D-137), annulation, changement de périmètre, retrait ; liste gardée sur le téléphone et modifiable hors connexion, envoyée au retour (D-136) ;
- « Paramètres » : fréquence par défaut, SMS, types de SMS, photo en MMS, synchronisés champ par champ avec le Web ; sur iPhone, mention que les SMS sont sans effet (D-137) ;
- « Alertes SOS » (historique, statuts des SMS, e-mails ; alertes encore en file hors connexion), « Assistance » (« Écrire à l'équipe NautiLink » vers la page de suivi du projet en attendant une adresse : D-138 ; avertissement bêta ; mémo), « Quota et abonnement » (« Souscrire l'abonnement » : achat Google Play et App Store pas encore ouvert, TODO-5.8, TODO-10.6) ;
- mémo sécurité en mer : copie de `site/securite.html` dans `assets/memo/`, faite par `outils/copier-memo.sh` (lancé par le workflow avant les essais et les constructions ; `test/memo_test.dart` échoue si la copie est périmée) ; ouvert dans l'application sur Android et iPhone, dans les deux modes, et sur le site depuis la démonstration Web (RG-SOS-22).

## Services externes : réglages de construction

Le code est prêt ; chaque service reste inactif tant que ses identifiants ne sont pas donnés (`--dart-define=…` à la construction, et variables du serveur, voir [`server/README.md`](../server/README.md)) :

| Service | Application (`--dart-define`) | Reste à faire hors du code |
|---------|-------------------------------|----------------------------|
| Connexion par Google (RG-CPT-02) | `NAUTILINK_GOOGLE_SERVEUR` (identifiant client OAuth de type Web), `NAUTILINK_GOOGLE_IOS` (identifiant client iOS) | créer les identifiants dans Google Cloud, empreinte SHA-1 de la clé de signature Android, schéma d'URL inversé dans `ios/Runner/Info.plist` ; serveur : `NAUTILINK_GOOGLE_CLIENTS` |
| Connexion par Apple (iPhone) | `NAUTILINK_APPLE=1` | capacité « Sign in with Apple » dans Xcode (fichier d'autorisations) ; serveur : `NAUTILINK_APPLE_CLIENTS` |
| Notifications push (RG-IOS-06, RG-AND-08) | `NAUTILINK_FCM_CLE`, `NAUTILINK_FCM_APPLICATION` (identifiant de l'application Firebase de la plateforme), `NAUTILINK_FCM_EXPEDITEUR`, `NAUTILINK_FCM_PROJET` | projet Firebase ; sur iPhone, capacité « Push Notifications » et clé APNs ; serveur : `NAUTILINK_FCM_COMPTE`, `NAUTILINK_APNS_*` |
| Achat de l'abonnement (RG-ECO-11, RG-IOS-07) | `NAUTILINK_PRODUIT` (par défaut `nautilink_abonnement_10_ans`) | produit « achat unique » à 15 € dans la Google Play Console et App Store Connect ; serveur : `NAUTILINK_GOOGLE_PLAY_COMPTE`, `NAUTILINK_APP_STORE_*` |

Sans ces réglages : boutons Google et Apple désactivés, aucune notification push, « Souscrire l'abonnement » dit que l'achat n'est pas encore ouvert.

## Ce que montre la démonstration

La démonstration V0 est terminée ([D-144](../docs/07-decisions.md#d-144)) : le site la publie toujours telle qu'au commit `8ac9c1a` (version 0.0.1), reconstruite depuis ce commit par le workflow « Site GitHub Pages ». Le mode démonstration reste dans le code, mais ce qui est publié ne suit plus `app/`.

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
- contacts (amis), paramètres SMS, quota ;
- tableau de bord Web : navigations en cours et historique, filtre navigateur / ami, carte du tracé, journal.

Sur le Web, un premier écran propose de jouer le navigateur (dans un cadre de téléphone) ou l'ami.

## Langues

Textes des écrans dans `lib/l10n/` (TODO-9.2, [Q-27](../docs/06-questions-ouvertes.md#q-27)) : `app_fr.arb`, langue de référence, dont les libellés sont ceux que cite la spécification (à modifier ensemble) ; `app_en.arb`, traduction d'essai non relue. `flutter pub get` régénère `app_localizations*.dart` (configuration : `l10n.yaml`). Le français est la langue par défaut ; essai en anglais : `flutter run --dart-define=NAUTILINK_LANG=en`. Restent en français dans le code : le contenu des SMS et du journal, et les textes de `lib/data.dart` (types d'événements, fréquences, dates).

## Signature de l'APK de production

L'APK de production (`nautilink.apk`) est signé par le workflow « Site GitHub Pages » avec une clé fixe, pour que chaque version s'installe par-dessus la précédente (D-145). La clé se crée une fois (`keytool -genkeypair -keystore nautilink-production.jks -alias nautilink -keyalg RSA -keysize 4096 -validity 10000`), se garde hors du dépôt avec ses mots de passe, et se donne au dépôt GitHub par quatre secrets (Settings → Secrets and variables → Actions) : `ANDROID_KEYSTORE_BASE64` (le fichier en base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (facultatif : sans lui, celui du fichier, le même pour une clé PKCS12 créée par `keytool`). Sans ces secrets, et sur un poste de développement, la clé de débogage sert (`android/app/build.gradle.kts`, variables `NAUTILINK_KEYSTORE…`). La démonstration V0 reste signée avec la clé de débogage.

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
