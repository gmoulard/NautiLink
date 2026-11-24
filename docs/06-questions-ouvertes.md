# NautiLink — Questions ouvertes et études

Tout ce qui n'est pas encore décidé est ici, et seulement ici. Chaque question a un identifiant `Q-nn` stable, cité par les autres documents.

- **Priorité** : *bloquant* (à trancher avant de développer la fonction concernée), *lancement* (avant la mise en service), *plus tard*.
- **Proposition** : choix par défaut suggéré, **non validé**. Ne pas l'implémenter tant que le porteur du projet ne l'a pas confirmé.
- Quand une question est tranchée : ajouter une décision dans [07-decisions.md](07-decisions.md), reporter la règle dans [02-regles-metier.md](02-regles-metier.md) et les autres documents, puis supprimer la question d'ici (son identifiant n'est pas réutilisé). Le travail correspondant est suivi dans le [TODO](TODO.md).

## 1. Questions fonctionnelles

### <a id="q-01"></a>Q-01 — Lieu d'arrivée et distance

- Priorité : bloquant.
- Question : comment sont déterminés le lieu de départ, le lieu d'arrivée et la distance d'une navigation (RG-NAV-16) ?
- Proposition : lieux = nom du lieu le plus proche de la première et de la dernière position (géocodage inverse), sinon coordonnées ; distance = somme des distances entre positions successives.

### <a id="q-04"></a>Q-04 — Refus des SMS par un suiveur

- Priorité : lancement.
- Question : un suiveur peut-il refuser de recevoir les SMS ordinaires d'un navigateur (RG-SMS-01) ? Faut-il son consentement préalable ?
- Proposition : oui, option « recevoir les SMS » dans son profil, activée par défaut lorsqu'il renseigne un numéro.

### <a id="q-06"></a>Q-06 — Validité d'une invitation

- Priorité : lancement.
- Question : durée de validité, usage unique ou multiple, renvoi, annulation par le navigateur.
- Proposition : 7 jours, usage unique, renvoyable et annulable.

### <a id="q-24"></a>Q-24 — Modifier les informations d'une navigation

- Priorité : lancement.
- Question : en dehors du nom (RG-NAV-17), quelles informations le navigateur peut-il modifier (destination, bateau, heures) ?
- Proposition : nom et destination seulement.

### <a id="q-32"></a>Q-32 — Prévenir avant la clôture automatique

- Priorité : lancement.
- Question : comment prévenir le navigateur que sa navigation sera clôturée au bout des 24 heures suivant l'épuisement du quota (RG-ECO-05) ?
- Proposition : avertissement à l'épuisement, puis 1 heure avant la clôture, sur l'écran de navigation ; SMS de fin envoyé si les paramètres le prévoient.

### <a id="q-33"></a>Q-33 — Notifications push sur iPhone

- Priorité : avant l'application iPhone.
- Question : en plus du SOS (RG-IOS-06), quels événements déclenchent une notification push au suiveur (début et fin de navigation, nouvelle photo, retard de position) ? Peut-il les régler ?
- Proposition : début, fin et SOS ; chaque type désactivable sauf le SOS.

### <a id="q-16"></a>Q-16 — Notifications

- Priorité : lancement.
- Question : liste complète des événements qui envoient un e-mail (début de navigation aux suiveurs ? fin ? quota épuisé ?), fréquence, désinscription.

### <a id="q-18"></a>Q-18 — Présentation du quota

- Priorité : lancement.
- Question : écrans et formulation du temps consommé, du temps disponible et des minutes récupérables.

### <a id="q-17"></a>Q-17 — Formules d'abonnement

- Priorité : lancement.
- Question : prix, nombre et contenu des formules, limites, périodicité, moyens de paiement, renouvellement et résiliation, période d'essai, paiements échoués, changement de formule, cohérence entre Google Play et le Web.

### <a id="q-19"></a>Q-19 — Administration

- Priorité : lancement.
- Question : profils et niveaux d'accès des administrateurs ; contenu et durée des journaux de traçabilité ; contrôle des suppressions ; un administrateur peut-il modifier des positions et alertes SOS que le navigateur lui-même ne peut pas modifier (RG-JRN-07) ?

## 2. Études techniques

### <a id="q-08"></a>Q-08 — Reprise après fermeture forcée ou redémarrage

- Priorité : bloquant.
- Question : la navigation en cours et les positions automatiques reprennent-elles seules après un redémarrage du téléphone ou une fermeture forcée de l'application ?
- Proposition : oui, l'enregistrement reprend automatiquement et l'écran de navigation s'ouvre au lancement suivant.
- Éléments techniques Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md) §3.

### <a id="q-09"></a>Q-09 — GPS en arrière-plan et batterie

- Priorité : bloquant.
- Étude : enregistrement GPS application en arrière-plan ou écran éteint, consommation de batterie, comportement selon les marques et versions d'Android, et sur iPhone (localisation en arrière-plan, règles de l'App Store).
- Étude documentaire Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md).

### <a id="q-10"></a>Q-10 — File d'attente et doublons

- Priorité : bloquant.
- Étude : stockage local des positions et événements non transmis, renvoi après coupure, détection des doublons côté serveur.

### <a id="q-11"></a>Q-11 — Échecs d'envoi des SMS

- Priorité : bloquant.
- Question : nombre et rythme des nouvelles tentatives, en particulier pour le SOS ; affichage de l'échec.

### <a id="q-12"></a>Q-12 — Restrictions Android sur l'envoi de SMS

- Priorité : bloquant, à étudier en premier.
- Étude : Google Play restreint fortement la permission d'envoyer des SMS aux applications qui ne sont pas l'application SMS par défaut. Vérifier si NautiLink peut obtenir une exception, ou prévoir une alternative (ouverture de l'application SMS préremplie, distribution hors Play Store). Tout le circuit SMS en dépend.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md) (voies possibles §3).

### <a id="q-13"></a>Q-13 — MMS

- Priorité : lancement.
- Étude : taille maximale des pièces jointes, compatibilité opérateurs, comportement si MMS impossible.

### <a id="q-14"></a>Q-14 — Notes vocales

- Priorité : bloquant pour la fonction Vocal.
- Étude : format audio, durée et taille maximales, stockage serveur, moteur de transcription (sur le téléphone, utilisable hors connexion, ou sur le serveur).

### <a id="q-15"></a>Q-15 — Photos

- Priorité : lancement.
- Question : taille maximale, compression, nombre de photos par navigation.

### <a id="q-29"></a>Q-29 — Fonctionnement hors connexion

- Priorité : bloquant.
- Étude : comportement de chaque écran Android sans Internet, sans réseau mobile, ou sans les deux (connexion au compte, démarrage, quota non vérifiable, etc.).

### <a id="q-31"></a>Q-31 — Autorisations Android

- Priorité : bloquant.
- Étude : localisation (y compris en arrière-plan), SMS, appareil photo, micro, notifications ; versions d'Android et d'iOS visées.

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- À définir : architecture technique, hébergement, base de données, stockage des fichiers, API et formats de données, mécanismes de synchronisation, environnements de développement, test et production, scénarios de tests.

## 3. Données, sécurité, conformité

### <a id="q-20"></a>Q-20 — Conservation des données

- Priorité : lancement.
- À définir : durée de conservation des positions détaillées, des journaux techniques et d'administration ; sauvegarde et restauration ; export des données personnelles.

### <a id="q-21"></a>Q-21 — Sécurité et conformité

- Priorité : lancement.
- À définir : protection des données personnelles (RGPD), sécurisation des comptes et des sessions, conditions d'utilisation, politique de confidentialité, obligations légales.

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
