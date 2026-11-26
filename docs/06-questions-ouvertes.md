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

### <a id="q-93"></a>Q-93 — Texte des SMS ordinaires

- Priorité : avant la version Android réelle (TODO-5.4).
- Cas : les règles disent quand partent les SMS ordinaires (début, positions, notes, photos, notes vocales, fin : RG-SMS-01 à RG-SMS-03), ce qu'ils disent sans GPS (RG-SMS-04), et le lien d'une photo ou d'une note vocale (RG-SMS-05, RG-SMS-06, RG-SMS-09), mais pas leur texte. Le contenu des SMS SOS, lui, est fixé (RG-SOS-07, RG-SOS-08).
- Proposition (non validée) : une première ligne « NautiLink <bateau> — <type d'envoi> à <heure>. », l'heure selon RG-PRM-07 (types : « début de navigation », « position », « note », « photo », « note vocale », « fin de navigation ») ; puis, selon le type : « Destination : <destination>. » au début ; « Position <latitude>, <longitude> : <lien Google Maps> » ou « GPS NON DISPONIBLE » pour le début, les positions et la fin ; « Note : <texte> » ; « Photo : <lien> » ou « Note vocale : <lien> » vers l'élément dans la page de la navigation ; « Suivre la navigation : <lien de la page> » au début. Dans la langue du navigateur (RG-PRM-04). Le second SMS SOS commence par « SOS <bateau> (suite). ».
- Appliqué en attendant dans l'application (`app/lib/reel/sms_navigation.dart`, textes `sms…` de `app/lib/l10n/`).

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
- Décidé (D-158) : avec la permission, tous les SMS de l'application partent automatiquement, invitations comprises ; la demande auprès de Google Play doit couvrir cet usage, hors de la seule exception « urgence ».
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
- Décidé (D-93) : sur l'Application web, langue du navigateur Internet par défaut (RG-PRM-03).
- Reste : relecture de la traduction anglaise ; ajout d'autres langues après le lancement, sans gestion des langues dans l'espace administrateur (RG-ADM-04).

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).
