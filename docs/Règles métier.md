CahieNautiLink — Règles métier

1. Gestion des comptes et des bateaux

1. Un utilisateur possède un compte NautiLink.
2. Un compte peut être associé à plusieurs bateaux.
3. Chaque bateau possède sa propre fiche descriptive et technique.
4. Un seul téléphone Android est associé à un bateau.
5. Les données de chaque bateau doivent rester clairement séparées de celles des autres bateaux du compte.
6. L'utilisateur dispose d'un profil unique de type « navigateur ».

2. Gestion des navigations

2.1 Création et suivi

1. Une navigation est associée à un bateau.
2. Au démarrage, l'utilisateur renseigne une destination.
3. La destination peut être saisie sous forme de texte ou choisie sur une carte.
4. Android enregistre les positions GPS selon la fréquence configurée.
5. La fréquence est définie par le sélecteur de temps existant dans l'application.
6. Le paramètre est enregistré sur le serveur et récupéré par Android au lancement de l'application.
7. Aucune cartographie ne doit être affichée sur l'écran Android pendant la navigation.

2.2 Historique

1. Les navigations terminées sont conservées sans limite de durée.
2. Sur le Web, elles sont présentées de la plus récente à la plus ancienne.
3. Chaque navigation comporte au minimum son nom, ses dates et heures, ses lieux de départ et d'arrivée, sa durée et sa distance.
4. Une navigation peut être consultée dans une page détaillée.
5. L'export d'une navigation est réalisé au format PDF.
6. La règle exacte de suppression d'une navigation reste à confirmer.

3. Journal de bord

1. Le journal de bord est alimenté principalement depuis Android.
2. Il peut contenir des textes, des photographies, des événements de sécurité et, si possible, des notes vocales.
3. Les éléments sont associés à la navigation concernée.
4. Depuis le Web, l'utilisateur peut consulter le journal de bord.
5. Depuis le Web, l'utilisateur peut également ajouter des textes, photographies, notes vocales et informations complémentaires après la navigation.
6. Les éléments ajoutés depuis le Web peuvent être modifiés.
7. La suppression des éléments ajoutés depuis le Web reste à confirmer.
8. Le journal de bord est conservé sans limite de durée.

4. GPS et positions

1. Le GPS doit pouvoir fonctionner sans connexion Internet.
2. L'enregistrement des positions ne doit pas dépendre de la disponibilité du serveur.
3. Les positions sont enregistrées selon la fréquence définie dans les paramètres.
4. Les positions disponibles sont synchronisées avec le serveur lorsque la connexion Internet le permet.
5. Une absence de connexion Internet ne doit pas empêcher le fonctionnement du GPS.
6. Les positions doivent être horodatées afin de connaître précisément le moment de leur acquisition.

5. Fonctionnement des communications

NautiLink repose sur deux circuits indépendants.

5.1 Circuit Internet

Il assure :

- La communication avec le serveur.
- La synchronisation des données.
- La transmission des positions GPS.
- L'accès aux fonctions connectées.

5.2 Circuit SMS

Il assure :

- L'envoi direct des SMS depuis le téléphone Android.
- L'utilisation de la carte SIM du téléphone.
- L'envoi sans prestataire SMS externe.

5.3 Indépendance des circuits

1. Une panne Internet ne doit pas empêcher l'envoi d'un SMS si le réseau mobile permet l'envoi de SMS.
2. Une indisponibilité du service SMS ne doit pas interrompre la communication Internet.
3. Le GPS ne doit dépendre ni d'Internet ni du service SMS.
4. L'indisponibilité d'un circuit ne doit pas bloquer les autres.

6. Règles d'envoi des SMS

1. Les SMS prévus par la configuration sont envoyés automatiquement.
2. Aucun écran de confirmation ne doit bloquer l'envoi d'une alerte SOS.
3. Les événements concernés peuvent notamment inclure le début et la fin d'une navigation, ainsi que des événements particuliers paramétrés.
4. Si le GPS est indisponible pour un SMS ordinaire nécessitant une position, le message doit indiquer « GPS NON DISPONIBLE » plutôt que de transmettre une position supposée ou ancienne.

7. Règles spécifiques au SOS

7.1 Déclenchement

