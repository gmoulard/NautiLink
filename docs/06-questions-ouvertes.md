# NautiLink — Questions ouvertes et études

Tout ce qui n'est pas encore décidé est ici, et seulement ici. Chaque question a un identifiant `Q-nn` stable, cité par les autres documents.

- **Priorité** : *bloquant* (à trancher avant de développer la fonction concernée), *lancement* (avant la mise en service), *plus tard*.
- **Proposition** : choix par défaut suggéré, **non validé**. Ne pas l'implémenter tant que le porteur du projet ne l'a pas confirmé.
- Quand une question est tranchée : ajouter une décision dans [07-decisions.md](07-decisions.md), reporter la règle dans [02-regles-metier.md](02-regles-metier.md) et les autres documents, puis supprimer la question d'ici (son identifiant n'est pas réutilisé). Le travail correspondant est suivi dans le [TODO](TODO.md).

## 1. Questions fonctionnelles

### <a id="q-36"></a>Q-36 — SMS préremplis : positions automatiques et nouvelles tentatives

- Priorité : bloquant pour les SMS sur Android.
- Question : avec des SMS ordinaires préremplis (RG-SMS-03), un SMS de position automatique demanderait un appui toutes les N minutes, et l'application ne voit pas si un SMS prérempli est parti (nouvelles tentatives de RG-SMS-07). Que faire ?
- Proposition : les positions automatiques ne partent plus par SMS, seulement au serveur ; les nouvelles tentatives ne concernent que les SMS SOS.

### <a id="q-39"></a>Q-39 — Service météo

- Priorité : avant la version réelle.
- Question : quel service fournit la météo marine relevée au début et à la fin d'une navigation (RG-NAV-28) : gratuit, utilisable par un serveur, avec vent, état de la mer et pression ?
- Proposition : Open-Meteo (API météo et API marine), sans clé pour un usage non commercial ; à vérifier pour un usage commercial.

### <a id="q-38"></a>Q-38 — Proposition de fin après « Continuer »

- Priorité : avant la version réelle.
- Question : quand le navigateur répond « Continuer » à la proposition de terminer une navigation immobile (RG-NAV-24), quand l'application la propose-t-elle de nouveau ?
- Proposition : après 2 nouvelles heures sans éloignement de plus de 20 mètres.

### <a id="q-35"></a>Q-35 — Position en retard

- Priorité : avant l'application iPhone.
- Question : à partir de quand une position est-elle « en retard » et déclenche-t-elle une notification push au suiveur (RG-IOS-06) ?
- Proposition : aucune position reçue pendant deux fois la fréquence de la navigation, une seule notification jusqu'à la position suivante.

### <a id="q-34"></a>Q-34 — Changer les heures d'une navigation

- Priorité : bloquant pour RG-NAV-22.
- Question : si le navigateur change les heures de début ou de fin (RG-NAV-22), le quota est-il recalculé, et que deviennent les positions et événements hors de la nouvelle plage ?
- Proposition : le quota reste calculé sur les heures réellement enregistrées par le téléphone ; les positions et événements hors plage sont gardés mais masqués du tracé.

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
- Décidé (D-48) : exception « urgence » de Google Play pour les seuls SMS SOS ; SMS ordinaires préremplis.
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

### <a id="q-31"></a>Q-31 — Autorisations Android

