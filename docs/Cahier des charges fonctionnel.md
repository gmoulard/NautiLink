NautiLink — Cahier des charges fonctionnel

1. Présentation du projet

NautiLink est une application destinée aux plaisanciers. Elle comprend deux interfaces complémentaires :

- NautiLink Web : gestion des bateaux, consultation des navigations, journal de bord, partage et administration.
- NautiLink Android : utilisation en navigation, acquisition GPS, journal de bord, alertes et envoi des SMS SOS.

Les deux applications communiquent avec un serveur central pour synchroniser les données.

2. Utilisateurs et comptes

2.1 Création et connexion

Les méthodes d’authentification prévues sont :

- Adresse e-mail et mot de passe.
- Connexion avec Google.
- Connexion avec Apple.

La langue de lancement est le français.

2.2 Profil utilisateur

Un compte possède un profil unique de type « navigateur ».

Un même compte peut gérer plusieurs bateaux.

Un seul téléphone Android est associé à chaque bateau.

2.3 Espace administrateur

Un espace administrateur général, distinct des espaces utilisateurs, permet de gérer et superviser la plateforme.

3. Fiche bateau

Chaque bateau possède une fiche comprenant :

- Nom du bateau.
- Type : voilier ou bateau à moteur.
- Longueur.
- Immatriculation.
- Port d’attache.
- Photographie.
- Caractéristiques techniques : moteur, autonomie, capacité en carburant, vitesse et tirant d’eau.

Toutes les caractéristiques enregistrées dans la fiche bateau doivent pouvoir être intégrées au SMS SOS.

4. NautiLink Web

4.1 Page d’accueil

La page d’accueil présente la liste des navigations passées, de la plus récente à la plus ancienne.

Pour chaque navigation, les informations suivantes sont affichées :

- Nom de la navigation.
- Date et heure de départ.
- Lieu de départ.
- Lieu d’arrivée.
- Durée.
- Distance parcourue.

Une prévisualisation des informations est prévue au survol sur ordinateur ou au toucher sur appareil mobile.

4.2 Détail d’une navigation

Une page complète permet de consulter :

- Les informations générales de la navigation.
- Les positions GPS enregistrées.
- Le journal de bord.
- Les photographies.
- Les événements de sécurité.

4.3 Gestion des navigations

Les navigations sont conservées sans limite de durée.

L’export d’une navigation est prévu au format PDF.

La suppression d’une navigation depuis le Web est prévue, mais le fonctionnement exact (suppression définitive ou corbeille avec restauration) reste à confirmer.

4.4 Journal de bord

Le journal de bord est créé et alimenté depuis l’application Android.

Il peut contenir :

- Des textes et notes.
- Des photographies.
- Des événements de sécurité.
- Des notes vocales, si la faisabilité technique le permet.

Depuis le Web, l’utilisateur peut consulter ces éléments et en ajouter après la navigation :

- Textes.
- Photographies.
- Notes vocales.
- Informations complémentaires.

Les éléments ajoutés depuis le Web peuvent être modifiés.

La suppression de ces éléments depuis le Web reste à confirmer.

Le journal de bord est conservé sans limite de durée.

4.5 Gestion des contacts SOS

Depuis le Web, l’utilisateur peut :

- Ajouter des contacts SOS.
- Modifier des contacts SOS.
- Supprimer des contacts SOS.

La liste des contacts est synchronisée vers Android au lancement de l’application.

4.6 Partage des navigations

Le partage permet de donner accès :

- À une navigation en cours, en temps réel.
- À une navigation terminée, à tout moment.
- À toutes les navigations d’un bateau, de manière permanente.

Le partage est réservé aux personnes identifiées dans NautiLink.

Un invité doit se connecter ou créer un compte pour accéder aux navigations partagées.

L’utilisateur peut choisir les personnes avec lesquelles il partage ses navigations.

4.7 Alertes SOS

Les alertes SOS sont consultables sur le Web et sur Android.

Les informations conservées et affichées comprennent :

