# NautiLink — Questions ouvertes et études

Tout ce qui n'est pas encore décidé est ici, et seulement ici. Chaque question a un identifiant `Q-nn` stable, cité par les autres documents.

- **Priorité** : *bloquant* (à trancher avant de développer la fonction concernée), *lancement* (avant la mise en service), *plus tard*.
- **Proposition** : choix par défaut suggéré, **non validé**. Ne pas l'implémenter tant que le porteur du projet ne l'a pas confirmé.
- Quand une question est tranchée : ajouter une décision dans [07-decisions.md](07-decisions.md), reporter la règle dans [02-regles-metier.md](02-regles-metier.md) et les autres documents, puis supprimer la question d'ici (son identifiant n'est pas réutilisé). Le travail correspondant est suivi dans le [TODO](TODO.md).

## 1. Questions fonctionnelles

### <a id="q-40"></a>Q-40 — Positions automatiques sans permission d'envoi de SMS

- Priorité : bloquant pour les SMS sur Android.
- Question : si Google Play refuse la permission d'envoi de SMS pour les positions automatiques (risque accepté, D-82), ou si le navigateur la refuse sur son téléphone (RG-AND-04), que deviennent les SMS de positions automatiques (RG-SMS-03) ?
- Proposition (non validée) : les positions automatiques partent seulement au serveur, sans SMS ; l'écran de démarrage le dit.

### <a id="q-39"></a>Q-39 — Service météo : conditions d'accès

- Priorité : avant la version réelle.
- Décidé (D-88) : la météo du début et de la fin d'une navigation (RG-NAV-28) vient de l'API de Météo-France.
- Reste à vérifier : conditions d'accès (clé, quotas, usage par un serveur) et présence des données demandées par RG-NAV-28 (vent, état de la mer, pression).

### <a id="q-17"></a>Q-17 — Formules d'abonnement

- Priorité : lancement.
- Décidé (D-43) : une seule formule, mensuelle ou annuelle, sans période d'essai.
- Question : prix mensuel et annuel, moyens de paiement sur le Web, renouvellement et résiliation, paiements échoués, cohérence entre Google Play, l'App Store et le Web.

## 2. Études techniques

### <a id="q-09"></a>Q-09 — GPS en arrière-plan et batterie

- Priorité : bloquant.
- Étude : enregistrement GPS application en arrière-plan ou écran éteint, consommation de batterie, comportement selon les marques et versions d'Android, et sur iPhone (localisation en arrière-plan, règles de l'App Store).
- Étude documentaire Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md).
- Étude documentaire iPhone : [localisation-arriere-plan-iphone.md](etudes/localisation-arriere-plan-iphone.md).

### <a id="q-10"></a>Q-10 — File d'attente et doublons

- Priorité : bloquant.
- Étude : stockage local des positions et événements non transmis, renvoi après coupure, détection des doublons côté serveur.

### <a id="q-12"></a>Q-12 — Restrictions Android sur l'envoi de SMS

- Priorité : bloquant, à étudier en premier.
- Décidé (D-48) : exception « urgence » de Google Play pour les SMS SOS ; SMS ordinaires préremplis.
- Décidé (D-82) : les SMS de positions automatiques partent aussi automatiquement ; la demande de permission auprès de Google Play doit couvrir ce cas, avec le risque accepté d'un refus en dehors de l'exception « urgence » (Q-40).
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

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- Décidé (D-58, D-59) : applications mobiles Android et iPhone en Flutter, un seul code ; serveur maison.
- Décidé (D-62) : serveur en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance, base PostgreSQL.
- Décidé (D-86) : photos et notes vocales stockées dans PostgreSQL ; notifications push par APNs pour l'iPhone et Firebase Cloud Messaging pour Android (contenu sur Android : Q-41) ; sauvegardes de pi-appliance, chaque nuit, gardées 30 jours (RG-DON-02).
- Reste : cadre du serveur ; hébergeur après la bêta (décidé plus tard) ; vérifier que les sauvegardes de pi-appliance couvrent la base, puis faire un essai de restauration ; API et formats de données ; synchronisation ; environnements de développement, test et production.
- Propositions (non validées), détaillées dans [08-architecture.md](08-architecture.md) §3 :
  - hébergeur après la bêta : serveur virtuel dans l'Union européenne, même image Docker, PostgreSQL dédié ;
  - e-mails après la bêta : relais de l'hébergeur, SPF, DKIM et DMARC ;
  - géocodage inverse (RG-NAV-16, RG-JRN-10) : Nominatim (OpenStreetMap) appelé par le serveur, avec cache.