- Priorité : bloquant.
- Décidé : localisation « Pendant l'utilisation » sur iPhone (D-54) ; exclusion de l'optimisation de la batterie sur Android (D-52).
- Étude : [autorisations Android](etudes/autorisations-android.md) (liste, versions concernées, règles Google Play). Version visée imposée par Google Play : Android 16 (API 36).
- Décidé (D-80) : Android 8.0 au minimum ; autorisations demandées au moment où elles servent et redemandées à chaque besoin ; localisation précise refusée : navigation sans positions (RG-AND-01 à RG-AND-03).
- Décidé (D-81) : envoi de SMS refusé : SOS par Internet plus SMS SOS prérempli ; réveil entre deux positions par une minuterie (RG-AND-04, RG-AND-05).
- Reste : version minimale d'iOS ; appareil photo de NautiLink ou du téléphone ; choix de la SIM sur les téléphones à deux SIM.

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- Décidé (D-58, D-59) : applications mobiles Android et iPhone en Flutter, un seul code ; serveur maison.
- Décidé (D-62) : serveur en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance, base PostgreSQL.
- Reste : cadre du serveur, hébergeur après la bêta, stockage des fichiers, notifications push, sauvegardes, API et formats de données, synchronisation, environnements de développement, test et production.
- Propositions (non validées), détaillées dans [08-architecture.md](08-architecture.md) §3 :
  - photos et notes vocales : fichiers dans un volume Docker du serveur, description dans PostgreSQL, servis par le serveur après contrôle de l'accès ;
  - hébergeur après la bêta : serveur virtuel dans l'Union européenne, même image Docker, PostgreSQL dédié ;
  - notifications push (RG-IOS-06) : appel direct du service push d'Apple (APNs) par le serveur ; Firebase Cloud Messaging seulement si Android doit aussi en recevoir ;
  - sauvegardes (RG-DON-02) : copie nocturne de la base et des fichiers hors du Pi, 30 jours, essai de restauration avant la bêta ;
  - e-mails après la bêta : relais de l'hébergeur, SPF, DKIM et DMARC ;
  - géocodage inverse (RG-NAV-16, RG-JRN-10) : Nominatim (OpenStreetMap) appelé par le serveur, avec cache.

## 3. Données, sécurité, conformité

## 4. Marque et interface

### <a id="q-25"></a>Q-25 — Logo et charte

- Priorité : lancement.
- À faire : valider le logo ; fichiers vectoriels ; icônes Android et iPhone ; déclinaisons claire, sombre et monochrome. La proposition actuelle utilise un repère GPS orange absent de la palette : l'ajouter à la palette ou le remplacer. Définir les couleurs du thème sombre.

### <a id="q-26"></a>Q-26 — Nom et présence en ligne

- Priorité : lancement.
- À vérifier : disponibilité juridique du nom NautiLink, noms de domaine, comptes sur les réseaux sociaux.
- Étude : [nom NautiLink](etudes/nom-nautilink.md) (2026-11-25) : pas d'homonyme exact repéré parmi les applications ; quasi-homonyme Nauti-Link (conseil en cession d'entreprises du nautisme, France) ; bases de marques, domaines et comptes non consultés.
- Proposition (non validée) : garder le nom NautiLink sous réserve de la consultation des bases INPI, EUIPO et OMPI et d'un avis juridique, puis réserver les domaines et comptes libres.

### <a id="q-30"></a>Q-30 — Maquettes et accessibilité

- Priorité : bloquant pour le développement des écrans.
- À produire : maquettes détaillées des écrans Android et Web ; règles d'accessibilité.

## 5. Évolutions futures

### <a id="q-23"></a>Q-23 — Cartes marines du SHOM

- Priorité : lancement (demande de l'utilisateur du 2026-11-24, D-79).
- Étude : quelles données du SHOM sont gratuites et réutilisables sur la carte de la page d'une navigation (licence, clé d'accès, conditions d'affichage), et comment les superposer au fond OpenStreetMap et à OpenSeaMap (RG-NAV-29).

### <a id="q-27"></a>Q-27 — Autres langues

- Priorité : plus tard.
- Étude : ajout de langues après le lancement ; architecture multilingue dès le départ, sans gestion des langues dans l'espace administrateur (RG-ADM-04).
- Essai dans le prototype (TODO-9.2, **non validé**) : textes des écrans dans `app/lib/l10n/app_fr.arb` (français, langue de référence, libellés identiques à la spécification), traduction d'essai en anglais dans `app_en.arb`, code généré par `flutter gen-l10n` ; français par défaut, anglais au lancement avec `--dart-define=NAUTILINK_LANG=en`.
- Reste à décider : langues proposées ; choix de la langue (celle du téléphone ou un réglage) ; langue des SMS, e-mails et du journal envoyés aux suiveurs et contacts SOS (restés en français dans le prototype) ; relecture des traductions.

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).
