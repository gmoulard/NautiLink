# TODO

Feuille de route de NautiLink, dans l'ordre de construction : décisions, études, préparation, serveur, Android, Web, administration, lancement, puis iPhone. Les identifiants `RG-…` renvoient aux [règles métier](02-regles-metier.md), les `Q-nn` aux [questions ouvertes](06-questions-ouvertes.md), les `D-nn` au [journal des décisions](07-decisions.md).

États : `[ ]` à faire ; `[~]` en cours ou à vérifier (fait, mais pas encore validé) ; `[!]` bloqué (attend une décision, un accès ou un matériel : la raison est dite) ; `[x]` réalisé et validé. Une action ouverte dit de quoi elle dépend (« Dépend de : ») et ses critères d'acceptation ; elle n'est cochée `[x]` qu'une fois ses critères remplis. Les actions réalisées tiennent sur une ligne ; une fois validées, elles sont déplacées dans [Actions réalisées](Todo-done.md), sauf si un de leurs points reste ouvert.

## Lots

Groupes d'actions cohérents, réalisés chacun par le sous-agent `todo-lot` (une action = un commit poussé). Un lot de décisions rend les questions à poser : le sous-agent ne tranche rien.

| Lot | Titre | Actions | Dépend de | État |
|-----|-------|---------|-----------|------|
| LOT-1 | Décisions sur les navigations et le partage | TODO-1.4, TODO-1.5, TODO-1.6, TODO-1.7, TODO-1.8, TODO-1.11, TODO-1.19 | aucun | [!] |
| LOT-2 | Décisions sur les notifications, le quota et l'abonnement | TODO-1.12, TODO-1.13, TODO-1.14, TODO-10.1, TODO-1.20 | aucun | [!] |
| LOT-3 | Décisions sur l'administration, les données et la conformité | TODO-1.15, TODO-1.16, TODO-1.17 | aucun | [x] |
| LOT-4 | Études SMS et MMS sur Android | TODO-2.1, TODO-2.3, TODO-2.4, TODO-1.10, TODO-1.21 | aucun | [~] |
| LOT-5 | Études GPS, batterie, reprise et notes vocales | TODO-2.2, TODO-10.2, TODO-1.9, TODO-2.5 | aucun | [~] |
| LOT-6 | Architecture, API et synchronisation | TODO-3.1, TODO-3.2, TODO-2.7, TODO-2.6, TODO-3.4, TODO-3.7 | LOT-4, LOT-5 | [~] |
| LOT-7 | Maquettes, scénarios de tests et prototype | TODO-3.3, TODO-3.5, TODO-3.6, TODO-3.8, TODO-3.9, TODO-3.10 | aucun | [~] |
| LOT-8 | Serveur : comptes, bateaux, contacts, paramètres | TODO-4.1, TODO-4.2, TODO-4.3, TODO-4.4 | LOT-1, LOT-6 | [ ] |
| LOT-9 | Serveur : navigations, quota, SOS, corbeille | TODO-4.5, TODO-4.6, TODO-4.7, TODO-4.8 | LOT-2, LOT-8 | [ ] |
| LOT-10 | Android : accueil, démarrage, positions, SOS | TODO-5.1, TODO-5.2, TODO-5.3, TODO-5.5 | LOT-7, LOT-9 | [ ] |
| LOT-11 | Android : journal, fin, contacts, abonnement | TODO-5.4, TODO-5.6, TODO-5.7, TODO-5.8 | LOT-10 | [ ] |
| LOT-12 | Web : consultation des navigations | TODO-6.1, TODO-6.2, TODO-6.3, TODO-6.4 | LOT-7, LOT-9 | [ ] |
| LOT-13 | Web : compte, suiveur, abonnement | TODO-6.5, TODO-6.6, TODO-6.7 | LOT-12 | [ ] |
| LOT-14 | Administration | TODO-7.1 | LOT-3, LOT-8 | [ ] |
| LOT-15 | Marque et publication Android | TODO-8.1, TODO-8.2, TODO-8.3, TODO-8.4, TODO-8.5 | LOT-3, LOT-11 | [~] |
| LOT-16 | Application iPhone | TODO-10.3, TODO-10.4, TODO-10.5, TODO-10.6, TODO-10.7 | LOT-11, LOT-13, LOT-15 | [ ] |
| LOT-17 | Évolutions futures | TODO-9.1, TODO-9.2, TODO-9.3 | LOT-13, LOT-14 | [ ] |

