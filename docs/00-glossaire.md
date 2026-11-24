# NautiLink — Glossaire

Ces termes ont le même sens dans tous les documents du dépôt. Un document qui emploie un autre mot pour la même notion doit être corrigé.

| Terme | Définition |
|-------|------------|
| **Utilisateur** | Personne possédant un compte NautiLink. Il n'existe qu'un seul type de compte utilisateur ([RG-CPT-01](02-regles-metier.md#rg-cpt-01)). |
| **Navigateur** | Rôle d'un utilisateur lorsqu'il conduit une navigation avec l'un de ses bateaux, depuis l'application Android. |
| **Suiveur** | Rôle d'un utilisateur lorsqu'il consulte les navigations d'un autre utilisateur qui lui a donné un accès. Un même utilisateur peut être navigateur et suiveur. |
| **Propriétaire** | Utilisateur qui a créé un bateau. Il est le seul à pouvoir naviguer avec ce bateau ([RG-CPT-05](02-regles-metier.md#rg-cpt-05)). |
| **Bateau** | Navire décrit par une fiche bateau, rattaché à un seul propriétaire. |
| **Fiche bateau** | Description du bateau : nom, type, longueur, immatriculation, port d'attache, photo, caractéristiques techniques ([RG-BAT-01](02-regles-metier.md#rg-bat-01)). |
| **Téléphone associé** | Téléphone Android enregistré pour un bateau. Un bateau a au plus un téléphone associé ; un téléphone peut être associé à plusieurs bateaux du même compte. |
| **Navigation** | Période entre le démarrage et la fin d'une sortie en mer, effectuée avec un bateau et un téléphone associé. États : *en cours*, *terminée*, *dans la corbeille*. |
| **Position** | Coordonnées GPS horodatées à l'instant de leur acquisition par le téléphone. |
| **Position automatique** | Position acquise et transmise à la fréquence de la navigation. |
| **Position manuelle** | Position acquise et transmise à la demande du navigateur (« Envoyer information position »). |
| **Fréquence** | Intervalle entre deux positions automatiques : 3, 4, 5, 10, 15, 30 minutes ou 1 heure. |
| **Journal de bord** | Liste chronologique des événements d'une navigation. |
| **Événement** | Entrée du journal de bord : début, position, note, photo, note vocale, alerte SOS, fin, ajout complémentaire. |
| **Note vocale** | Enregistrement audio conservé sur le serveur, accompagné de sa transcription texte ([D-07](07-decisions.md#d-07)). |
| **Alerte SOS** | Alerte de détresse déclenchée depuis Android : SMS aux contacts SOS, enregistrement sur le serveur, e-mail aux suiveurs. |
| **Contact SOS** | Destinataire des SMS SOS : nom, numéro de téléphone, e-mail facultatif. Défini par le navigateur. |
| **Destinataire SMS** | Suiveur d'une navigation ayant renseigné un numéro de téléphone ; reçoit les SMS ordinaires de cette navigation ([RG-SMS-01](02-regles-metier.md#rg-sms-01)). |
| **SMS ordinaire** | Tout SMS ou MMS autre qu'un SMS SOS : début, positions, notes, photos, notes vocales, fin. |
| **Invitation** | Message (e-mail ou SMS) contenant un lien qui mène à la connexion ou à la création d'un compte, puis donne un accès. |
| **Accès** | Droit d'un suiveur sur les navigations d'un navigateur. Périmètre *navigation* (une seule) ou *navigateur* (toutes, présentes et futures, tous bateaux confondus). |
| **Paramètres généraux** | Réglages par défaut du navigateur (SMS, fréquence, contacts SOS), synchronisés entre Android et le Web. |
| **Paramètres de navigation** | Copie des paramètres généraux modifiable au démarrage, valable pour cette seule navigation. |
| **Circuit Internet** | Échanges entre les applications et le serveur par API HTTPS. |
| **Circuit SMS** | Envoi de SMS et MMS par la carte SIM du téléphone Android, sans prestataire externe. |
| **Quota gratuit** | 24 heures de navigation cumulées sur les 7 derniers jours glissants, par compte. |
| **Abonnement** | Offre payante qui lève la limite du quota gratuit, par compte. |
| **Corbeille** | État d'une navigation supprimée, restaurable pendant 30 jours. |
| **Administrateur** | Personne de l'équipe NautiLink qui utilise l'espace administrateur, distinct de l'espace utilisateur. |
