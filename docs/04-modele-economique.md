# NautiLink — Modèle économique

Statut : validé ; une seule formule, 15 € pour 10 ans, sans renouvellement automatique ni essai ([D-94](07-decisions.md#d-94)).

Les règles opposables sont RG-ECO-01 à RG-ECO-09 dans [02-regles-metier.md](02-regles-metier.md). Ce document en explique l'intention.

## 1. Principe : freemium

- Chacun peut essayer et utiliser NautiLink gratuitement.
- Seul le temps passé à **naviguer** au-delà du quota gratuit est payant.
- **Suivre** les autres et **consulter son historique** sont toujours gratuits.

## 2. Offre gratuite

Chaque compte dispose de **24 heures de navigation cumulées sur les 7 derniers jours glissants**, tous bateaux confondus (RG-ECO-01).

Le quota est glissant : chaque minute consommée redevient disponible 7 jours plus tard. Il n'y a pas de remise à zéro hebdomadaire (RG-ECO-02).

Exemple : un navigateur navigue 10 h le lundi à partir de 9 h et 14 h le mercredi. Son quota est épuisé le mercredi soir. Les minutes du lundi redeviennent disponibles le lundi suivant à partir de 9 h, minute par minute.

## 3. Quota épuisé

- **Avant de démarrer** : le démarrage est refusé ; le navigateur peut s'abonner ou attendre que des minutes reviennent (RG-ECO-04).
- **Pendant une navigation** : elle continue au plus 24 heures, puis elle est clôturée automatiquement, sauf abonnement souscrit entre-temps (RG-ECO-05).
- **Dans tous les cas** : le SOS reste disponible (RG-SOS-03) et les navigations enregistrées restent consultables.

## 4. Abonnement

L'abonnement lève la limite pour le compte (RG-ECO-06). Il se souscrit sur Google Play, sur l'App Store ou sur le Web ; le serveur tient un seul état d'abonnement par compte (RG-ECO-07).

Une seule formule, sans autre contenu que la navigation sans limite : 15 € payés une fois, pour 10 ans, sans renouvellement automatique ; pas de période d'essai, le quota gratuit en tient lieu (RG-ECO-06). Paiement par carte bancaire avec Stripe sur le Web, achat unique intégré sur Google Play et l'App Store ; un paiement échoué laisse le compte en version gratuite (RG-ECO-11).

## 5. Toujours gratuit

| Fonctionnalité | Offre gratuite | Abonnement |
|----------------|----------------|------------|
| Naviguer | 24 h sur 7 jours glissants | Sans cette limite |
| Suivre un autre navigateur | Gratuit, sans limite | Gratuit, sans limite |
| Consulter ses navigations terminées | Gratuit | Gratuit |
| Positions GPS et traces | Gratuit | Gratuit |
| Notes, notes vocales et photos | Gratuit | Gratuit |
| Journaux de bord | Gratuit | Gratuit |
| Alertes SOS archivées | Gratuit | Gratuit |
| Déclencher un SOS | Toujours possible | Toujours possible |

L'abonnement ne conditionne jamais l'accès aux données déjà enregistrées (RG-ECO-08).

## 6. Exigences pour l'application

- Le quota est calculé par le serveur, pour être identique sur tous les appareils (RG-ECO-09).
- Les applications mobiles et le Web affichent le temps consommé, le temps disponible, les prochaines minutes récupérables et l'état de l'abonnement sur un écran « Quota et abonnement » et en résumé sur l'accueil (RG-ECO-09).
- Le temps de suivi n'est jamais compté (RG-ECO-03).
