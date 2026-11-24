# NautiLink — Modèle économique

Statut : principes validés, formules et tarifs à définir ([Q-17](06-questions-ouvertes.md#q-17)).

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

L'abonnement lève la limite pour le compte (RG-ECO-06). Il se souscrit sur Google Play ou sur le Web ; le serveur tient un seul état d'abonnement par compte (RG-ECO-07).

À définir ([Q-17](06-questions-ouvertes.md#q-17)) : prix, nombre et contenu des formules, limites éventuelles, périodicité, moyens de paiement, renouvellement et résiliation, période d'essai, paiements échoués, changement de formule.

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
- Android et le Web affichent le temps consommé, le temps disponible, les prochaines minutes récupérables et l'état de l'abonnement (RG-ECO-09 ; présentation : [Q-18](06-questions-ouvertes.md#q-18)).
- Le temps de suivi n'est jamais compté (RG-ECO-03).