## 0. Ménage du dépôt

Tout est réalisé : voir [Actions réalisées](Todo-done.md).

## 1. Décisions

Pour chaque action : critères d'acceptation communs — choix de l'utilisateur tracé en `D-nn`, règle écrite dans les règles métier, question retirée des questions ouvertes.

- [!] **TODO-1.19**: Changer les heures d'une navigation : effet sur le quota et les positions ([Q-34](06-questions-ouvertes.md#q-34), RG-NAV-22). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.21**: SMS préremplis : positions automatiques et nouvelles tentatives ([Q-36](06-questions-ouvertes.md#q-36), RG-SMS-03). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.14**: Prix et règles de paiement de l'abonnement ([Q-17](06-questions-ouvertes.md#q-17), RG-ECO-06, RG-ECO-07). Tranché le 2026-11-24 : une seule formule, mensuelle ou annuelle, sans essai (D-43). Dépend de : aucune.
  - Critères d'acceptation : communs, dans le modèle économique. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.20**: Seuil d'une position en retard ([Q-35](06-questions-ouvertes.md#q-35), RG-IOS-06). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.

## 2. Études techniques

- [~] **TODO-2.1**: **À faire en premier.** Envoi de SMS par une application Android publiée sur Google Play ([Q-12](06-questions-ouvertes.md#q-12), RG-COM-01). Tout le circuit SMS en dépend, SOS compris. Dépend de : aucune.
  - Critères d'acceptation : règles actuelles de Google Play sur la permission SMS lues et citées ; voie retenue par l'utilisateur (exception demandée, application SMS préremplie, distribution hors Play Store…) et écrite dans les règles métier.
  - Fait : [étude documentaire](etudes/sms-mms-android.md) (règles Google Play, voies A à D, API `SmsManager`). Reste : relire en entier les pages d'aide Google Play (inaccessibles lors de la rédaction) ; choix de la voie par l'utilisateur, puis règles métier et `D-nn`.
  - Tranché le 2026-11-24 (D-48) : exception « urgence » pour les SMS SOS, SMS ordinaires préremplis. Reste : vérifier l'exception sur la page officielle de Google Play.
- [~] **TODO-2.2**: GPS en arrière-plan, écran éteint, et consommation de batterie ([Q-09](06-questions-ouvertes.md#q-09), RG-GPS-03). Dépend de : aucune.
  - Critères d'acceptation : prototype qui enregistre une position toutes les 15 minutes pendant 8 heures, écran éteint, sur au moins trois marques de téléphones (dont Samsung et Xiaomi) ; positions manquantes et batterie consommée notées.
  - Fait : [étude documentaire](etudes/gps-arriere-plan-android.md) (service de premier plan `location`, autorisations, Doze, constructeurs, reprise au redémarrage, protocole d'essai). Reste : prototype sur trois marques (dont Samsung et Xiaomi) avec mesures ; relire dontkillmyapp.com et la politique Google Play (inaccessibles lors de la rédaction).
  - Tranché le 2026-11-24 (D-51, D-52) : reprise au lancement, exclusion de l'optimisation de la batterie et aide par marque.
- [~] **TODO-2.3**: Autorisations Android et versions visées ([Q-31](06-questions-ouvertes.md#q-31)). Dépend de : TODO-2.1, TODO-2.2.
  - Critères d'acceptation : liste des autorisations (localisation en arrière-plan, SMS, appareil photo, micro, notifications), version minimale d'Android choisie, parcours de demande des autorisations dessiné.
  - Fait (2026-11-25) : [étude documentaire](etudes/autorisations-android.md) : 12 autorisations avec versions d'Android et règles Google Play, version visée API 36, version minimale proposée (Android 8.0), parcours de demande en Mermaid (propositions dans Q-31). Tranché le 2026-11-25 (D-80) : Android 8.0 au minimum, autorisations demandées au moment où elles servent et redemandées à chaque besoin, localisation refusée : navigation sans positions (RG-AND-01 à RG-AND-03). Tranché aussi (D-81) : SMS refusé, réveil par minuterie (RG-AND-04, RG-AND-05). Reste : relire les pages Google Play (inaccessibles lors de la rédaction) ; choix de l'appareil photo et de la SIM (Q-31) ; essai du parcours sur le prototype de TODO-2.2.
- [~] **TODO-2.4**: MMS : taille, opérateurs, repli ([Q-13](06-questions-ouvertes.md#q-13), RG-SMS-05). Dépend de : TODO-2.1.
  - Critères d'acceptation : MMS avec photo envoyé et reçu chez les quatre opérateurs français ; taille maximale et comportement en cas d'échec écrits.
  - Fait : [étude documentaire](etudes/sms-mms-android.md#5-mms-todo-24) (API, taille lue sur le téléphone, repères 300/600 Ko non officiels). Reste : essai chez les quatre opérateurs ; choix de la taille et du comportement en cas d'échec par l'utilisateur.
  - Tranché le 2026-11-24 (D-49) : en cas d'échec, SMS avec le lien. Reste : mesures chez les opérateurs.
- [~] **TODO-2.5**: Notes vocales : format, durée, transcription ([D-53](07-decisions.md#d-53), RG-JRN-04). Dépend de : aucune.
  - Critères d'acceptation : format et durée maximale choisis ; transcription en français essayée hors connexion et en ligne, avec le taux d'erreur constaté.
  - Fait : [étude documentaire](etudes/notes-vocales.md) (formats AAC, Opus, AMR ; moteurs Android, iPhone, Whisper ; limite d'une minute sur iPhone ; protocole d'essai). Reste : essais de transcription en français et taux d'erreur ; choix du format, de la durée et du moteur par l'utilisateur.
  - Tranché le 2026-11-24 (D-53) : AAC `.m4a`, 1 minute, moteur du téléphone. Reste : essais de transcription et taux d'erreur.
- [ ] **TODO-2.6**: Fonctionnement hors connexion de chaque écran Android ([Q-29](06-questions-ouvertes.md#q-29)). Dépend de : TODO-3.1.
  - Critères d'acceptation : tableau écran par écran (sans Internet, sans réseau mobile, sans les deux), validé par l'utilisateur.
- [ ] **TODO-2.7**: File d'attente des envois et doublons ([Q-10](06-questions-ouvertes.md#q-10), RG-GPS-04). Dépend de : TODO-3.2.
  - Critères d'acceptation : mécanisme écrit (identifiant unique par événement, ordre, renvoi) et essayé avec une coupure de 2 heures.

## 3. Préparation du développement

- [~] **TODO-3.1**: Architecture technique : hébergement, base de données, stockage des photos et notes vocales, envoi des e-mails ([Q-22](06-questions-ouvertes.md#q-22)). Dépend de : TODO-2.1.
  - Critères d'acceptation : document d'architecture dans `docs/`, schéma Mermaid, choix validés par l'utilisateur.
  - Fait (2026-11-25) : [08-architecture.md](08-architecture.md) avec schéma Mermaid, choix décidés (D-58 à D-62 et suivantes) et propositions non validées reportées dans Q-22 (fichiers, hébergeur après la bêta, push, sauvegardes, e-mails, géocodage). Reste : validation par l'utilisateur.
- [ ] **TODO-3.2**: API et formats de données, synchronisation Android ↔ serveur ↔ Web ([Q-22](06-questions-ouvertes.md#q-22)). Dépend de : TODO-3.1.
  - Critères d'acceptation : description de l'API (OpenAPI) couvrant chaque règle `RG-…` qui passe par le serveur.
- [~] **TODO-3.3**: Maquettes Android et Web ([Q-30](06-questions-ouvertes.md#q-30)). Dépend de : aucune.
  - Critères d'acceptation : un écran par section des §5 et §6 du cahier des charges, thèmes clair et sombre, validés par l'utilisateur.
  - Fait (2026-11-24) : [maquettes Android et Web](../site/designs/app.html) en design « Radar de pluie » : 9 écrans Android (accueil, démarrage, navigation, résultat d'envoi, bateau immobile, confirmation et résultat du SOS, quota, contacts) et 2 écrans Web (tableau de bord, suivi d'une navigation), avec les règles illustrées. Reste : thème sombre, écrans manquants (paramètres, bateaux, corbeille, administration), validation par l'utilisateur.
- [ ] **TODO-3.4**: Environnements de développement, de test et de production ([Q-22](06-questions-ouvertes.md#q-22)). Dépend de : TODO-3.1.
  - Critères d'acceptation : trois environnements décrits ; déploiement de test reproductible.
- [~] **TODO-3.6**: Prototype de démonstration en Flutter, données d'exemple, sans serveur (`app/`, D-57, D-58). Dépend de : aucune.
  - Critères d'acceptation : démonstration Web en ligne sur le site ; APK Android de démonstration téléchargeable depuis le site et installé sur un vrai téléphone ; écrans conformes au cahier des charges §5 et §6 ; relu par l'utilisateur.
  - Fait (2026-11-24) : application Flutter dans `app/`, test de parcours et analyse sans erreur, démonstration Web vérifiée dans Chromium ; le workflow « Site GitHub Pages » construit la démonstration Web et l'APK et les publie avec le site. Reste : activer GitHub Pages, installer l'APK sur un vrai téléphone, relecture.
  - Ajouté (2026-11-24, D-61) : page « Télécharger » (`site/telecharger.html`), IPA iPhone non signé construit sur macOS, démonstration Web installable sur l'écran d'accueil, `SHA256SUMS.txt`. Reste : essai de l'IPA avec AltStore ou Sideloadly sur un vrai iPhone.
- [~] **TODO-3.8**: Demandes du 2026-11-24 sur l'application mobile (boîte de réception) : logo sans coins blancs, fréquences de 15 minutes à 10 jours (RG-NAV-05), chronomètre remis à zéro par tout envoi (RG-NAV-10), fenêtre de résultat avec « OK » fermée au bout d'une minute (RG-COM-03), proposition de fin si immobile 2 heures (RG-NAV-24), lien « Version gratuite - abonnement » et page d'information sur l'abonnement (RG-ECO-10). Dépend de : TODO-3.6.
  - Critères d'acceptation : chaque point visible dans le prototype et sur le site, couvert par un test quand c'est possible ; relu par l'utilisateur.
  - Fait (2026-11-24) : les six points dans le prototype (5 tests) et sur le site (`site/abonnement.html`, fréquence de l'accueil, logo). Reste : relecture par l'utilisateur sur la démonstration en ligne.
- [~] **TODO-3.9**: Choisir le design du site et de l'application parmi les 11 propositions de la [planche](../site/designs/index.html) (dont la 11 aux couleurs du guidon de la SRT), puis l'appliquer. Préférée le 2026-11-24 : la 7 « Météo marine », déclinée en 10 variantes ([planche météo](../site/designs/meteo.html)) ; reste à choisir la variante. Dépend de : aucune.
  - Critères d'acceptation : design choisi par l'utilisateur, tracé en `D-nn`, appliqué au site et au prototype, identité de marque mise à jour.
  - Fait (2026-11-24) : variante 8 « Radar de pluie » choisie (D-69) et appliquée au site, puis au prototype (D-70). Reste : relecture du site et de la démonstration en ligne.
- [~] **TODO-3.10**: Remarques du 2026-11-25 dans le prototype : personnes alertées cochées et ajout de contact au démarrage (RG-NAV-25, RG-NAV-26), nombre de personnes à bord (RG-NAV-27), « Problème rencontré » dans le SOS (RG-SOS-02, RG-SOS-07), note vocale en enregistrement (RG-JRN-04, RG-SMS-06), page détaillée après la fin (RG-NAV-13), journal avec photos, écoute et nom des lieux (RG-JRN-09, RG-JRN-10), météo au début et à la fin (RG-NAV-28), carte OpenStreetMap et OpenSeaMap (RG-NAV-29). Dépend de : TODO-3.6.
  - Critères d'acceptation : chaque point visible dans la démonstration, couvert par un test quand c'est possible ; relu par l'utilisateur.
  - Fait (2026-11-25) : tous les points dans le prototype, 8 tests. Démonstration : enregistrement vocal et météo simulés, données du SHOM non intégrées (TODO-9.1, Q-23). La règle RG-GPS-06 (GPS éteint entre deux positions) concerne la vraie application. Reste : relecture par l'utilisateur.
- [~] **TODO-3.7**: Squelette du serveur en Go déployé sur pi-appliance ([D-62](07-decisions.md#d-62)) : page d'accueil de la plateforme Web, point de santé de l'API, connexion à la base, image `arm64`, fichier `compose.yaml` pour « Docker Compose libre ». Dépend de : aucune pour le squelette ; publication sur internet : TODO-2.72 à TODO-2.74 et TODO-3.18 de pi-appliance.
  - Critères d'acceptation : service installé sur le Pi de `vdl.moulard.org`, page ouverte depuis un téléphone à `https://nautilink.moulard.org` (redirigée vers `https://vdl.moulard.org/nautilink/`), base PostgreSQL partagée jointe, e-mail d'essai reçu par le relais, service gardé après un redémarrage du Pi.
  - Fait (2026-11-24) : serveur Go dans `server/` (accueil, espace administrateur vide, `api/sante`, PostgreSQL par pgx, commande `mail-essai`, tests), image `ghcr.io/gmoulard/nautilink-serveur` construite par le workflow « Serveur », `server/compose.yaml` ; essayé sous Docker (arm64 et amd64 construits, base jointe puis arrêtée, renvoi vers `/nautilink/`). Reste : premier passage du workflow sur GitHub, puis installation sur le Pi une fois TODO-2.72 à TODO-2.74 et TODO-3.18 de pi-appliance faits.
- [~] **TODO-3.5**: Scénarios de tests fonctionnels tirés des règles métier ([scénarios](tests/scenarios-fonctionnels.md)). Dépend de : aucune.
  - Critères d'acceptation : au moins un scénario par règle `RG-…`, en priorité RG-SOS, RG-ECO, RG-PAR.
  - Fait : 117 scénarios `TS-…`, les 105 règles citées, domaines SOS, ECO et PAR en tête. Reste : scénarios pour les règles tranchées ou ajoutées le 2026-11-24 après leur écriture (RG-NAV-16, RG-NAV-22, RG-JRN-04, RG-JRN-08, RG-SMS-03, RG-SMS-05, RG-SMS-07, RG-GPS-05, RG-SOS-16, RG-DON-02, RG-DON-03, RG-ADM-03, RG-IOS-06, RG-IOS-08, RG-SMS-08, RG-NOT-03, RG-CPT-06, RG-CPT-07, RG-NAV-23, RG-NAV-24, RG-ECO-10, et RG-NAV-10, RG-COM-03 modifiées) ; validation par l'utilisateur.

## 4. Étape 1 — Serveur

- [ ] **TODO-4.1**: Comptes et connexion par e-mail, Google et Apple (RG-CPT-01 à RG-CPT-03). Dépend de : TODO-3.2.
  - Critères d'acceptation : création de compte et connexion par les trois moyens, sur le Web et Android.
- [ ] **TODO-4.2**: Bateaux, fiche bateau, téléphone associé (RG-CPT-04, RG-CPT-05, RG-BAT-01 à RG-BAT-03). Dépend de : TODO-4.1.
  - Critères d'acceptation : plusieurs bateaux par compte ; associer un autre téléphone remplace l'ancien ; seul le propriétaire démarre une navigation.
- [ ] **TODO-4.3**: Contacts, invitations et accès (RG-CTC-01 à RG-CTC-05, RG-PAR-01 à RG-PAR-08). Dépend de : TODO-4.1, TODO-1.6.
  - Critères d'acceptation : un contact ajouté est suiveur et contact SOS par défaut ; invitation par e-mail et par lien ; périmètres *navigation* et *navigateur* ; retrait immédiat ; aucun accès sans compte.
- [ ] **TODO-4.4**: Paramètres généraux synchronisés (RG-PRM-01, RG-PRM-02, RG-SMS-02). Dépend de : TODO-4.1.
  - Critères d'acceptation : modification sur le Web vue par Android au lancement suivant, et inversement.
- [ ] **TODO-4.5**: Navigations, positions et journal de bord (RG-NAV-01 à RG-NAV-21, RG-JRN-01 à RG-JRN-07, RG-GPS-04). Dépend de : TODO-4.2, TODO-2.7, TODO-1.4.
  - Critères d'acceptation : une navigation complète reçue avec des positions envoyées en retard et en double ; journal dans l'ordre d'acquisition ; positions, début, fin et SOS non modifiables.
- [ ] **TODO-4.6**: Calcul du quota et clôture automatique (RG-ECO-01 à RG-ECO-05, RG-ECO-09). Dépend de : TODO-4.5, TODO-1.8.
  - Critères d'acceptation : tests du quota glissant à la minute (cas de l'exemple du modèle économique) ; démarrage refusé ; clôture 24 heures après l'épuisement, annulée par un abonnement.
- [ ] **TODO-4.7**: Alertes SOS et e-mails (RG-SOS-06, RG-SOS-12, RG-SOS-15, RG-NOT-01, RG-NOT-02). Dépend de : TODO-4.5, TODO-1.12.
  - Critères d'acceptation : e-mail reçu par les suiveurs et les contacts SOS avec e-mail en moins d'une minute après réception de l'alerte.
- [ ] **TODO-4.8**: Corbeille (RG-NAV-20, RG-NAV-21). Dépend de : TODO-4.5.
  - Critères d'acceptation : restauration avant 30 jours ; suppression définitive après ; suiveurs sans accès pendant ce temps ; temps toujours décompté du quota.

## 5. Étape 2 — Android

- [ ] **TODO-5.1**: Connexion, association du téléphone, écran d'accueil avec les trois boutons et le SOS (cahier des charges 5.1, 5.2, RG-SOS-15). Dépend de : TODO-4.2, TODO-3.3.
  - Critères d'acceptation : essai sur un vrai téléphone, écran conforme à la maquette.
- [ ] **TODO-5.2**: Démarrage d'une navigation (RG-NAV-02 à RG-NAV-08, RG-ECO-04, RG-SOS-14). Dépend de : TODO-5.1, TODO-4.6.
  - Critères d'acceptation : bateau, destination, fréquence, paramètres de la navigation ; refus si quota épuisé ; avertissement sans contact SOS.
- [ ] **TODO-5.3**: Positions automatiques en arrière-plan, stockage local et envoi différé (RG-GPS-01 à RG-GPS-04). Dépend de : TODO-5.2, TODO-2.2, TODO-2.7.
  - Critères d'acceptation : 8 heures de navigation écran éteint, avec une coupure Internet de 2 heures, sans position perdue.
- [ ] **TODO-5.4**: Position manuelle, NOTE, Photo, Vocal (RG-COM-03, RG-SMS-01 à RG-SMS-06, RG-JRN-04). Dépend de : TODO-5.2, TODO-2.4, TODO-2.5.
  - Critères d'acceptation : chaque action envoie au serveur et par SMS selon les paramètres, et affiche le résultat de chaque circuit.
- [ ] **TODO-5.5**: Alerte SOS (RG-SOS-01 à RG-SOS-15). Dépend de : TODO-5.1, TODO-2.1, TODO-1.10.
  - Critères d'acceptation : essai en mode avion sauf réseau mobile : SMS reçus ; les trois cas de position (RG-SOS-09 à RG-SOS-11) essayés ; SMS partis même avec l'interrupteur SMS coupé.
- [ ] **TODO-5.6**: Fin de navigation et reprise (RG-NAV-12 à RG-NAV-14). Dépend de : TODO-5.2, TODO-1.9.
  - Critères d'acceptation : fin hors connexion transmise plus tard avec l'heure réelle ; reprise après redémarrage du téléphone conforme à la décision TODO-1.9.
- [ ] **TODO-5.7**: Contacts, paramètres généraux, historique des alertes SOS, assistance (cahier des charges 5.5). Dépend de : TODO-4.3, TODO-4.4.
  - Critères d'acceptation : modifications vues sur le Web ; liste des contacts utilisable hors connexion pour le SOS.
- [ ] **TODO-5.8**: Quota et abonnement Google Play (RG-ECO-07, RG-ECO-09). Dépend de : TODO-4.6, TODO-1.13, TODO-1.14.
  - Critères d'acceptation : abonnement souscrit sur Google Play reconnu sur le Web.

## 6. Étape 3 — Web

- [ ] **TODO-6.1**: Tableau de bord (cahier des charges 6.1, D-23). Dépend de : TODO-4.5, TODO-3.3.
  - Critères d'acceptation : navigations en cours en haut, historique trié et filtrable, prévisualisation au survol et au toucher.
- [ ] **TODO-6.2**: Page d'une navigation : carte, journal, photos, notes vocales, mise à jour en direct (cahier des charges 6.2). Dépend de : TODO-6.1.
  - Critères d'acceptation : une position envoyée par Android apparaît sans recharger la page.
- [ ] **TODO-6.3**: Compléter et corriger le journal, renommer (RG-JRN-05, RG-JRN-06, RG-NAV-17). Dépend de : TODO-6.2, TODO-1.7.
  - Critères d'acceptation : ajouts, modifications et suppressions autorisés ; positions et SOS non modifiables.
- [ ] **TODO-6.4**: Export PDF (RG-NAV-19). Dépend de : TODO-6.2.
  - Critères d'acceptation : PDF avec informations, carte et journal, téléchargeable par le navigateur et ses suiveurs.
- [ ] **TODO-6.5**: Gestion du compte : bateaux, contacts, paramètres, corbeille, alertes SOS, assistance (cahier des charges 6.3). Dépend de : TODO-4.2, TODO-4.3, TODO-4.4, TODO-4.8.
  - Critères d'acceptation : chaque écran conforme à sa maquette ; modifications vues sur Android.
- [ ] **TODO-6.6**: Vue du suiveur (RG-PAR-07, RG-PAR-08). Dépend de : TODO-6.2, TODO-4.3.
  - Critères d'acceptation : lecture seule ; fiche bateau, autres suiveurs, contacts SOS et export visibles ; plus rien après un retrait.
- [ ] **TODO-6.7**: Quota et abonnement Web (RG-ECO-07, RG-ECO-09). Dépend de : TODO-4.6, TODO-1.13, TODO-1.14.
  - Critères d'acceptation : abonnement souscrit sur le Web reconnu sur Android.

## 7. Étape 4 — Administration

- [ ] **TODO-7.1**: Espace administrateur (RG-ADM-01 à RG-ADM-04). Dépend de : TODO-4.1, TODO-1.15.
  - Critères d'acceptation : chaque fonction de RG-ADM-02 disponible ; chaque action tracée.

## 8. Lancement

- [!] **TODO-8.1**: Logo, icône Android, déclinaisons, couleurs du thème sombre ([Q-25](06-questions-ouvertes.md#q-25)). Dépend de : aucune.
  - Critères d'acceptation : fichiers vectoriels et icônes Android et iPhone dans `docs/assets/`, palette complétée dans l'identité de marque. Bloqué par : validation du logo par l'utilisateur.
- [~] **TODO-8.2**: Disponibilité du nom, domaines, réseaux sociaux ([Q-26](06-questions-ouvertes.md#q-26)). Dépend de : aucune.
  - Critères d'acceptation : recherche d'antériorité faite, domaines et comptes réservés.
  - Fait : [étude documentaire](etudes/nom-nautilink.md) (moteur de recherche ; quasi-homonyme Nauti-Link) (2026-11-25). Reste : consulter INPI, EUIPO, OMPI ; vérifier domaines et comptes ; vérification juridique ; décision Q-26 ; réservations par l'utilisateur.
- [ ] **TODO-8.3**: Conditions d'utilisation, politique de confidentialité et [avertissement bêta](textes/avertissement-beta.md) relus par un juriste (RG-DON-03, D-56). Dépend de : TODO-1.17.
  - Critères d'acceptation : textes publiés sur le Web et accessibles depuis Android.
- [~] **TODO-8.5**: Site de présentation sur GitHub Pages : accueil, mémo sécurité en mer, avertissement bêta (`site/`, D-56). Dépend de : aucune.
  - Critères d'acceptation : site en ligne à l'adresse GitHub Pages du dépôt ; contenu cohérent avec la spécification ; mémo sécurité relu par l'utilisateur.
  - Fait : trois pages, le workflow de déploiement, liens vers la démonstration Web et l'APK (2026-11-24). Reste : activer GitHub Pages (Settings → Pages → Source : GitHub Actions), vérifier le site en ligne, relecture.
- [ ] **TODO-8.4**: Publication sur Google Play. Dépend de : TODO-2.1, TODO-5.1 à TODO-5.8, TODO-8.3.
  - Critères d'acceptation : application acceptée par Google Play avec les autorisations SMS et localisation en arrière-plan.

## 9. Évolutions futures

- [ ] **TODO-9.1**: Données gratuites du SHOM sur la carte du Web (priorité lancement depuis D-79) ([Q-23](06-questions-ouvertes.md#q-23)). Dépend de : TODO-6.2.
  - Critères d'acceptation : licence vérifiée, faisabilité et coût chiffrés.
- [~] **TODO-9.2**: Autres langues ([Q-27](06-questions-ouvertes.md#q-27)). Dépend de : aucune.
  - Critères d'acceptation : textes des interfaces séparés du code dès le départ ; une deuxième langue essayée.
  - Fait dans le prototype : textes des écrans en fichiers ARB (`app/lib/l10n/`), essai en anglais, test associé. Reste : relecture de la traduction, choix des langues et des points ouverts de Q-27 par l'utilisateur ; textes de `app/lib/data.dart` (types d'événements, fréquences, dates, durées) encore dans le code.
- [ ] **TODO-9.3**: Plusieurs versions de l'application Web ([Q-28](06-questions-ouvertes.md#q-28), RG-ADM-05). Dépend de : TODO-7.1.
  - Critères d'acceptation : stratégie de déploiement et de compatibilité écrite.

## 10. Étape 5 — iPhone (15)

Construite après l'application Android et le Web (D-33).

- [~] **TODO-10.2**: Étude : localisation en arrière-plan sur iPhone, batterie, règles de l'App Store ([Q-09](06-questions-ouvertes.md#q-09), [Q-31](06-questions-ouvertes.md#q-31)). Dépend de : aucune.
  - Critères d'acceptation : prototype qui enregistre une position toutes les 15 minutes pendant 8 heures, écran verrouillé, sur deux modèles d'iPhone ; autorisations et règles de l'App Store citées.
  - Fait : [étude documentaire](etudes/localisation-arriere-plan-iphone.md) (mode d'arrière-plan, autorisations, pause automatique, règles 2.4.2, 2.5.4, 5.1.1 et 5.1.5 de l'App Store citées, reprise). Reste : prototype de 8 heures sur deux modèles d'iPhone ; risque de la règle 5.1.5 (services d'urgence) pour le SOS à traiter.
  - Tranché le 2026-11-24 (D-54) : autorisation « Pendant l'utilisation ». Reste : prototype sur deux iPhone.
- [ ] **TODO-10.3**: Navigateur sur iPhone, sans SMS : accueil, démarrage, positions, NOTE, Photo, Vocal, fin, contacts, paramètres (RG-IOS-01, RG-IOS-02, RG-IOS-04). Dépend de : TODO-5.1 à TODO-5.7, TODO-10.2.
  - Critères d'acceptation : mêmes essais que l'application Android sur un vrai iPhone ; aucun SMS envoyé ; avertissement de démarrage avec la liste des contacts SOS sans e-mail.
- [ ] **TODO-10.4**: SOS sur iPhone par Internet (RG-IOS-03). Dépend de : TODO-10.3, TODO-4.7.
  - Critères d'acceptation : e-mails et notifications push reçus ; en mode avion, message clair puis envoi automatique au retour de la connexion.
- [ ] **TODO-10.5**: Suiveur sur iPhone et notifications push (RG-IOS-05, RG-IOS-06). Dépend de : TODO-6.2, TODO-10.1, TODO-1.20.
  - Critères d'acceptation : navigation suivie en direct avec la carte ; notification push d'un SOS reçue application fermée.
- [ ] **TODO-10.6**: Abonnement par achat intégré de l'App Store (RG-IOS-07). Dépend de : TODO-4.6, TODO-1.14.
  - Critères d'acceptation : abonnement souscrit sur l'iPhone reconnu sur Android et le Web.
- [ ] **TODO-10.7**: Publication sur l'App Store. Dépend de : TODO-10.3 à TODO-10.6, TODO-8.3.
  - Critères d'acceptation : application acceptée par Apple avec la localisation en arrière-plan.
