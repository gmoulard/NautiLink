# TODO

Feuille de route de NautiLink, dans l'ordre de construction : décisions, études, préparation, serveur, Android, Web, administration, lancement, puis iPhone. Les identifiants `RG-…` renvoient aux [règles métier](02-regles-metier.md), les `Q-nn` aux [questions ouvertes](06-questions-ouvertes.md), les `D-nn` au [journal des décisions](07-decisions.md).

États : `[ ]` à faire ; `[~]` en cours ou à vérifier (fait, mais pas encore validé) ; `[!]` bloqué (attend une décision, un accès ou un matériel : la raison est dite) ; `[x]` réalisé et validé. Une action ouverte dit de quoi elle dépend (« Dépend de : ») et ses critères d'acceptation ; elle n'est cochée `[x]` qu'une fois ses critères remplis. Les actions réalisées tiennent sur une ligne ; une fois validées, elles sont déplacées dans [Actions réalisées](Todo-done.md), sauf si un de leurs points reste ouvert.

## Lots

Groupes d'actions cohérents, réalisés chacun par le sous-agent `todo-lot` (une action = un commit poussé). Un lot de décisions rend les questions à poser : le sous-agent ne tranche rien.

| Lot | Titre | Actions | Dépend de | État |
|-----|-------|---------|-----------|------|
| LOT-1 | Décisions sur les navigations et le partage | TODO-1.4, TODO-1.5, TODO-1.6, TODO-1.7, TODO-1.8, TODO-1.11 | aucun | [!] |
| LOT-2 | Décisions sur les notifications, le quota et l'abonnement | TODO-1.12, TODO-1.13, TODO-1.14, TODO-10.1 | aucun | [!] |
| LOT-3 | Décisions sur l'administration, les données et la conformité | TODO-1.15, TODO-1.16, TODO-1.17 | aucun | [!] |
| LOT-4 | Études SMS et MMS sur Android | TODO-2.1, TODO-2.3, TODO-2.4, TODO-1.10 | aucun | [ ] |
| LOT-5 | Études GPS, batterie, reprise et notes vocales | TODO-2.2, TODO-10.2, TODO-1.9, TODO-2.5 | aucun | [ ] |
| LOT-6 | Architecture, API et synchronisation | TODO-3.1, TODO-3.2, TODO-2.7, TODO-2.6, TODO-3.4 | LOT-4, LOT-5 | [ ] |
| LOT-7 | Maquettes et scénarios de tests | TODO-3.3, TODO-3.5 | aucun | [ ] |
| LOT-8 | Serveur : comptes, bateaux, contacts, paramètres | TODO-4.1, TODO-4.2, TODO-4.3, TODO-4.4 | LOT-1, LOT-6 | [ ] |
| LOT-9 | Serveur : navigations, quota, SOS, corbeille | TODO-4.5, TODO-4.6, TODO-4.7, TODO-4.8 | LOT-2, LOT-8 | [ ] |
| LOT-10 | Android : accueil, démarrage, positions, SOS | TODO-5.1, TODO-5.2, TODO-5.3, TODO-5.5 | LOT-7, LOT-9 | [ ] |
| LOT-11 | Android : journal, fin, contacts, abonnement | TODO-5.4, TODO-5.6, TODO-5.7, TODO-5.8 | LOT-10 | [ ] |
| LOT-12 | Web : consultation des navigations | TODO-6.1, TODO-6.2, TODO-6.3, TODO-6.4 | LOT-7, LOT-9 | [ ] |
| LOT-13 | Web : compte, suiveur, abonnement | TODO-6.5, TODO-6.6, TODO-6.7 | LOT-12 | [ ] |
| LOT-14 | Administration | TODO-7.1 | LOT-3, LOT-8 | [ ] |
| LOT-15 | Marque et publication Android | TODO-8.1, TODO-8.2, TODO-8.3, TODO-8.4 | LOT-3, LOT-11 | [ ] |
| LOT-16 | Application iPhone | TODO-10.3, TODO-10.4, TODO-10.5, TODO-10.6, TODO-10.7 | LOT-11, LOT-13, LOT-15 | [ ] |
| LOT-17 | Évolutions futures | TODO-9.1, TODO-9.2, TODO-9.3 | LOT-13, LOT-14 | [ ] |

