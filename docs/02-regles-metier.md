# NautiLink — Règles métier

Chaque règle a un identifiant stable `RG-<DOMAINE>-<nn>`. On cite une règle par son identifiant dans les autres documents, le code, les tests et les tickets. Un identifiant n'est jamais réutilisé : une règle abandonnée est barrée et renvoie à la décision qui l'a remplacée.

Les sujets encore ouverts renvoient à une question `Q-nn` de [06-questions-ouvertes.md](06-questions-ouvertes.md). Les arbitrages sont tracés dans [07-decisions.md](07-decisions.md). Vocabulaire : [00-glossaire.md](00-glossaire.md).

## 1. Comptes et bateaux

- <a id="rg-cpt-01"></a>**RG-CPT-01** — Il existe un seul type de compte utilisateur. Un utilisateur est navigateur quand il conduit ses propres navigations et suiveur quand il consulte celles d'un autre ([D-01](07-decisions.md#d-01)).
- <a id="rg-cpt-02"></a>**RG-CPT-02** — Connexion par e-mail et mot de passe, par Google ou par Apple, sur le Web et sur les applications mobiles ([D-18](07-decisions.md#d-18)).
- <a id="rg-cpt-03"></a>**RG-CPT-03** — Les interfaces sont en français au lancement. La signature de marque reste en anglais.
- <a id="rg-cpt-04"></a>**RG-CPT-04** — Un compte peut posséder plusieurs bateaux. Un bateau a un seul propriétaire.
- <a id="rg-cpt-05"></a>**RG-CPT-05** — Seul le propriétaire d'un bateau peut démarrer une navigation avec ce bateau ([D-11](07-decisions.md#d-11)).
- <a id="rg-bat-01"></a>**RG-BAT-01** — La fiche bateau comprend : nom, type (voilier ou bateau à moteur), longueur, immatriculation, port d'attache, photo, caractéristiques techniques (moteur, autonomie, capacité en carburant, vitesse, tirant d'eau).
- <a id="rg-bat-02"></a>**RG-BAT-02** — Un bateau a au plus un téléphone associé. Un même téléphone peut être associé à plusieurs bateaux du même compte. Associer un autre téléphone à un bateau remplace l'association précédente ([D-12](07-decisions.md#d-12)).
- <a id="rg-bat-03"></a>**RG-BAT-03** — Les données de chaque bateau (navigations, journaux, positions, alertes) restent séparées de celles des autres bateaux du compte.

## 2. Navigations

### 2.1 Démarrage

- <a id="rg-nav-01"></a>**RG-NAV-01** — Une navigation est créée uniquement par le navigateur, avec le bouton « Démarrer navigation » de l'application mobile (Android ou iPhone). Aucune navigation n'est créée automatiquement.
- <a id="rg-nav-02"></a>**RG-NAV-02** — Au démarrage, le navigateur choisit le bateau. Si le téléphone n'est associé qu'à un seul bateau, ce choix n'est pas affiché ([D-12](07-decisions.md#d-12)).
- <a id="rg-nav-03"></a>**RG-NAV-03** — Un bateau a au plus une navigation en cours. Un téléphone a au plus une navigation en cours.
- <a id="rg-nav-04"></a>**RG-NAV-04** — La destination est facultative. Elle se saisit en texte (adresse ou lieu) ou en choisissant un point sur une carte ([D-06](07-decisions.md#d-06)).
- <a id="rg-nav-05"></a>**RG-NAV-05** — La fréquence est préremplie avec la valeur des paramètres généraux et peut être changée au démarrage pour cette navigation seulement. Valeurs possibles : 3, 4, 5, 10, 15, 30 minutes, 1 heure ([D-05](07-decisions.md#d-05)).
- <a id="rg-nav-06"></a>**RG-NAV-06** — Le bouton « Paramètres » de l'écran de démarrage modifie les paramètres de cette navigation seulement. Les paramètres généraux ne changent pas et sont repris à la navigation suivante.
- <a id="rg-nav-07"></a>**RG-NAV-07** — Le démarrage est refusé si le quota gratuit est épuisé et que le compte n'a pas d'abonnement actif ([RG-ECO-04](#rg-eco-04)).
- <a id="rg-nav-08"></a>**RG-NAV-08** — À la confirmation du démarrage (« Envoi message – Début de navigation ») : enregistrement de la date et de l'heure de début, acquisition d'une position, envoi au serveur par API, SMS de début si les paramètres le prévoient, activation des positions automatiques.

### 2.2 Pendant la navigation

- <a id="rg-nav-09"></a>**RG-NAV-09** — Aucune carte n'est affichée sur l'écran de navigation de l'application mobile. La seule carte de l'écran du navigateur est celle du choix de la destination ; le suivi sur iPhone affiche une carte ([RG-IOS-05](#rg-ios-05)).
- <a id="rg-nav-10"></a>**RG-NAV-10** — L'écran de navigation affiche deux chronomètres : temps écoulé depuis le début, temps écoulé depuis le dernier envoi.
- <a id="rg-nav-11"></a>**RG-NAV-11** — Positions automatiques et positions manuelles coexistent pendant une même navigation.
- <a id="rg-nav-12"></a>**RG-NAV-12** — « Reprendre la dernière navigation » rouvre l'écran de la navigation en cours du téléphone. Comportement après fermeture forcée ou redémarrage du téléphone : [Q-08](06-questions-ouvertes.md#q-08).

### 2.3 Fin

- <a id="rg-nav-13"></a>**RG-NAV-13** — « Terminer la navigation » demande une confirmation. Après confirmation : SMS de fin si les paramètres le prévoient, envoi des informations de fin au serveur, clôture de la navigation côté serveur.
- <a id="rg-nav-14"></a>**RG-NAV-14** — La clôture côté serveur a lieu même si l'envoi d'un SMS échoue. Sans Internet, la fin est enregistrée sur le téléphone avec son heure réelle et transmise dès que possible.
- <a id="rg-nav-15"></a>**RG-NAV-15** — Une navigation peut aussi être clôturée automatiquement par épuisement du quota ([RG-ECO-05](#rg-eco-05)).

### 2.4 Informations et historique

- <a id="rg-nav-16"></a>**RG-NAV-16** — Une navigation porte au minimum : nom, bateau, date et heure de début et de fin, lieu de départ, lieu d'arrivée, destination si saisie, durée, distance parcourue. Calcul du lieu d'arrivée et de la distance : [Q-01](06-questions-ouvertes.md#q-01).
- <a id="rg-nav-17"></a>**RG-NAV-17** — Le nom est généré au démarrage (« <nom du bateau> — <destination> » si une destination est saisie, sinon « <nom du bateau> — <date> ») et peut être modifié ensuite par le navigateur, sur le Web et sur l'application mobile ([D-15](07-decisions.md#d-15)). Modification des autres informations : [Q-24](06-questions-ouvertes.md#q-24).
- <a id="rg-nav-18"></a>**RG-NAV-18** — Les navigations terminées sont conservées sans limite de durée.
- <a id="rg-nav-19"></a>**RG-NAV-19** — Une navigation peut être exportée en PDF depuis le Web par son navigateur et par ses suiveurs ([RG-PAR-08](#rg-par-08)).
- <a id="rg-nav-20"></a>**RG-NAV-20** — Le navigateur peut supprimer depuis le Web une navigation terminée. Elle passe dans la corbeille, restaurable pendant 30 jours, puis est supprimée définitivement. Une navigation en cours ne peut pas être supprimée. Pendant son séjour dans la corbeille, les suiveurs n'y ont plus accès ([D-17](07-decisions.md#d-17)).
- <a id="rg-nav-21"></a>**RG-NAV-21** — Le temps d'une navigation supprimée reste décompté du quota.

## 3. Journal de bord

- <a id="rg-jrn-01"></a>**RG-JRN-01** — Chaque navigation a un journal de bord, conservé sans limite de durée.
- <a id="rg-jrn-02"></a>**RG-JRN-02** — Types d'événements : début de navigation, position automatique, position manuelle, note écrite, photo, note vocale, alerte SOS, fin de navigation, ajout complémentaire (texte, photo, note vocale ou information ajoutés depuis le Web).
- <a id="rg-jrn-03"></a>**RG-JRN-03** — Le journal est présenté dans l'ordre chronologique de l'heure de l'événement (heure d'acquisition sur le téléphone, pas heure de réception par le serveur).
- <a id="rg-jrn-04"></a>**RG-JRN-04** — Une note vocale est un enregistrement audio conservé sur le serveur avec sa transcription texte. Le navigateur valide la transcription avant l'envoi ([D-07](07-decisions.md#d-07)). Format, taille, moteur de transcription : [Q-14](06-questions-ouvertes.md#q-14).
- <a id="rg-jrn-05"></a>**RG-JRN-05** — Depuis le Web, le navigateur peut ajouter à une navigation terminée des textes, photos, notes vocales et informations complémentaires.
- <a id="rg-jrn-06"></a>**RG-JRN-06** — Le navigateur peut modifier et supprimer, depuis le Web ou l'application mobile, les notes écrites, photos, notes vocales et ajouts complémentaires, quelle que soit leur origine ([D-16](07-decisions.md#d-16)).
- <a id="rg-jrn-07"></a>**RG-JRN-07** — Les événements de début, de fin, de position et d'alerte SOS ne sont jamais modifiables ni supprimables par le navigateur. Ils ne disparaissent qu'avec la suppression de la navigation entière ([D-16](07-decisions.md#d-16)).

## 4. GPS et positions

- <a id="rg-gps-01"></a>**RG-GPS-01** — Le GPS fonctionne sans Internet et sans réseau mobile.
- <a id="rg-gps-02"></a>**RG-GPS-02** — Chaque position est horodatée à son acquisition.
- <a id="rg-gps-03"></a>**RG-GPS-03** — Les positions sont enregistrées sur le téléphone à la fréquence de la navigation, que le serveur soit joignable ou non.
- <a id="rg-gps-04"></a>**RG-GPS-04** — Les positions non transmises sont envoyées au serveur dès que la connexion Internet le permet, dans l'ordre d'acquisition. Gestion fine de la file d'attente et des doublons : [Q-10](06-questions-ouvertes.md#q-10).

## 5. Circuits de communication

- <a id="rg-com-01"></a>**RG-COM-01** — Deux circuits indépendants : le circuit Internet (API HTTPS vers le serveur) et le circuit SMS (SMS et MMS par la carte SIM du téléphone, sans prestataire externe). Le circuit SMS n'existe que sur Android ([RG-IOS-02](#rg-ios-02)).
- <a id="rg-com-02"></a>**RG-COM-02** — L'échec ou l'indisponibilité d'un circuit n'empêche jamais de tenter l'autre. Le GPS ne dépend d'aucun des deux.
- <a id="rg-com-03"></a>**RG-COM-03** — Chaque action de transmission (position, note, photo, note vocale, SOS, début, fin) affiche le résultat de chaque circuit (par exemple « Position envoyée »).

## 6. SMS ordinaires

- <a id="rg-sms-01"></a>**RG-SMS-01** — Les SMS ordinaires d'une navigation sont envoyés aux suiveurs de cette navigation ayant renseigné un numéro de téléphone ([D-08](07-decisions.md#d-08)). Possibilité pour un suiveur de refuser ces SMS : [Q-04](06-questions-ouvertes.md#q-04).
- <a id="rg-sms-02"></a>**RG-SMS-02** — Un interrupteur général active ou désactive tous les SMS ordinaires. Une préférence par type précise lesquels partent : début, positions automatiques, positions manuelles, notes écrites, photos, notes vocales, fin. Ces réglages ne s'appliquent jamais aux SMS SOS ([RG-SOS-14](#rg-sos-14)).
- <a id="rg-sms-03"></a>**RG-SMS-03** — Les SMS prévus par les paramètres partent sans confirmation supplémentaire.
- <a id="rg-sms-04"></a>**RG-SMS-04** — Si le GPS est indisponible pour un SMS ordinaire qui doit contenir une position, le SMS indique « GPS NON DISPONIBLE » au lieu d'une position ancienne.
- <a id="rg-sms-05"></a>**RG-SMS-05** — Photo : la photo est envoyée au serveur. Si les paramètres le prévoient, un MMS la joint ; le message peut aussi contenir un lien vers la photo hébergée. Contraintes MMS : [Q-13](06-questions-ouvertes.md#q-13).
- <a id="rg-sms-06"></a>**RG-SMS-06** — Note vocale : le SMS contient la transcription texte, pas l'audio.
- <a id="rg-sms-07"></a>**RG-SMS-07** — Échecs d'envoi et nouvelles tentatives : [Q-11](06-questions-ouvertes.md#q-11). Restrictions Android et Google Play sur l'envoi de SMS : [Q-12](06-questions-ouvertes.md#q-12).

## 7. Alerte SOS

### 7.1 Déclenchement

- <a id="rg-sos-01"></a>**RG-SOS-01** — Le bouton SOS n'existe que sur les applications mobiles (Android et iPhone). Il est rouge (`#D94343`) et clairement identifiable. Il figure sur l'écran de navigation en cours et sur l'écran d'accueil ([RG-SOS-15](#rg-sos-15)).
- <a id="rg-sos-02"></a>**RG-SOS-02** — L'appui sur le bouton ouvre une boîte de confirmation. L'envoi part à la confirmation ([D-02](07-decisions.md#d-02)).
- <a id="rg-sos-03"></a>**RG-SOS-03** — Le SOS reste disponible quel que soit l'état du quota ou de l'abonnement.
- <a id="rg-sos-04"></a>**RG-SOS-04** — Après confirmation, dans cet ordre et sans qu'une étape en bloque une autre : acquisition de la position, SMS aux contacts SOS (Android seulement), envoi de l'alerte et de la position au serveur, enregistrement dans le journal, affichage du résultat.
- <a id="rg-sos-05"></a>**RG-SOS-05** — Les SMS SOS utilisent la liste des contacts SOS présente sur le téléphone, même sans Internet.
- <a id="rg-sos-06"></a>**RG-SOS-06** — À réception de l'alerte, le serveur envoie un e-mail à tous les suiveurs de la navigation et aux contacts SOS dont l'e-mail est connu ([D-14](07-decisions.md#d-14)).
- <a id="rg-sos-14"></a>**RG-SOS-14** — Les SMS SOS ne peuvent pas être désactivés : ni l'interrupteur général des SMS ni les préférences par type ne s'y appliquent. Ils partent dès qu'au moins un contact SOS existe. Si le navigateur n'a aucun contact SOS, le démarrage d'une navigation affiche un avertissement ([D-26](07-decisions.md#d-26)).
- <a id="rg-sos-15"></a>**RG-SOS-15** — SOS depuis l'écran d'accueil, hors navigation : il est rattaché au bateau du téléphone (choix du bateau s'il y en a plusieurs), enregistré dans l'historique des alertes de ce bateau, et le serveur envoie l'e-mail aux suiveurs de périmètre *navigateur* et aux contacts SOS dont l'e-mail est connu. Le reste est identique au SOS en navigation ([D-27](07-decisions.md#d-27)).

### 7.2 Contenu des SMS SOS

- <a id="rg-sos-07"></a>**RG-SOS-07** — Premier SMS : mention SOS, nom du bateau, type, longueur, immatriculation, coordonnées GPS, date et heure d'acquisition de la position, lien Google Maps vers ces coordonnées ([D-13](07-decisions.md#d-13)).
- <a id="rg-sos-08"></a>**RG-SOS-08** — Second SMS : les autres informations de la fiche bateau (port d'attache, moteur, autonomie, capacité en carburant, vitesse, tirant d'eau).

### 7.3 Position transmise

- <a id="rg-sos-09"></a>**RG-SOS-09** — GPS disponible : la position actuelle est transmise avec sa date et son heure d'acquisition.
- <a id="rg-sos-10"></a>**RG-SOS-10** — GPS indisponible mais une position antérieure existe : la dernière position connue est transmise avec ses coordonnées, sa date et son heure d'acquisition, un lien Google Maps et la mention explicite qu'il s'agit de la dernière position connue, pas nécessairement de la position actuelle.
- <a id="rg-sos-11"></a>**RG-SOS-11** — Aucune position connue : le SMS indique que le GPS est indisponible et qu'aucune position n'est connue.

### 7.4 Historique

- <a id="rg-sos-12"></a>**RG-SOS-12** — Chaque alerte est conservée avec sa date et son heure, la position transmise et le statut d'envoi de chaque SMS. Le statut distingue « accepté pour envoi » et « livraison confirmée » lorsque le téléphone fournit l'accusé de réception.
- <a id="rg-sos-13"></a>**RG-SOS-13** — L'historique des alertes est consultable sur les applications mobiles et sur le Web.

## 8. Contacts : suiveurs et contacts SOS

- <a id="rg-ctc-01"></a>**RG-CTC-01** — Le navigateur a une seule liste de contacts. Un contact comprend un nom, un numéro de téléphone et un e-mail (au moins l'un des deux), et deux cases : « Suiveur » et « Contact SOS ». Par défaut, les deux cases sont cochées : suiveurs et contacts SOS sont les mêmes personnes, et le navigateur peut décocher l'une ou l'autre pour chaque contact ([D-30](07-decisions.md#d-30)).
- <a id="rg-ctc-04"></a>**RG-CTC-04** — Cocher « Suiveur » envoie une invitation avec le périmètre choisi (RG-PAR-03) ; le contact devient suiveur quand il a accepté. Décocher « Suiveur » retire le suiveur de toutes les navigations (RG-PAR-06). Inviter un suiveur l'ajoute à la liste avec les deux cases cochées.
- <a id="rg-ctc-05"></a>**RG-CTC-05** — « Contact SOS » demande un numéro de téléphone : pour un contact sans numéro, la case est décochée et ne peut pas être cochée.
- <a id="rg-ctc-02"></a>**RG-CTC-02** — Le navigateur ajoute, modifie et supprime ses contacts, et coche ou décoche leurs cases, depuis le Web et depuis l'application mobile ([D-03](07-decisions.md#d-03)).
- <a id="rg-ctc-03"></a>**RG-CTC-03** — La liste des contacts est synchronisée par le serveur au lancement de l'application mobile et à chaque modification lorsque Internet est disponible. L'application mobile en garde une copie locale.

## 9. Partage et suiveurs

- <a id="rg-par-01"></a>**RG-PAR-01** — Le partage est réservé aux utilisateurs ayant un compte NautiLink. Aucun accès anonyme.
- <a id="rg-par-02"></a>**RG-PAR-02** — Un accès a l'un de ces deux périmètres, choisi par le navigateur : *navigation* (une seule navigation, en cours ou terminée) ou *navigateur* (toutes ses navigations présentes et futures, tous bateaux confondus). Le navigateur peut changer le périmètre à tout moment ([D-04](07-decisions.md#d-04)).
- <a id="rg-par-03"></a>**RG-PAR-03** — Le navigateur invite depuis le Web ou depuis l'application mobile, par e-mail ou par numéro de téléphone, en choisissant le périmètre ([D-10](07-decisions.md#d-10)). L'invité est ajouté à la liste de contacts ([RG-CTC-04](#rg-ctc-04)).
- <a id="rg-par-04"></a>**RG-PAR-04** — Une invitation par e-mail est envoyée par le serveur. Une invitation par téléphone est envoyée en SMS par la carte SIM du téléphone Android. Depuis le Web ou un iPhone, une invitation par téléphone n'envoie pas de SMS : le Web affiche le lien d'invitation, que le navigateur transmet lui-même ([D-28](07-decisions.md#d-28)).
- <a id="rg-par-05"></a>**RG-PAR-05** — Le lien d'invitation mène à la connexion ou à la création d'un compte ; l'accès est accordé dès que l'invité est connecté. Un « lien de partage » est un lien d'invitation, jamais un accès public ([D-09](07-decisions.md#d-09)). Durée de validité : [Q-06](06-questions-ouvertes.md#q-06).
- <a id="rg-par-06"></a>**RG-PAR-06** — Le navigateur peut retirer un suiveur d'une navigation seulement, ou globalement de toutes ses navigations présentes et futures. Le retrait prend effet immédiatement.
- <a id="rg-par-07"></a>**RG-PAR-07** — Un suiveur voit en lecture seule, pour les navigations auxquelles il a accès : dernière position, positions successives, tracé, dates et heures, notes, photos, notes vocales, événements, alertes SOS.
- <a id="rg-par-08"></a>**RG-PAR-08** — Un suiveur voit aussi la fiche du bateau, la liste des autres suiveurs du navigateur et la liste de ses contacts SOS, et peut exporter en PDF les navigations auxquelles il a accès. Il ne modifie rien ([D-29](07-decisions.md#d-29)).

## 10. Paramètres

- <a id="rg-prm-01"></a>**RG-PRM-01** — Les paramètres généraux (interrupteur SMS, préférences par type, fréquence par défaut) sont modifiables depuis l'application mobile et depuis le Web et synchronisés par le serveur.
- <a id="rg-prm-02"></a>**RG-PRM-02** — L'application mobile récupère les paramètres généraux au lancement et à chaque modification lorsque Internet est disponible ; il utilise la dernière version reçue hors connexion.

## 11. Modèle économique

- <a id="rg-eco-01"></a>**RG-ECO-01** — Le quota gratuit est de 24 heures de navigation cumulées sur les 7 derniers jours glissants. Il est porté par le compte, tous bateaux confondus ([D-19](07-decisions.md#d-19)).
- <a id="rg-eco-02"></a>**RG-ECO-02** — Est décompté le temps entre le début et la fin de chaque navigation du compte en tant que navigateur, à la minute. Chaque minute redevient disponible 7 jours après avoir été consommée. Il n'y a pas de remise à zéro à date fixe.
- <a id="rg-eco-03"></a>**RG-ECO-03** — Le temps passé comme suiveur n'est jamais décompté.
- <a id="rg-eco-04"></a>**RG-ECO-04** — Quota épuisé et pas d'abonnement actif : le démarrage d'une nouvelle navigation est refusé ; l'application l'explique et propose de s'abonner ou d'attendre que des minutes redeviennent disponibles (avec l'heure à laquelle elles le redeviennent).
- <a id="rg-eco-05"></a>**RG-ECO-05** — Quota épuisé pendant une navigation en cours : la navigation continue au plus 24 heures après l'épuisement, puis elle est clôturée automatiquement. Le SOS reste disponible. Si le compte souscrit un abonnement entre-temps, la clôture automatique est annulée ([D-20](07-decisions.md#d-20)). Prévenance avant clôture : [Q-32](06-questions-ouvertes.md#q-32).
- <a id="rg-eco-06"></a>**RG-ECO-06** — Un abonnement actif lève la limite du quota pour le compte. Formules et tarifs : [Q-17](06-questions-ouvertes.md#q-17).
- <a id="rg-eco-07"></a>**RG-ECO-07** — L'abonnement se souscrit sur Android (Google Play), sur iPhone (achat intégré de l'App Store, [D-34](07-decisions.md#d-34)) ou sur le Web. Le serveur tient un seul état d'abonnement par compte, quel que soit le canal ([D-21](07-decisions.md#d-21)).
- <a id="rg-eco-08"></a>**RG-ECO-08** — Le suivi des navigations des autres et la consultation de l'historique (positions, traces, notes, notes vocales, photos, alertes SOS, journaux) sont gratuits, sans limite, avec ou sans abonnement.
- <a id="rg-eco-09"></a>**RG-ECO-09** — Le quota est calculé par le serveur. Les applications mobiles et le Web affichent le temps consommé, le temps disponible, les prochaines minutes récupérables et l'état de l'abonnement. Présentation : [Q-18](06-questions-ouvertes.md#q-18).

## 12. Notifications

- <a id="rg-not-01"></a>**RG-NOT-01** — Les notifications sont envoyées par e-mail par le serveur.
- <a id="rg-not-02"></a>**RG-NOT-02** — Événements notifiés au lancement : invitation, nouvel accès accordé, alerte SOS ([RG-SOS-06](#rg-sos-06)). Sur iPhone, les suiveurs reçoivent aussi des notifications push ([RG-IOS-06](#rg-ios-06)). Liste complète, fréquence et désinscription : [Q-16](06-questions-ouvertes.md#q-16).

## 13. Administration

- <a id="rg-adm-01"></a>**RG-ADM-01** — L'espace administrateur est distinct de l'espace utilisateur.
- <a id="rg-adm-02"></a>**RG-ADM-02** — Au lancement, il permet : gestion des utilisateurs, gestion des bateaux et de leur rattachement aux comptes, gestion des abonnements, supervision technique (serveurs, erreurs, incidents, synchronisations), publication d'annonces et d'informations de maintenance, sécurité et journaux de traçabilité, statistiques générales.
- <a id="rg-adm-03"></a>**RG-ADM-03** — L'administrateur peut consulter, modifier et supprimer les données des utilisateurs (navigations, journaux, positions, alertes SOS). Chaque action est tracée ; modalités et profils d'administrateurs : [Q-19](06-questions-ouvertes.md#q-19).
- <a id="rg-adm-04"></a>**RG-ADM-04** — La gestion des langues n'est pas une fonction de l'espace administrateur.
- <a id="rg-adm-05"></a>**RG-ADM-05** — La gestion de plusieurs versions de l'application Web est une évolution future, hors lancement ([D-22](07-decisions.md#d-22)).

## 14. Conservation des données

- <a id="rg-don-01"></a>**RG-DON-01** — Navigations et journaux de bord : conservés sans limite de durée, sauf suppression par le navigateur ([RG-NAV-20](#rg-nav-20)) ou par un administrateur.
- <a id="rg-don-02"></a>**RG-DON-02** — Positions détaillées, journaux techniques, journaux d'administration, sauvegardes, export des données personnelles : [Q-20](06-questions-ouvertes.md#q-20).

## 15. Application iPhone

L'application iPhone a les mêmes fonctions que l'application Android, avec les différences ci-dessous ([D-31](07-decisions.md#d-31)). Elle est construite après l'application Android et le Web ([D-33](07-decisions.md#d-33)).

- <a id="rg-ios-01"></a>**RG-IOS-01** — L'application iPhone sert au navigateur (démarrer, positions, journal, SOS, fin) et au suiveur (consultation et notifications). Un iPhone peut être le téléphone associé d'un bateau (RG-BAT-02).
- <a id="rg-ios-02"></a>**RG-IOS-02** — L'iPhone n'envoie aucun SMS ni MMS : ni SMS ordinaires, ni SMS SOS, ni invitations. Pour une navigation menée depuis un iPhone, l'interrupteur SMS et les préférences par type n'ont pas d'effet, et l'écran de démarrage le dit.
- <a id="rg-ios-03"></a>**RG-IOS-03** — SOS depuis un iPhone : même déclenchement (RG-SOS-02), puis envoi de l'alerte au serveur, qui envoie l'e-mail aux suiveurs et aux contacts SOS dont l'e-mail est connu (RG-SOS-06). Sans Internet, l'alerte ne peut pas partir : l'application le dit clairement et l'envoie dès que la connexion revient ([D-32](07-decisions.md#d-32)).
- <a id="rg-ios-04"></a>**RG-IOS-04** — Au démarrage d'une navigation sur iPhone, un avertissement rappelle que le SOS passe uniquement par Internet, sans SMS, et liste les contacts SOS sans e-mail, qui ne seront pas prévenus.
- <a id="rg-ios-05"></a>**RG-IOS-05** — Le suiveur sur iPhone voit les navigations auxquelles il a accès comme sur le Web, carte comprise (RG-PAR-07, RG-PAR-08).
- <a id="rg-ios-06"></a>**RG-IOS-06** — Le suiveur sur iPhone reçoit une notification push à chaque alerte SOS d'une navigation qu'il suit, en plus de l'e-mail. Autres événements notifiés : [Q-33](06-questions-ouvertes.md#q-33).
- <a id="rg-ios-07"></a>**RG-IOS-07** — L'abonnement se souscrit par achat intégré de l'App Store ; le serveur le reconnaît sur tous les supports (RG-ECO-07).
