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
- Reste : liste des autorisations Android (localisation en arrière-plan, SMS, appareil photo, micro, notifications) ; versions minimales d'Android et d'iOS.

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- À définir : architecture technique, hébergement, base de données, stockage des fichiers, API et formats de données, mécanismes de synchronisation, environnements de développement, test et production, scénarios de tests.

## 3. Données, sécurité, conformité

## 4. Marque et interface

### <a id="q-25"></a>Q-25 — Logo et charte

- Priorité : lancement.
- À faire : valider le logo ; fichiers vectoriels ; icônes Android et iPhone ; déclinaisons claire, sombre et monochrome. La proposition actuelle utilise un repère GPS orange absent de la palette : l'ajouter à la palette ou le remplacer. Définir les couleurs du thème sombre.

### <a id="q-26"></a>Q-26 — Nom et présence en ligne

- Priorité : lancement.
- À vérifier : disponibilité juridique du nom NautiLink, noms de domaine, comptes sur les réseaux sociaux.

### <a id="q-30"></a>Q-30 — Maquettes et accessibilité

- Priorité : bloquant pour le développement des écrans.
- À produire : maquettes détaillées des écrans Android et Web ; règles d'accessibilité.

## 5. Évolutions futures

### <a id="q-23"></a>Q-23 — Cartes marines du SHOM

- Priorité : plus tard.
- Étude : intégration de la partie gratuite des cartes du SHOM sur le Web ; licences, restrictions, faisabilité, coûts.

### <a id="q-27"></a>Q-27 — Autres langues

- Priorité : plus tard.
- Étude : ajout de langues après le lancement ; architecture multilingue dès le départ, sans gestion des langues dans l'espace administrateur (RG-ADM-04).

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).

### <a id="q-37"></a>Q-37 — Hébergement sur pi-appliance

- Priorité : plus tard.
- Demande de l'utilisateur du 2026-11-24 : rendre le serveur et la plateforme Web de NautiLink installables sur un Raspberry Pi depuis la marketplace de [pi-appliance](https://github.com/gmoulard/pi-appliance) (action TODO-2.71 de ce dépôt).
- À définir : hébergement central seul, ou aussi un serveur installé chez soi ; ce que deviennent alors l'abonnement, les SMS et les e-mails ; réglage de l'adresse du serveur dans les applications Android et iPhone ; images `arm64`.
- Proposition (non validée) : à étudier après le lancement, une fois l'architecture choisie ([Q-22](#q-22)).
