# NautiLink — Questions ouvertes et études

Tout ce qui n'est pas encore décidé est ici, et seulement ici. Chaque question a un identifiant `Q-nn` stable, cité par les autres documents.

- **Priorité** : *bloquant* (à trancher avant de développer la fonction concernée), *lancement* (avant la mise en service), *plus tard*.
- **Proposition** : choix par défaut suggéré, **non validé**. Ne pas l'implémenter tant que le porteur du projet ne l'a pas confirmé.
- Quand une question est tranchée : ajouter une décision dans [07-decisions.md](07-decisions.md), reporter la règle dans [02-regles-metier.md](02-regles-metier.md) et les autres documents, puis supprimer la question d'ici (son identifiant n'est pas réutilisé). Le travail correspondant est suivi dans le [TODO](TODO.md).

## 1. Questions fonctionnelles

### <a id="q-39"></a>Q-39 — Service météo : conditions d'accès

- Priorité : avant la version réelle.
- Décidé (D-88) : la météo du début et de la fin d'une navigation (RG-NAV-28) vient de l'API de Météo-France.
- Reste à vérifier : conditions d'accès (clé, quotas, usage par un serveur) et présence des données demandées par RG-NAV-28 (vent, état de la mer, pression).

### <a id="q-42"></a>Q-42 — Modifications faites sur deux supports

- Priorité : bloquant pour la synchronisation (TODO-3.2).
- Cas : un même contact, les paramètres généraux ou les informations d'une même navigation sont modifiés sur le Web et sur l'application mobile hors connexion ; la modification du téléphone arrive ensuite au serveur (RG-CTC-02, RG-CTC-03, RG-PRM-01, RG-NAV-22).
- Proposition (non validée) : la dernière modification reçue par le serveur l'emporte, champ par champ ; l'application mobile affiche ensuite la version du serveur, sans message.

### <a id="q-43"></a>Q-43 — Durée des sessions

- Priorité : lancement (RG-DON-03 : « sessions qui expirent »).
- Proposition (non validée) : une session expire après 90 jours sans usage, sur l'application mobile comme sur le Web ; elle n'expire jamais sur le téléphone associé pendant une navigation en cours, pour que les envois en attente partent sans nouvelle connexion ; la déconnexion ne vide pas la file d'attente du téléphone.

### <a id="q-44"></a>Q-44 — Liens des SMS de photo et de note vocale

- Priorité : bloquant pour les SMS de photo et de note vocale (RG-SMS-05, RG-SMS-06).
- Cas : le destinataire SMS ouvre le lien sur un téléphone où il n'est pas connecté à NautiLink.
- Proposition (non validée) : comme pour tout partage (RG-PAR-01), le lien mène à la connexion, puis à la photo ou à la note vocale dans la page de la navigation ; aucun accès sans compte.

### <a id="q-45"></a>Q-45 — Envois reçus après une clôture automatique

- Priorité : bloquant pour la clôture automatique (RG-ECO-05).
- Cas : le serveur clôture la navigation par épuisement du quota pendant que le téléphone est hors connexion ; le téléphone envoie ensuite des positions, notes ou une fin acquises après l'heure de clôture.
- Proposition (non validée) : le serveur garde les événements acquis avant l'heure de clôture et refuse ceux d'après ; au premier échange, l'application apprend la clôture, arrête les positions automatiques et le dit au navigateur. Un SOS acquis après la clôture est enregistré comme un SOS depuis l'accueil (RG-SOS-15).

### <a id="q-46"></a>Q-46 — Affichage des annonces de l'administrateur

- Priorité : lancement (RG-ADM-02 : « publication d'annonces et d'informations de maintenance »).
- Proposition (non validée) : bandeau en haut de l'écran d'accueil de l'application mobile et du tableau de bord Web, jusqu'à la date de fin choisie par l'administrateur ou jusqu'à sa fermeture par l'utilisateur.

### <a id="q-47"></a>Q-47 — Portée des désinscriptions du suiveur

- Priorité : bloquant pour les notifications (RG-NOT-02, RG-IOS-06, RG-AND-08).
- Cas : un suiveur se désinscrit des e-mails de début ou désactive un type de notification push ; cela vaut-il pour toutes les navigations qu'il suit, ou pour un seul navigateur ?
- Proposition (non validée) : réglage unique du compte du suiveur, valable pour tous les navigateurs qu'il suit.

## 2. Études techniques

### <a id="q-09"></a>Q-09 — GPS en arrière-plan et batterie

- Priorité : bloquant.
- Étude : enregistrement GPS application en arrière-plan ou écran éteint, consommation de batterie, comportement selon les marques et versions d'Android, et sur iPhone (localisation en arrière-plan, règles de l'App Store).
- Étude documentaire Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md).
- Étude documentaire iPhone : [localisation-arriere-plan-iphone.md](etudes/localisation-arriere-plan-iphone.md).

