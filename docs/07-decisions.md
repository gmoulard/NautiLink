# NautiLink — Journal des décisions

Chaque arbitrage fonctionnel est tracé ici avec un identifiant `D-nn`, sa date, le problème posé et le choix retenu. Une décision n'est jamais modifiée après coup : une décision qui en remplace une autre reçoit un nouvel identifiant et indique « remplace D-nn ».

Toute décision est reportée dans le même changement dans les règles métier ([02-regles-metier.md](02-regles-metier.md)) et les documents concernés, et la question correspondante est retirée de [06-questions-ouvertes.md](06-questions-ouvertes.md).

## 2026-11-24 — Mise en cohérence des documents initiaux

Les documents d'origine (deux cahiers des charges, règles métier, parcours utilisateur, modèle économique, identité de marque, liste de tâches) se contredisaient sur les points ci-dessous. Arbitrages du porteur du projet, sauf D-25, déduite des parcours existants (à infirmer si besoin).

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-01"></a>D-01 | Type de compte | « Profil unique de type navigateur » d'un côté ; « un seul type de compte, navigateur et suiveur » de l'autre. | Un seul type de compte ; navigateur et suiveur sont des rôles. | RG-CPT-01 |
| <a id="d-02"></a>D-02 | Confirmation du SOS | « Sans confirmation » (cahier fonctionnel, règles métier) contre « demande de confirmation » (cahier des charges, parcours). | Boîte de confirmation avant l'envoi. | RG-SOS-02 |
| <a id="d-03"></a>D-03 | Gestion des contacts SOS | Web seulement (règles métier) contre Web et Android (cahier des charges). | Web et Android, synchronisés par le serveur, copie locale sur Android. | RG-CTC-02, RG-CTC-03 |
| <a id="d-04"></a>D-04 | Périmètre du partage | Par navigation ou par bateau (cahier fonctionnel) contre « toutes les futures navigations du navigateur » (cahier des charges). | Deux périmètres paramétrables : une navigation, ou tout le navigateur. Pas de périmètre par bateau. | RG-PAR-02 |
| <a id="d-05"></a>D-05 | Fréquence des positions | Réglage général stocké sur le serveur contre choix à chaque démarrage. | Valeur par défaut dans les paramètres généraux, modifiable au démarrage pour la navigation seulement. | RG-NAV-05 |
| <a id="d-06"></a>D-06 | Destination | Saisie au démarrage (cahier fonctionnel, règles métier) ; absente de l'écran de démarrage (cahier des charges, parcours). | Facultative, en texte ou sur une carte. | RG-NAV-04 |
| <a id="d-07"></a>D-07 | Note vocale | Dictée transformée en texte (parcours, cahier des charges) contre enregistrement audio (cahier fonctionnel, tâches). | Audio conservé et transcription texte. | RG-JRN-04, RG-SMS-06 |
| <a id="d-08"></a>D-08 | Destinataires des SMS ordinaires | Non défini. | Les suiveurs de la navigation ayant un numéro de téléphone. | RG-SMS-01 |
| <a id="d-09"></a>D-09 | Lien de partage | « Lien de partage » (cahier des charges) contre partage réservé aux comptes. | Un lien de partage est un lien d'invitation ; aucun accès anonyme. | RG-PAR-01, RG-PAR-05 |
| <a id="d-10"></a>D-10 | Invitation | Depuis Android seulement (cahier des charges) contre Web et Android (parcours) ; canal SMS non défini. | Depuis le Web ou Android ; le navigateur choisit le périmètre ; e-mail par le serveur, SMS par la SIM du téléphone. | RG-PAR-03, RG-PAR-04 |
| <a id="d-11"></a>D-11 | Qui navigue avec un bateau | Non défini. | Le propriétaire seul. | RG-CPT-05 |
| <a id="d-12"></a>D-12 | Téléphone et bateaux | « Un seul téléphone par bateau » sans règle pour plusieurs bateaux. | Un téléphone peut servir plusieurs bateaux du compte ; choix du bateau au démarrage, sauf s'il n'y en a qu'un. | RG-BAT-02, RG-NAV-02 |
| <a id="d-13"></a>D-13 | Contenu du SMS SOS | « Toutes les caractéristiques » du bateau, au risque de plusieurs SMS. | Premier SMS avec l'essentiel et le lien Google Maps, second SMS avec le reste de la fiche. | RG-SOS-07, RG-SOS-08 |
| <a id="d-14"></a>D-14 | SOS et suiveurs | Non défini. | Le serveur envoie un e-mail aux suiveurs de la navigation et aux contacts SOS dont l'e-mail est connu. | RG-SOS-06 |
| <a id="d-15"></a>D-15 | Nom d'une navigation | Affiché dans les listes, origine non définie. | Généré automatiquement, modifiable. | RG-NAV-17 |
| <a id="d-16"></a>D-16 | Modification du journal | Seuls les ajouts Web modifiables ; le reste ouvert. | Notes, photos, notes vocales, ajouts : modifiables et supprimables. Début, fin, positions, SOS : figés. | RG-JRN-06, RG-JRN-07 |
| <a id="d-17"></a>D-17 | Suppression d'une navigation | Définitive ou corbeille, à confirmer. | Corbeille 30 jours, navigations terminées seulement. | RG-NAV-20 |
| <a id="d-18"></a>D-18 | Authentification | E-mail, Google, Apple (cahier fonctionnel) ; « à définir » ailleurs. | Les trois, sur le Web et Android. | RG-CPT-02 |
| <a id="d-19"></a>D-19 | Portée du quota | Non défini (un compte peut avoir plusieurs bateaux). | Par compte. | RG-ECO-01 |
| <a id="d-20"></a>D-20 | Quota épuisé en cours de navigation | Non défini. | La navigation continue au plus 24 heures après l'épuisement, puis est clôturée automatiquement. | RG-ECO-05, RG-NAV-15 |
| <a id="d-21"></a>D-21 | Canal de souscription | Non défini. | Google Play et Web, un seul état d'abonnement par compte. | RG-ECO-07 |
| <a id="d-22"></a>D-22 | Périmètre admin au lancement | Versions multiples du Web dans le périmètre admin (cahier fonctionnel) et en évolution future (tâches). | Évolution future. | RG-ADM-05 |
| <a id="d-23"></a>D-23 | Accueil Web | Liste des navigations passées (cahier fonctionnel) contre tableau de bord (cahier des charges). | Tableau de bord : navigations en cours puis historique, filtres navigateur / suiveur, prévisualisation. | [01 §6.1](01-cahier-des-charges.md#61-tableau-de-bord) |
| <a id="d-24"></a>D-24 | Organisation du dépôt | Deux cahiers des charges, noms de fichiers incohérents, liens cassés. | Un fichier par domaine, numéroté ; identifiants de règles, décisions et questions ; `CLAUDE.md`. | — |
| <a id="d-25"></a>D-25 | Création d'une navigation | « Automatique, manuelle ou les deux » ouvert dans les tâches, alors que tous les parcours décrivent un démarrage manuel. | Manuelle uniquement. | RG-NAV-01 |