1. Le bouton SOS est disponible uniquement sur Android.
2. Le déclenchement entraîne automatiquement l'envoi de SMS aux contacts SOS configurés.
3. L'envoi ne nécessite pas de confirmation supplémentaire.

7.2 Contenu du SMS SOS

Le SMS SOS doit contenir :

- Le nom du bateau.
- Toutes les caractéristiques enregistrées dans la fiche bateau.
- Les coordonnées GPS disponibles.
- La date et l'heure exactes de l'acquisition de la position transmise.
- Un lien Google Maps correspondant à cette position.

7.3 Gestion de la position GPS

Cas 1 — GPS disponible au moment du SOS

La position actuelle est transmise, avec sa date et son heure d'acquisition.

Cas 2 — GPS indisponible au moment du SOS, mais une position antérieure existe

La dernière position GPS connue est transmise avec :

- Ses coordonnées.
- Sa date et son heure exactes d'acquisition.
- Un lien Google Maps.
- Une mention explicite indiquant qu'il s'agit de la dernière position connue et qu'elle ne correspond pas nécessairement à la position actuelle.

Cas 3 — Aucune position GPS connue

Le SMS indique que le GPS est indisponible et qu'aucune position connue n'est disponible.

7.4 Historique des alertes SOS

Chaque alerte SOS doit être conservée avec :

- Sa date et son heure.
- La position GPS transmise.
- Le statut d'envoi du SMS.

Les alertes doivent être consultables sur Android et sur le Web.

Le statut d'envoi doit distinguer autant que possible un SMS accepté pour envoi d'un SMS dont la livraison a été confirmée, lorsque cette information est disponible.

8. Contacts SOS

1. Les contacts SOS sont gérés depuis le Web.
2. L'utilisateur peut ajouter, modifier et supprimer des contacts.
3. La liste des contacts est synchronisée vers Android au lancement de l'application.
4. Android utilise la dernière liste synchronisée pour les envois SOS.
5. L'indisponibilité d'Internet au moment du SOS ne doit pas empêcher l'utilisation de cette liste déjà présente sur le téléphone.

9. Partage des navigations

9.1 Types de partage

Deux modes de partage sont prévus :

- Partage d'une navigation précise, en cours ou terminée.
- Accès permanent à toutes les navigations d'un bateau.

9.2 Personnes autorisées

1. Le partage est réservé aux personnes identifiées dans NautiLink.
2. Un invité doit disposer d'un compte ou en créer un.
3. L'utilisateur choisit les personnes autorisées à accéder aux données.
4. Les personnes invitées peuvent consulter les navigations en temps réel et les navigations historiques selon les droits accordés.

9.3 Accès et révocation

Les modalités précises d'invitation, de durée du partage, de révocation des accès et de notification restent à définir.

10. Notifications par e-mail

1. NautiLink doit pouvoir envoyer des notifications par e-mail.
2. Les invitations et les partages font notamment partie des événements concernés.
3. La liste complète des événements déclencheurs reste à définir.

11. Administration et traçabilité

1. L'espace administrateur est distinct de l'espace utilisateur.
2. L'administrateur peut consulter, modifier et supprimer les données des utilisateurs dans le périmètre défini.
3. Les données concernées comprennent notamment les navigations, journaux de bord, positions GPS et alertes SOS.
4. Les actions administrateur doivent faire l'objet d'une traçabilité, selon des modalités restant à préciser.
5. La gestion des langues ne fait pas partie des fonctions de l'espace administrateur.

12. Conservation des données

Les navigations et les journaux de bord sont conservés sans limite de durée.

Les modalités de conservation des autres données, notamment les positions GPS détaillées, les historiques techniques et les journaux d'administration, restent à préciser.

13. Points à confirmer ou à étudier

Les sujets qui nécessitent encore une décision ou une étude technique sont regroupés dans "todo-et-points-a-confirmer.md".

En particulier :

- Le mode exact de suppression des navigations.
- La suppression éventuelle des éléments ajoutés au journal de bord depuis le Web.
- Les règles détaillées de partage et de révocation.
- Les événements déclenchant les notifications.
- Les modalités de traçabilité des actions administrateur.
- Les durées de conservation des données autres que les navigations et journaux de bord.