### <a id="q-10"></a>Q-10 — File d'attente et doublons

- Priorité : bloquant.
- Étude : stockage local des positions et événements non transmis, renvoi après coupure, détection des doublons côté serveur.
- Proposition (non validée, TODO-2.7) : [08-architecture.md §5](08-architecture.md#5-file-dattente-et-doublons) — identifiant unique tiré par le téléphone pour chaque événement, numéro d'ordre, renvoi rejouable sans doublon, SOS en priorité, fichiers après les éléments légers.
- Reste : validation, puis essai avec 2 heures de coupure sur un vrai téléphone (TS-GPS-07, TODO-5.3).

### <a id="q-12"></a>Q-12 — Restrictions Android sur l'envoi de SMS

- Priorité : bloquant, à étudier en premier.
- Décidé (D-48) : exception « urgence » de Google Play pour les SMS SOS ; SMS ordinaires préremplis.
- Décidé (D-82) : les SMS de positions automatiques partent aussi automatiquement ; la demande de permission auprès de Google Play doit couvrir ce cas, avec le risque accepté d'un refus en dehors de l'exception « urgence » ; sans cette permission, positions au serveur seulement (D-91).
- Reste : lire la page officielle de Google Play et vérifier que l'exception existe et couvre NautiLink. Si elle est refusée, revenir vers l'utilisateur.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md) (voies possibles §3).

### <a id="q-13"></a>Q-13 — MMS

- Priorité : lancement.
- Décidé (D-49) : en cas d'échec, SMS avec le lien vers la photo.
- Reste : taille maximale des pièces jointes et compatibilité des opérateurs, à mesurer.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md#5-mms-todo-24).

### <a id="q-29"></a>Q-29 — Fonctionnement hors connexion