- Date et heure de l’alerte.
- Position GPS transmise.
- Statut d’envoi du SMS.

Le bouton SOS est uniquement présent sur Android.

4.8 Assistance

Une fonction de contact et d’assistance est disponible depuis l’application Web.

5. NautiLink Android

5.1 Préparation d’une navigation

Au démarrage d’une navigation, l’utilisateur saisit sa destination :

- En entrant une adresse ou un lieu sous forme de texte.
- En sélectionnant une destination sur une carte.

5.2 Suivi GPS

L’application enregistre les positions GPS pendant la navigation.

La fréquence d’enregistrement est réglable à l’aide du sélecteur de temps déjà prévu dans l’application.

Le paramètre est enregistré sur le serveur et récupéré par Android au lancement de l’application.

Aucune cartographie ne doit être affichée sur l’écran Android pendant la navigation.

5.3 Journal de bord

L’utilisateur peut créer et alimenter son journal de bord depuis Android avec des textes, des photographies, des événements de sécurité et, si possible, des notes vocales.

5.4 Système SOS

Un bouton SOS est disponible sur Android.

Il déclenche automatiquement l’envoi de SMS aux contacts SOS configurés, sans demander de confirmation supplémentaire.

Le SMS SOS doit contenir :

- Les informations du bateau.
- Toutes les caractéristiques techniques enregistrées dans sa fiche.
- La dernière position GPS connue.
- La date et l’heure exactes de cette position.
- Un lien Google Maps correspondant aux coordonnées transmises.

Si le GPS fonctionne au moment du SOS, la position actuelle est utilisée.

Si le GPS ne fonctionne pas, la dernière position connue est transmise avec son horodatage et une mention indiquant clairement qu’il ne s’agit pas nécessairement de la position actuelle.

Si aucune position n’a jamais été enregistrée, le SMS indique que le GPS est indisponible et qu’aucune position connue n’est disponible.

L’historique des alertes SOS est conservé sur Android et consultable également sur le Web.

5.5 Assistance

Une fonction de contact et d’assistance est disponible depuis l’application Android.

6. Architecture de communication

NautiLink utilise deux circuits indépendants :

Circuit Internet

- Communication avec le serveur.
- Synchronisation des données.
- Transmission des positions GPS.
- Accès aux fonctionnalités connectées.

Circuit SMS

- Envoi direct depuis le téléphone Android, au moyen de sa carte SIM.
- Aucun prestataire SMS externe.
- Fonctionnement possible sans connexion Internet, sous réserve de disponibilité du réseau mobile permettant l’envoi de SMS.

Les deux circuits ne doivent pas dépendre l’un de l’autre.

Le GPS peut fonctionner indépendamment d’Internet et des SMS.

7. Notifications

Des notifications par e-mail sont prévues, notamment pour les invitations et le partage.

La liste complète des événements déclenchant une notification reste à définir.

8. Administration générale

L’espace administrateur doit permettre :

- La gestion des utilisateurs.
- La gestion des bateaux et de leurs associations aux comptes.
- La gestion des abonnements, si une offre payante est mise en place.
- La supervision technique des serveurs, erreurs, incidents et synchronisations.
- La gestion des différentes versions de l’application Web.
- La publication d’annonces et d’informations de maintenance.
- La gestion de la sécurité et des journaux de traçabilité.
- La consultation de statistiques générales.

L’administrateur peut consulter, modifier et supprimer les données des utilisateurs, notamment les navigations, journaux de bord, positions GPS et alertes SOS.

La traçabilité des actions administrateur est prévue, avec ses modalités détaillées à confirmer.

La gestion des langues n’est pas une fonction de l’espace administrateur.

9. Interface et présentation

- Identité visuelle maritime.
- Thème clair et thème sombre.
- Interface disponible en français au lancement.

10. Points restant à préciser

Les sujets non définitivement définis sont recensés dans le document "todo-et-points-a-confirmer.md".

Ce cahier des charges pourra évoluer au fil des validations fonctionnelles et techniques.
