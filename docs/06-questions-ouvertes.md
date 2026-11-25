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
- Prévu (2026-11-25) : le porteur du projet ouvre le compte sur le portail API de Météo-France ; la météo est intégrée avant la sortie de la version réelle. Mode d'emploi et points à vérifier : [meteofrance-connexion.md](etudes/meteofrance-connexion.md).

### <a id="q-81"></a>Q-81 — Association du téléphone aux bateaux à la connexion

- Priorité : avant la version Android réelle (TODO-5.1).
- Cas : à la connexion sur l'application mobile, le téléphone « devient le téléphone associé au bateau » (parcours §2, RG-BAT-02). Rien ne dit quoi faire quand le compte a plusieurs bateaux, quand un bateau est déjà associé à un autre téléphone (l'associer remplace l'association précédente), ni quand le compte n'a pas encore de bateau.
- Proposition (non validée) : à chaque connexion, le téléphone est enregistré (`PUT /v1/appareils/{id}`), puis associé à tous les bateaux du compte qui n'ont pas de téléphone ; un bateau déjà associé à un autre téléphone le reste, l'association se change sur le Web (« Bateaux ») ou au démarrage d'une navigation avec ce bateau (TODO-5.2) ; sans bateau, l'écran de démarrage invite à créer la fiche (TODO-5.2).
- Appliqué en attendant dans l'application (`app/lib/reel/depot_reel.dart`, `associerTelephone`) pour l'enregistrement et les bateaux sans téléphone.

### <a id="q-82"></a>Q-82 — Autre compte sur le même téléphone

- Priorité : avant la version Android réelle (TODO-5.1).
- Cas : après une déconnexion ou une session expirée, quelqu'un se connecte sur le téléphone avec un autre compte. La déconnexion ne vide pas la file d'attente (RG-CPT-08), mais rien ne dit ce que deviennent les copies locales du premier compte (navigations, contacts, paramètres, quota) ni ses envois encore en attente.
- Proposition (non validée) : les copies locales du premier compte sont effacées à la connexion d'un autre compte ; la file d'attente reste et part avec la nouvelle session ; ce que le serveur refuse (pas propriétaire, navigation inconnue) est mis de côté comme tout refus définitif (08-architecture.md §5). Une session expirée ou fermée par le serveur ramène à l'écran de connexion avec « Votre session a expiré : reconnectez-vous. », données locales et file gardées.
- Appliqué en attendant dans l'application (`app/lib/reel/depot_reel.dart`).

### <a id="q-83"></a>Q-83 — Sortie de la file pour les statuts des SMS SOS et les fichiers

- Priorité : avant la version Android réelle (TODO-5.3, TODO-5.4, TODO-5.5).
- Cas : un élément quitte la file d'attente « à la réponse 200 ou 201 seulement » (08-architecture.md §5), mais l'API répond 204 au dépôt d'un fichier (`PUT /v1/fichiers/{evenementId}`) et aux statuts des SMS SOS (`PUT /v1/alertes-sos/{id}/sms`, élément `statuts_sms` de la synchronisation). Lu à la lettre, ces envois ne quitteraient jamais la file.
- Proposition (non validée) : 204 vaut réception pour ces deux envois, dont c'est la seule réponse de succès ; écrire « 200, 201, ou 204 pour les fichiers et les statuts des SMS » dans 08-architecture.md §5.
- Appliqué en attendant dans l'application (`app/lib/reel/file_attente.dart`).

### <a id="q-84"></a>Q-84 — Moments où l'application relit l'accueil sur le serveur

- Priorité : avant la version Android réelle (TODO-5.1).
- Cas : les contacts et les paramètres généraux sont relus au lancement et après chaque modification (08-architecture.md §4) ; rien ne dit quand l'accueil relit la navigation en cours, la liste des navigations et le quota.
- Proposition (non validée) : à l'ouverture de l'application, à la connexion, au retour de l'application au premier plan, et quand le navigateur tire l'accueil ou la liste « Navigations enregistrées » vers le bas ; la file d'attente est relancée aux mêmes moments.
- Appliqué en attendant dans l'application (`app/lib/main.dart`, `app/lib/screens/home.dart`).

## 2. Études techniques

### <a id="q-09"></a>Q-09 — GPS en arrière-plan et batterie

- Priorité : bloquant.
- Étude : enregistrement GPS application en arrière-plan ou écran éteint, consommation de batterie, comportement selon les marques et versions d'Android, et sur iPhone (localisation en arrière-plan, règles de l'App Store).
- Étude documentaire Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md).
- Étude documentaire iPhone : [localisation-arriere-plan-iphone.md](etudes/localisation-arriere-plan-iphone.md).

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

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- Décidé (D-58, D-59) : applications mobiles Android et iPhone en Flutter, un seul code ; serveur maison.
- Décidé (D-62) : serveur en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance, base PostgreSQL ; base propre au service dans `server/compose.yaml` (D-130).
- Décidé (D-86) : photos et notes vocales stockées dans PostgreSQL ; notifications push par APNs pour l'iPhone et Firebase Cloud Messaging pour Android (contenu sur Android : D-92, RG-AND-08) ; sauvegardes de pi-appliance, chaque nuit, gardées 30 jours (RG-DON-02).
- Décidé (D-96) : [08-architecture.md](08-architecture.md) validé, propositions comprises (serveur virtuel dans l'Union européenne après la bêta, relais d'e-mails avec SPF, DKIM et DMARC, géocodage par Nominatim).
- Décidé (D-115) : API ([`api/openapi.yaml`](api/openapi.yaml)) et environnements de développement, de test et de production ([08-architecture.md §6](08-architecture.md#6-environnements)) validés.
- Reste : nom de l'hébergeur et date du passage après la bêta ; sauvegarde de la base du Pi ([Q-85](#q-85)), puis essai de restauration (TODO-3.11).

## 3. Données, sécurité, conformité

### <a id="q-85"></a>Q-85 — Sauvegarde de la base du Pi

- Priorité : avant la mise en service sur le Pi (TODO-3.7).
- Cas : depuis [D-130](07-decisions.md#d-130), la base est le service `base` de `server/compose.yaml` (volume `nautilink-base`) et non plus le PostgreSQL partagé de pi-appliance, sauvegardé chaque nuit. RG-DON-02 demande une sauvegarde quotidienne gardée 30 jours.
- Proposition (non validée) : vérifier d'abord si les sauvegardes de pi-appliance couvrent les volumes des services « Docker Compose libre » ; sinon, un service de sauvegarde dans `compose.yaml` qui fait chaque nuit un `pg_dump` de la base dans un second volume, en gardant les 30 derniers, et un essai de restauration (TODO-3.11).

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
