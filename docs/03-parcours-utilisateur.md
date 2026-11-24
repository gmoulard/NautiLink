# NautiLink — Parcours utilisateur

Ce document décrit les parcours pas à pas. Il applique les règles de [02-regles-metier.md](02-regles-metier.md) sans les redéfinir : en cas d'écart, les règles métier font foi.

## 1. Rejoindre NautiLink sur invitation

1. Le navigateur invite une personne par e-mail ou par téléphone et choisit le périmètre : cette navigation ou toutes ses navigations (RG-PAR-02, RG-PAR-03).
2. La personne reçoit l'invitation par e-mail (envoyé par le serveur) ou par SMS (envoyé par le téléphone du navigateur). Une invitation par téléphone lancée depuis le Web affiche le lien, que le navigateur transmet lui-même (RG-PAR-04).
3. Elle ouvre le lien et arrive sur la plateforme Web.
4. Elle se connecte ou crée son compte (e-mail, Google ou Apple) (RG-CPT-02).
5. Elle devient suiveur avec le périmètre choisi par le navigateur (RG-PAR-05).
6. Elle voit la navigation partagée sur son tableau de bord.

## 2. Créer son compte et son bateau

1. L'utilisateur crée son compte sur le Web ou sur Android.
2. Il crée la fiche de son bateau (RG-BAT-01).
3. Il se connecte sur son téléphone Android, qui devient le téléphone associé au bateau (RG-BAT-02).
4. Il renseigne ses contacts, sur le Web ou sur Android : chacun est par défaut suiveur (une invitation part) et contact SOS ; il décoche ce qu'il ne veut pas (RG-CTC-01, RG-CTC-04).
5. Il règle ses paramètres généraux (RG-PRM-01).

## 3. Navigateur sur Android

### 3.1 Démarrer une navigation

1. Accueil → « Démarrer navigation ».
2. Si le quota est épuisé sans abonnement : message, proposition d'abonnement ou heure de disponibilité ; fin du parcours (RG-ECO-04).
3. Choix du bateau, si le téléphone en sert plusieurs (RG-NAV-02).
4. Destination facultative, en texte ou sur une carte (RG-NAV-04).
5. Fréquence préremplie, modifiable (RG-NAV-05).
6. Facultatif : « Paramètres » pour adapter les réglages à cette navigation (RG-NAV-06).
7. « Envoi message – Début de navigation » (RG-NAV-08) : position, envoi au serveur, SMS de début si prévu, positions automatiques activées.
8. L'écran de navigation en cours s'affiche.

### 3.2 Pendant la navigation

L'écran affiche le temps depuis le début et le temps depuis le dernier envoi (RG-NAV-10).

**Envoyer une position** : « Envoyer information position » → position acquise → SMS aux destinataires si prévu → envoi au serveur → résultat affiché, par exemple « Position envoyée » (RG-COM-03).

**Note écrite** : « NOTE » → saisie → validation → journal, serveur, SMS si prévu.

**Photo** : « Photo » → prise ou sélection → validation → serveur et journal ; MMS si prévu (RG-SMS-05).

**Note vocale** : « Vocal » → enregistrement → transcription affichée → le navigateur corrige et valide → audio et texte au serveur et au journal ; le SMS éventuel contient le texte (RG-JRN-04, RG-SMS-06).

### 3.3 Déclencher un SOS

1. Bouton rouge « Envoyer un SOS », sur l'écran de navigation ou sur l'écran d'accueil (RG-SOS-15).
2. Boîte de confirmation (RG-SOS-02).
3. Confirmation.
4. Position acquise (RG-SOS-09 à RG-SOS-11).
5. SMS SOS aux contacts SOS, même sans Internet (RG-SOS-05, RG-SOS-07, RG-SOS-08).
6. Alerte envoyée au serveur, qui prévient les suiveurs par e-mail (RG-SOS-06).
7. Événement ajouté au journal.
8. Résultat affiché pour chaque circuit et chaque contact (RG-SOS-12).

### 3.4 Terminer la navigation

1. « Terminer la navigation ».
2. Confirmation.
3. SMS de fin si prévu.
4. Envoi des informations de fin au serveur ; clôture côté serveur, même si un SMS échoue (RG-NAV-13, RG-NAV-14).
5. La navigation est terminée et reste consultable sur le Web.

### 3.5 Quota épuisé pendant la navigation

1. Le quota s'épuise : l'application prévient le navigateur.
2. La navigation continue au plus 24 heures (RG-ECO-05).
3. S'il s'abonne, la navigation continue normalement ; sinon elle est clôturée automatiquement au bout des 24 heures.

### 3.6 Reprendre une navigation

Accueil → « Reprendre la dernière navigation » → écran de la navigation en cours (RG-NAV-12). Après fermeture forcée ou redémarrage du téléphone : [Q-08](06-questions-ouvertes.md#q-08).

### 3.7 Consulter ses navigations

Accueil → « Navigations enregistrées » → liste du serveur → sélection → ouverture de la page de la navigation sur la plateforme Web.

## 4. Suiveur sur le Web

### 4.1 Suivre une navigation en cours

Depuis son tableau de bord, le suiveur ouvre la navigation et voit la dernière position, les positions successives, le tracé, les dates et heures, les notes, les photos, les notes vocales, les événements et les alertes SOS (RG-PAR-07). La page se met à jour à mesure que les positions arrivent. Il peut aussi consulter la fiche du bateau, les autres suiveurs et les contacts SOS, et exporter la navigation en PDF (RG-PAR-08). Le suivi est gratuit et sans limite (RG-ECO-08).

### 4.2 Consulter une navigation terminée

Le suiveur consulte le journal tant qu'il a l'accès (RG-PAR-06).

## 5. Navigateur sur le Web

### 5.1 Gérer ses contacts

Depuis le Web ou Android, le navigateur peut :

1. voir sa liste de contacts, avec pour chacun les cases « Suiveur » et « Contact SOS » et le périmètre (RG-CTC-01) ;
2. inviter une personne par e-mail ou téléphone (RG-PAR-03) ;
3. changer le périmètre d'un suiveur (RG-PAR-02) ;
4. retirer un suiveur d'une navigation, ou de toutes ses navigations (RG-PAR-06) ;
5. cocher ou décocher « Contact SOS » (RG-CTC-05).

### 5.2 Compléter le journal

Après la navigation : ajouter textes, photos, notes vocales, informations ; modifier ou supprimer notes, photos et notes vocales ; les positions, le début, la fin et les SOS ne se modifient pas (RG-JRN-05 à RG-JRN-07).

### 5.3 Supprimer et restaurer une navigation

Page de la navigation → « Supprimer » → confirmation → corbeille ; restauration possible pendant 30 jours depuis la corbeille (RG-NAV-20).

### 5.4 Configurer

Paramètres généraux (interrupteur SMS, préférences par type, fréquence par défaut), sur le Web ou Android, synchronisés (RG-PRM-01, RG-SMS-02).

### 5.5 Quota et abonnement

Le navigateur consulte le temps consommé, le temps disponible et l'heure à laquelle des minutes redeviennent disponibles (RG-ECO-09). Il peut s'abonner sur le Web ou sur Android (RG-ECO-07).

## 6. Points restant à concevoir

Maquettes, autorisations Android, reprise après perte de réseau ou redémarrage, erreurs d'envoi, hors connexion, accessibilité : voir [06-questions-ouvertes.md](06-questions-ouvertes.md).