## 0. Ménage du dépôt

Tout est réalisé : voir [Actions réalisées](Todo-done.md).

## 1. Décisions

Pour chaque action : critères d'acceptation communs — choix de l'utilisateur tracé en `D-nn`, règle écrite dans les règles métier, question retirée des questions ouvertes.

- [!] **TODO-1.4**: Lieu de départ, lieu d'arrivée et distance d'une navigation ([Q-01](06-questions-ouvertes.md#q-01), RG-NAV-16). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.5**: Un suiveur peut-il refuser les SMS ordinaires ([Q-04](06-questions-ouvertes.md#q-04), RG-SMS-01). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.6**: Validité d'une invitation ([Q-06](06-questions-ouvertes.md#q-06), RG-PAR-05). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.7**: Informations modifiables d'une navigation en dehors du nom ([Q-24](06-questions-ouvertes.md#q-24), RG-NAV-17). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.8**: Prévenir avant la clôture automatique pour quota épuisé ([Q-32](06-questions-ouvertes.md#q-32), RG-ECO-05). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.9**: Reprise après fermeture forcée ou redémarrage du téléphone ([Q-08](06-questions-ouvertes.md#q-08), RG-NAV-12). Dépend de : TODO-2.2.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur, éclairée par l'étude TODO-2.2.
- [!] **TODO-1.10**: Nouvelles tentatives et affichage des échecs d'envoi des SMS, SOS compris ([Q-11](06-questions-ouvertes.md#q-11), RG-SMS-07). Dépend de : TODO-2.1.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.11**: Taille et nombre des photos ([Q-15](06-questions-ouvertes.md#q-15)). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.12**: Liste des notifications par e-mail, fréquence, désinscription ([Q-16](06-questions-ouvertes.md#q-16), RG-NOT-02). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.13**: Présentation du quota dans les interfaces ([Q-18](06-questions-ouvertes.md#q-18), RG-ECO-09). Dépend de : aucune.
  - Critères d'acceptation : communs, plus une maquette de l'écran quota (TODO-3.3). Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.14**: Formules, tarifs et règles de l'abonnement ([Q-17](06-questions-ouvertes.md#q-17), RG-ECO-06, RG-ECO-07). Dépend de : aucune.
  - Critères d'acceptation : communs, dans le modèle économique. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.15**: Profils d'administrateurs et traçabilité ([Q-19](06-questions-ouvertes.md#q-19), RG-ADM-03). Dépend de : aucune.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.16**: Conservation des données, sauvegardes, export des données personnelles ([Q-20](06-questions-ouvertes.md#q-20), RG-DON-02). Dépend de : TODO-1.17.
  - Critères d'acceptation : communs. Bloqué par : décision de l'utilisateur.
- [!] **TODO-1.17**: Sécurité et conformité : RGPD, sessions, conditions d'utilisation, confidentialité ([Q-21](06-questions-ouvertes.md#q-21)). Dépend de : aucune.
  - Critères d'acceptation : communs, plus les obligations légales listées avec leur source. Bloqué par : décision de l'utilisateur, avis juridique éventuel.

## 2. Études techniques

- [~] **TODO-2.1**: **À faire en premier.** Envoi de SMS par une application Android publiée sur Google Play ([Q-12](06-questions-ouvertes.md#q-12), RG-COM-01). Tout le circuit SMS en dépend, SOS compris. Dépend de : aucune.
  - Critères d'acceptation : règles actuelles de Google Play sur la permission SMS lues et citées ; voie retenue par l'utilisateur (exception demandée, application SMS préremplie, distribution hors Play Store…) et écrite dans les règles métier.
  - Fait : [étude documentaire](etudes/sms-mms-android.md) (règles Google Play, voies A à D, API `SmsManager`). Reste : relire en entier les pages d'aide Google Play (inaccessibles lors de la rédaction) ; choix de la voie par l'utilisateur, puis règles métier et `D-nn`.
- [~] **TODO-2.2**: GPS en arrière-plan, écran éteint, et consommation de batterie ([Q-09](06-questions-ouvertes.md#q-09), RG-GPS-03). Dépend de : aucune.
  - Critères d'acceptation : prototype qui enregistre une position toutes les 3 minutes pendant 8 heures, écran éteint, sur au moins trois marques de téléphones (dont Samsung et Xiaomi) ; positions manquantes et batterie consommée notées.
  - Fait : [étude documentaire](etudes/gps-arriere-plan-android.md) (service de premier plan `location`, autorisations, Doze, constructeurs, reprise au redémarrage, protocole d'essai). Reste : prototype sur trois marques (dont Samsung et Xiaomi) avec mesures ; relire dontkillmyapp.com et la politique Google Play (inaccessibles lors de la rédaction).
- [ ] **TODO-2.3**: Autorisations Android et versions visées ([Q-31](06-questions-ouvertes.md#q-31)). Dépend de : TODO-2.1, TODO-2.2.
  - Critères d'acceptation : liste des autorisations (localisation en arrière-plan, SMS, appareil photo, micro, notifications), version minimale d'Android choisie, parcours de demande des autorisations dessiné.
- [~] **TODO-2.4**: MMS : taille, opérateurs, repli ([Q-13](06-questions-ouvertes.md#q-13), RG-SMS-05). Dépend de : TODO-2.1.
  - Critères d'acceptation : MMS avec photo envoyé et reçu chez les quatre opérateurs français ; taille maximale et comportement en cas d'échec écrits.
  - Fait : [étude documentaire](etudes/sms-mms-android.md#5-mms-todo-24) (API, taille lue sur le téléphone, repères 300/600 Ko non officiels). Reste : essai chez les quatre opérateurs ; choix de la taille et du comportement en cas d'échec par l'utilisateur.
- [ ] **TODO-2.5**: Notes vocales : format, durée, transcription ([Q-14](06-questions-ouvertes.md#q-14), RG-JRN-04). Dépend de : aucune.
  - Critères d'acceptation : format et durée maximale choisis ; transcription en français essayée hors connexion et en ligne, avec le taux d'erreur constaté.
- [ ] **TODO-2.6**: Fonctionnement hors connexion de chaque écran Android ([Q-29](06-questions-ouvertes.md#q-29)). Dépend de : TODO-3.1.
  - Critères d'acceptation : tableau écran par écran (sans Internet, sans réseau mobile, sans les deux), validé par l'utilisateur.
- [ ] **TODO-2.7**: File d'attente des envois et doublons ([Q-10](06-questions-ouvertes.md#q-10), RG-GPS-04). Dépend de : TODO-3.2.
  - Critères d'acceptation : mécanisme écrit (identifiant unique par événement, ordre, renvoi) et essayé avec une coupure de 2 heures.

## 3. Préparation du développement

- [ ] **TODO-3.1**: Architecture technique : hébergement, base de données, stockage des photos et notes vocales, envoi des e-mails ([Q-22](06-questions-ouvertes.md#q-22)). Dépend de : TODO-2.1.
  - Critères d'acceptation : document d'architecture dans `docs/`, schéma Mermaid, choix validés par l'utilisateur.
- [ ] **TODO-3.2**: API et formats de données, synchronisation Android ↔ serveur ↔ Web ([Q-22](06-questions-ouvertes.md#q-22)). Dépend de : TODO-3.1.
  - Critères d'acceptation : description de l'API (OpenAPI) couvrant chaque règle `RG-…` qui passe par le serveur.
- [ ] **TODO-3.3**: Maquettes Android et Web ([Q-30](06-questions-ouvertes.md#q-30)). Dépend de : aucune.
  - Critères d'acceptation : un écran par section des §5 et §6 du cahier des charges, thèmes clair et sombre, validés par l'utilisateur.
- [ ] **TODO-3.4**: Environnements de développement, de test et de production ([Q-22](06-questions-ouvertes.md#q-22)). Dépend de : TODO-3.1.
  - Critères d'acceptation : trois environnements décrits ; déploiement de test reproductible.
- [ ] **TODO-3.5**: Scénarios de tests fonctionnels tirés des règles métier. Dépend de : aucune.
  - Critères d'acceptation : au moins un scénario par règle `RG-…`, en priorité RG-SOS, RG-ECO, RG-PAR.

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
- [ ] **TODO-8.2**: Disponibilité du nom, domaines, réseaux sociaux ([Q-26](06-questions-ouvertes.md#q-26)). Dépend de : aucune.
  - Critères d'acceptation : recherche d'antériorité faite, domaines et comptes réservés.
- [ ] **TODO-8.3**: Conditions d'utilisation et politique de confidentialité. Dépend de : TODO-1.17.
  - Critères d'acceptation : textes publiés sur le Web et accessibles depuis Android.
- [ ] **TODO-8.4**: Publication sur Google Play. Dépend de : TODO-2.1, TODO-5.1 à TODO-5.8, TODO-8.3.
  - Critères d'acceptation : application acceptée par Google Play avec les autorisations SMS et localisation en arrière-plan.

## 9. Évolutions futures

- [ ] **TODO-9.1**: Cartes marines du SHOM sur le Web ([Q-23](06-questions-ouvertes.md#q-23)). Dépend de : TODO-6.2.
  - Critères d'acceptation : licence vérifiée, faisabilité et coût chiffrés.
- [ ] **TODO-9.2**: Autres langues ([Q-27](06-questions-ouvertes.md#q-27)). Dépend de : aucune.
  - Critères d'acceptation : textes des interfaces séparés du code dès le départ ; une deuxième langue essayée.
- [ ] **TODO-9.3**: Plusieurs versions de l'application Web ([Q-28](06-questions-ouvertes.md#q-28), RG-ADM-05). Dépend de : TODO-7.1.
  - Critères d'acceptation : stratégie de déploiement et de compatibilité écrite.

## 10. Étape 5 — iPhone (15)

Construite après l'application Android et le Web (D-33).

- [!] **TODO-10.1**: Notifications push du suiveur sur iPhone ([Q-33](06-questions-ouvertes.md#q-33), RG-IOS-06). Dépend de : aucune.
  - Critères d'acceptation : choix de l'utilisateur tracé en `D-nn`, règle écrite, question retirée. Bloqué par : décision de l'utilisateur.
- [~] **TODO-10.2**: Étude : localisation en arrière-plan sur iPhone, batterie, règles de l'App Store ([Q-09](06-questions-ouvertes.md#q-09), [Q-31](06-questions-ouvertes.md#q-31)). Dépend de : aucune.
  - Critères d'acceptation : prototype qui enregistre une position toutes les 3 minutes pendant 8 heures, écran verrouillé, sur deux modèles d'iPhone ; autorisations et règles de l'App Store citées.
  - Fait : [étude documentaire](etudes/localisation-arriere-plan-iphone.md) (mode d'arrière-plan, autorisations, pause automatique, règles 2.4.2, 2.5.4, 5.1.1 et 5.1.5 de l'App Store citées, reprise). Reste : prototype de 8 heures sur deux modèles d'iPhone ; risque de la règle 5.1.5 (services d'urgence) pour le SOS à traiter.
- [ ] **TODO-10.3**: Navigateur sur iPhone, sans SMS : accueil, démarrage, positions, NOTE, Photo, Vocal, fin, contacts, paramètres (RG-IOS-01, RG-IOS-02, RG-IOS-04). Dépend de : TODO-5.1 à TODO-5.7, TODO-10.2.
  - Critères d'acceptation : mêmes essais que l'application Android sur un vrai iPhone ; aucun SMS envoyé ; avertissement de démarrage avec la liste des contacts SOS sans e-mail.
- [ ] **TODO-10.4**: SOS sur iPhone par Internet (RG-IOS-03). Dépend de : TODO-10.3, TODO-4.7.
  - Critères d'acceptation : e-mails et notifications push reçus ; en mode avion, message clair puis envoi automatique au retour de la connexion.
- [ ] **TODO-10.5**: Suiveur sur iPhone et notifications push (RG-IOS-05, RG-IOS-06). Dépend de : TODO-6.2, TODO-10.1.
  - Critères d'acceptation : navigation suivie en direct avec la carte ; notification push d'un SOS reçue application fermée.
- [ ] **TODO-10.6**: Abonnement par achat intégré de l'App Store (RG-IOS-07). Dépend de : TODO-4.6, TODO-1.14.
  - Critères d'acceptation : abonnement souscrit sur l'iPhone reconnu sur Android et le Web.
- [ ] **TODO-10.7**: Publication sur l'App Store. Dépend de : TODO-10.3 à TODO-10.6, TODO-8.3.
  - Critères d'acceptation : application acceptée par Apple avec la localisation en arrière-plan.