- Priorité : bloquant.
- Étude : comportement de chaque écran Android sans Internet, sans réseau mobile, ou sans les deux (connexion au compte, démarrage, quota non vérifiable, etc.).
- Proposition (non validée, TODO-2.6) : tableau ci-dessous. Les cases qui citent une règle sont déjà décidées ; les autres, marquées *(proposition)*, attendent la validation. « Sans Internet » : ni données mobiles ni Wi-Fi, SMS possibles ; « sans réseau mobile » : ni SMS ni données mobiles, Wi-Fi éventuel ; « sans les deux » : seul le GPS fonctionne (RG-GPS-01). Envois vers le serveur : [file d'attente](08-architecture.md#5-file-dattente-et-doublons).

| Écran | Sans Internet | Sans réseau mobile | Sans les deux |
|-------|---------------|--------------------|---------------|
| Connexion, création du compte | Impossibles ; une session déjà ouverte reste ouverte et l'application s'ouvre sur ses données locales *(proposition)*. | Possibles par Wi-Fi. | Comme sans Internet. |
| Accueil | Fonctionne sur les données locales ; résumé du quota d'après le dernier état reçu, avec son heure *(proposition)* ; SOS disponible (RG-SOS-15). | Fonctionne. | Comme sans Internet. |
| Démarrage | Autorisé si le dernier état du quota reçu ne dit pas « épuisé sans abonnement » (sinon refus, RG-ECO-04) ; le démarrage part par la file ; s'il arrive alors que le quota est épuisé, le serveur l'accepte et applique RG-ECO-05 depuis sa réception *(proposition)*. SMS de début possible. | Démarrage normal par Wi-Fi ; le SMS de début prérempli reste dans l'application SMS du téléphone, le résultat affiche son échec *(proposition)*. | Démarrage comme sans Internet, sans SMS. |
| Navigation en cours : positions, note, photo, note vocale | Enregistrées et mises en file (RG-GPS-03, RG-GPS-04) ; SMS selon les paramètres ; résultat de chaque circuit affiché (RG-COM-03). | Envoi au serveur ; SMS automatiques : 3 essais puis « Réessayer » (RG-SMS-07) ; SMS préremplis non envoyés *(proposition : échec affiché)*. | Enregistrées et mises en file ; SMS comme sans réseau mobile. |
| SOS | SMS SOS envoyés (RG-SOS-05) ; alerte mise en file en priorité ; sur iPhone, message clair et envoi au retour (RG-IOS-03). | Alerte au serveur ; SMS SOS retentés chaque minute (RG-SMS-07). | Alerte en file en priorité ; SMS SOS retentés chaque minute ; résultat affiché (RG-COM-03). |
| Fin de navigation | Fin enregistrée avec son heure réelle, transmise dès que possible (RG-NAV-14) ; la page Web ne s'ouvre pas, un message dit qu'elle sera disponible au retour de la connexion *(proposition)*. | Fin normale ; SMS de fin non envoyé, échec affiché *(proposition)*. | Comme sans Internet, sans SMS. |
| Navigations enregistrées | Dernière liste reçue, marquée « hors connexion » ; la page Web ne s'ouvre pas *(proposition)*. | Fonctionne par Wi-Fi. | Comme sans Internet. |
| Paramètres généraux | Dernière version reçue (RG-PRM-02) ; une modification est gardée et envoyée au retour (conflit : Q-42) *(proposition)*. | Fonctionne. | Comme sans Internet. |
| Contacts, invitations | Copie locale (RG-CTC-03) ; ajout et modification gardés et envoyés au retour ; invitation par e-mail envoyée au retour ; invitation par SMS impossible faute de lien, message *(proposition)*. | Fonctionne ; invitation par SMS non envoyée, échec affiché *(proposition)*. | Comme sans Internet. |
| Quota et abonnement | Dernier état reçu avec son heure ; souscription impossible, message *(proposition)*. | Fonctionne. | Comme sans Internet. |
| Historique des alertes SOS | Alertes du téléphone et dernier historique reçu *(proposition)*. | Fonctionne. | Comme sans Internet. |
| Assistance | Avertissement bêta consultable, texte inclus dans l'application (RG-CPT-07) ; contact de l'équipe impossible, message *(proposition)*. | Fonctionne. | Comme sans Internet. |

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- Décidé (D-58, D-59) : applications mobiles Android et iPhone en Flutter, un seul code ; serveur maison.
- Décidé (D-62) : serveur en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance, base PostgreSQL.
- Décidé (D-86) : photos et notes vocales stockées dans PostgreSQL ; notifications push par APNs pour l'iPhone et Firebase Cloud Messaging pour Android (contenu sur Android : D-92, RG-AND-08) ; sauvegardes de pi-appliance, chaque nuit, gardées 30 jours (RG-DON-02).
- Décidé (D-96) : [08-architecture.md](08-architecture.md) validé, propositions comprises (serveur virtuel dans l'Union européenne après la bêta, relais d'e-mails avec SPF, DKIM et DMARC, géocodage par Nominatim).
- Proposition (non validée, TODO-3.2) : API et formats de données, synchronisation : [08-architecture.md §4](08-architecture.md#4-api-et-synchronisation) et [`api/openapi.yaml`](api/openapi.yaml) ; points fonctionnels ouverts : Q-29, Q-42 à Q-47.
- Reste : nom de l'hébergeur et date du passage après la bêta ; vérifier que les sauvegardes de pi-appliance couvrent la base, puis faire un essai de restauration (TODO-3.11) ; validation de l'API ; environnements de développement, test et production.

## 3. Données, sécurité, conformité

## 4. Marque et interface

### <a id="q-26"></a>Q-26 — Nom et présence en ligne

- Priorité : lancement.
- À vérifier : disponibilité juridique du nom NautiLink, noms de domaine, comptes sur les réseaux sociaux.
- Étude : [nom NautiLink](etudes/nom-nautilink.md) (2026-11-25) : pas d'homonyme exact repéré parmi les applications ; quasi-homonyme Nauti-Link (conseil en cession d'entreprises du nautisme, France) ; bases de marques, domaines et comptes non consultés.
- Décidé (D-87) : le nom NautiLink est gardé, sous réserve des vérifications ci-dessous.
- Reste : consulter les bases de marques INPI, EUIPO et OMPI ; obtenir un avis juridique (cas Nauti-Link) ; puis réserver les domaines et les comptes libres.

### <a id="q-30"></a>Q-30 — Maquettes et accessibilité

- Priorité : bloquant pour le développement des écrans.
- Décidé (D-95) : WCAG 2.2 niveau AA (RG-PRM-05).
- Reste : validation des [maquettes](../site/designs/app.html) des écrans Android et Web.

## 5. Évolutions futures

### <a id="q-23"></a>Q-23 — Cartes marines du SHOM

- Priorité : lancement (demande de l'utilisateur du 2026-11-24, D-79).
- Étude : quelles données du SHOM sont gratuites et réutilisables sur la carte de la page d'une navigation (licence, clé d'accès, conditions d'affichage), et comment les superposer au fond OpenStreetMap et à OpenSeaMap (RG-NAV-29).

### <a id="q-27"></a>Q-27 — Autres langues

- Priorité : plus tard.
- Décidé (D-90) : français et anglais au lancement ; langue du téléphone par défaut, modifiable dans les paramètres ; messages envoyés aux suiveurs et aux contacts SOS dans la langue du navigateur (RG-PRM-03, RG-PRM-04).
- Essai dans le prototype (TODO-9.2) : textes des écrans dans `app/lib/l10n/app_fr.arb` (français, langue de référence) et `app_en.arb` (anglais), code généré par `flutter gen-l10n`.
- Décidé (D-93) : sur la plateforme Web, langue du navigateur Internet par défaut (RG-PRM-03).
- Reste : relecture de la traduction anglaise ; ajout d'autres langues après le lancement, sans gestion des langues dans l'espace administrateur (RG-ADM-04).

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).