### <a id="q-41"></a>Q-41 — Notifications push sur Android

- Priorité : avant la version réelle.
- Question : Firebase Cloud Messaging est retenu pour Android (D-86), mais aucune règle ne prévoit de notification push pour le suiveur sur Android : lesquelles reçoit-il ?
- Proposition (non validée) : comme sur iPhone (RG-IOS-06) : alerte SOS (en plus de l'e-mail), début et fin de navigation, nouvelle photo, position en retard (même seuil, D-84) ; chaque type désactivable, sauf le SOS.

## 3. Données, sécurité, conformité

## 4. Marque et interface

### <a id="q-25"></a>Q-25 — Logo et charte

- Priorité : lancement.
- À faire : valider le logo ; fichiers vectoriels ; icônes Android et iPhone ; déclinaisons claire, sombre et monochrome. La proposition actuelle utilise un repère GPS orange absent de la palette : l'ajouter à la palette ou le remplacer. Définir les couleurs du thème sombre.

### <a id="q-26"></a>Q-26 — Nom et présence en ligne

- Priorité : lancement.
- À vérifier : disponibilité juridique du nom NautiLink, noms de domaine, comptes sur les réseaux sociaux.
- Étude : [nom NautiLink](etudes/nom-nautilink.md) (2026-11-25) : pas d'homonyme exact repéré parmi les applications ; quasi-homonyme Nauti-Link (conseil en cession d'entreprises du nautisme, France) ; bases de marques, domaines et comptes non consultés.
- Décidé (D-87) : le nom NautiLink est gardé, sous réserve des vérifications ci-dessous.
- Reste : consulter les bases de marques INPI, EUIPO et OMPI ; obtenir un avis juridique (cas Nauti-Link) ; puis réserver les domaines et les comptes libres.

### <a id="q-30"></a>Q-30 — Maquettes et accessibilité

- Priorité : bloquant pour le développement des écrans.
- À produire : maquettes détaillées des écrans Android et Web ; règles d'accessibilité.

## 5. Évolutions futures

### <a id="q-23"></a>Q-23 — Cartes marines du SHOM

- Priorité : lancement (demande de l'utilisateur du 2026-11-24, D-79).
- Étude : quelles données du SHOM sont gratuites et réutilisables sur la carte de la page d'une navigation (licence, clé d'accès, conditions d'affichage), et comment les superposer au fond OpenStreetMap et à OpenSeaMap (RG-NAV-29).

### <a id="q-27"></a>Q-27 — Autres langues

- Priorité : plus tard.
- Décidé (D-90) : français et anglais au lancement ; langue du téléphone par défaut, modifiable dans les paramètres ; messages envoyés aux suiveurs et aux contacts SOS dans la langue du navigateur (RG-PRM-03, RG-PRM-04).
- Essai dans le prototype (TODO-9.2) : textes des écrans dans `app/lib/l10n/app_fr.arb` (français, langue de référence) et `app_en.arb` (anglais), code généré par `flutter gen-l10n`.
- Reste : relecture de la traduction anglaise ; ajout d'autres langues après le lancement, sans gestion des langues dans l'espace administrateur (RG-ADM-04) ; langue par défaut sur la plateforme Web, où il n'y a pas de téléphone.
- Proposition (non validée) : sur la plateforme Web, la langue du navigateur Internet par défaut.

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).
