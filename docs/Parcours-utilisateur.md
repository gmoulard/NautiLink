NautiLink — Parcours utilisateur

Signature : Your sea, your safety, your story.
Version : 1.0

---

1. Objectif

Ce document décrit les principaux parcours d'utilisation de NautiLink, depuis la création d'un compte jusqu'au suivi d'une navigation et à la consultation du journal de bord.

NautiLink comporte deux interfaces :

- Une application Android destinée principalement au navigateur.
- Une plateforme Web destinée à la consultation, au suivi et à la gestion des navigations.

Un même utilisateur peut être navigateur et suiveur.

2. Création d'un compte

1. L'utilisateur reçoit une invitation par e-mail ou SMS.
2. Il clique sur le lien reçu.
3. Il accède à la plateforme Web NautiLink.
4. Il crée son compte.
5. Son compte est associé automatiquement au navigateur qui l'a invité.
6. Il devient suiveur de ce navigateur et accède à la navigation pour laquelle il a été invité.
7. Il pourra également suivre automatiquement les futures navigations de ce navigateur.

3. Parcours du navigateur sur Android

3.1 Ouverture de l'application

L'écran d'accueil propose trois possibilités :

- Démarrer navigation ;
- Reprendre la dernière navigation ;
- Navigations enregistrées.

3.2 Démarrer une navigation

1. Le navigateur appuie sur « Démarrer navigation ».
2. Il choisit une fréquence d'envoi automatique : 3, 4, 5, 10, 15 ou 30 minutes, ou 1 heure.
3. Il peut ouvrir le bouton « Paramètres » pour modifier les réglages de cette navigation uniquement.
4. Il appuie sur « Envoi message – Début de navigation ».
5. L'application récupère la position GPS.
6. Le début de navigation est enregistré sur le serveur.
7. Le SMS de début est envoyé si les paramètres le prévoient.
8. Les transmissions automatiques sont activées.

Les réglages spécifiques à cette navigation ne modifient pas les paramètres généraux.

3.3 Navigation en cours

L'écran affiche deux chronomètres :

- Temps écoulé depuis le début de la navigation ;
- Temps écoulé depuis le dernier envoi des messages.

Le navigateur peut effectuer plusieurs actions.

Envoyer une position

1. Appuyer sur « Envoyer information position ».
2. L'application récupère les coordonnées GPS.
3. Elle envoie un SMS si cette transmission est activée.
4. Elle transmet la position au serveur par API.
5. Elle affiche une confirmation, par exemple « Position envoyée ».

Ajouter une note écrite

1. Appuyer sur « NOTE ».
2. Saisir le texte.
3. Valider l'envoi.
4. L'application transmet l'information selon les paramètres SMS et API.
5. La note est ajoutée au journal de bord.

Ajouter une photographie

1. Appuyer sur « Photo ».
2. Prendre une photographie ou en sélectionner une.
3. Valider l'envoi.
4. L'application transmet la photo au serveur.
5. Un MMS peut être envoyé avec la photographie en pièce jointe si cette option est activée.
6. Le journal de bord conserve la photo et son événement associé.

Ajouter une note vocale

1. Appuyer sur « Vocal ».
2. Dicter une information.
3. La reconnaissance vocale transforme la dictée en texte.
4. Le navigateur valide le texte.
5. L'information est transmise selon les paramètres configurés.
6. La note est ajoutée au journal de bord.

3.4 Déclencher une alerte SOS

1. Appuyer sur le bouton rouge « Envoyer un SOS ».
2. Une demande de confirmation apparaît.
3. Confirmer l'envoi.
4. L'application récupère la position GPS.
5. Un SMS est envoyé aux contacts SOS configurés.
6. Une alerte accompagnée de la position est transmise au serveur par API.
7. L'événement est enregistré dans le journal de bord.
8. Une confirmation est affichée.

3.5 Terminer une navigation

1. Appuyer sur « Terminer la navigation ».
2. Confirmer la clôture.
3. L'application envoie le dernier SMS si les paramètres le prévoient.
4. Les informations de fin sont transmises au serveur par API.
5. La navigation est clôturée côté serveur.
6. Le journal de bord est archivé et reste consultable.

4. Reprendre une navigation

Si une navigation est toujours en cours, le navigateur peut ouvrir l'application et appuyer sur « Reprendre la dernière navigation ».

L'application retrouve la navigation en cours et affiche son écran de suivi.

Les modalités techniques de reprise après fermeture forcée ou redémarrage du téléphone restent à définir.

5. Consulter les navigations enregistrées

1. Depuis l'accueil Android, appuyer sur « Navigations enregistrées ».
2. L'application récupère la liste depuis le serveur.
3. Sélectionner une navigation.
4. La plateforme Web s'ouvre sur la page correspondante.
5. Le navigateur peut consulter la carte et le journal de bord.

6. Parcours du suiveur sur le Web

6.1 Accéder à une navigation

1. Le suiveur reçoit une invitation.
2. Il clique sur le lien.
3. Il crée son compte s'il n'en possède pas encore.
4. Il accède à la navigation partagée.
5. Il peut consulter la position et les informations transmises.

6.2 Suivre une navigation en cours

La plateforme Web présente :

- La dernière position connue ;
- Les positions successives ;
- Le tracé sur la carte ;
- Les dates et heures ;
- Les notes ;
- Les photographies ;
- Les événements importants ;
- Les alertes SOS.

Le suivi est gratuit et sans limite de durée.

6.3 Consulter une navigation terminée

Le suiveur autorisé peut consulter le journal de bord de la navigation terminée.

Les informations archivées restent accessibles gratuitement, sous réserve du maintien de ses droits d'accès.

7. Parcours de gestion des suiveurs

Le navigateur peut gérer ses suiveurs depuis l'application et la plateforme Web.

Il peut :

1. Consulter la liste des personnes associées à ses navigations.
2. Inviter une nouvelle personne par e-mail ou téléphone.
3. Donner accès à une navigation.
4. Retirer un accès pour une navigation seulement.
5. Retirer globalement une personne de toutes ses navigations présentes et futures.
6. Gérer les liens de partage et révoquer les accès.

8. Parcours de configuration

Les paramètres généraux sont accessibles depuis Android et le Web.

L'utilisateur peut configurer :

- L'activation générale des SMS ;
- Les SMS de début de navigation ;
- Les positions automatiques ;
- Les positions manuelles ;
- Les notes écrites ;
- Les photos ;
- Les notes vocales ;
- Les alertes SOS ;
- Les SMS de fin de navigation ;
- Les contacts destinataires des SOS.

Les paramètres sont synchronisés entre les deux interfaces.

Lors du démarrage d'une navigation, les réglages peuvent être adaptés pour cette navigation sans modifier les réglages généraux.

9. Parcours lié au quota gratuit

Le navigateur peut consulter son temps de navigation consommé et son temps disponible.

Le quota gratuit est de 24 heures de navigation cumulées sur les sept derniers jours glissants.

Lorsque le quota est épuisé :

1. L'application informe le navigateur.
2. Une nouvelle navigation ne peut pas être démarrée sans abonnement.
3. Le navigateur peut souscrire un abonnement ou attendre que des minutes redeviennent disponibles.

Le suivi des autres navigateurs et la consultation de l'historique restent gratuits.

10. Principes d'expérience utilisateur

Les interfaces doivent privilégier :

- Une utilisation simple et rapide à bord ;
- Des boutons clairement identifiables ;
- Une bonne lisibilité ;
- Une confirmation avant les actions sensibles comme le SOS ou la clôture ;
- Une indication claire du résultat des transmissions ;
- Une distinction nette entre navigation et suivi ;
- Un accès simple au journal de bord.

Les actions importantes doivent rester compréhensibles même dans des conditions d'utilisation difficiles à bord d'un bateau.

11. Points restant à définir

Les points suivants nécessitent une conception complémentaire :

- Maquettes graphiques détaillées des écrans ;
- Gestion des autorisations Android ;
- Reprise après perte de réseau ou redémarrage ;
- Notifications aux suiveurs ;
- Gestion des erreurs d'envoi SMS, MMS et API ;
- Détails de l'authentification Web ;
- Accessibilité et ergonomie ;
- Fonctionnement hors connexion.

12. Conclusion

Le parcours NautiLink doit être fluide pour le navigateur et simple pour les proches qui le suivent.

Le navigateur démarre sa navigation, partage sa position, transmet ses informations et conserve un journal de bord. Les suiveurs consultent les informations partagées depuis le Web.

L'ensemble doit former une expérience cohérente entre l'application Android et la plateforme Web.
