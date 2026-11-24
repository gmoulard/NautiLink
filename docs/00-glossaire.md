# NautiLink — Glossaire

Ces termes ont le même sens dans tous les documents du dépôt. Un document qui emploie un autre mot pour la même notion doit être corrigé.

| Terme | Définition |
|-------|------------|
| **Utilisateur** | Personne possédant un compte NautiLink. Il n'existe qu'un seul type de compte utilisateur ([RG-CPT-01](02-regles-metier.md#rg-cpt-01)). |
| **Navigateur** | Rôle d'un utilisateur lorsqu'il conduit une navigation avec l'un de ses bateaux, depuis l'application mobile. |
| **Suiveur** | Rôle d'un utilisateur lorsqu'il consulte les navigations d'un autre utilisateur qui lui a donné un accès. Un même utilisateur peut être navigateur et suiveur. |
| **Propriétaire** | Utilisateur qui a créé un bateau. Il est le seul à pouvoir naviguer avec ce bateau ([RG-CPT-05](02-regles-metier.md#rg-cpt-05)). |
| **Bateau** | Navire décrit par une fiche bateau, rattaché à un seul propriétaire. |
| **Fiche bateau** | Description du bateau : nom, type, longueur, immatriculation, port d'attache, photo, caractéristiques techniques ([RG-BAT-01](02-regles-metier.md#rg-bat-01)). |
| **Application mobile** | L'application Android ou l'application iPhone. Elles ont les mêmes fonctions, sauf le circuit SMS qui n'existe que sur Android ([RG-IOS-02](02-regles-metier.md#rg-ios-02)). |
| **Téléphone associé** | Téléphone Android ou iPhone enregistré pour un bateau. Un bateau a au plus un téléphone associé ; un téléphone peut être associé à plusieurs bateaux du même compte. |
| **Navigation** | Période entre le démarrage et la fin d'une sortie en mer, effectuée avec un bateau et un téléphone associé. États : *en cours*, *terminée*, *dans la corbeille*. |
| **Position** | Coordonnées GPS horodatées à l'instant de leur acquisition par le téléphone. |
| **Position automatique** | Position acquise et transmise à la fréquence de la navigation. |
| **Position manuelle** | Position acquise et transmise à la demande du navigateur (« Envoyer information position »). |
| **Fréquence** | Intervalle entre deux positions automatiques : 3, 4, 5, 10, 15, 30 minutes ou 1 heure. |
| **Journal de bord** | Liste chronologique des événements d'une navigation. |
| **Événement** | Entrée du journal de bord : début, position, note, photo, note vocale, alerte SOS, fin, ajout complémentaire. |
| **Note vocale** | Enregistrement audio conservé sur le serveur, accompagné de sa transcription texte ([D-07](07-decisions.md#d-07)). |
| **Alerte SOS** | Alerte de détresse déclenchée depuis l'application mobile : SMS aux contacts SOS (Android seulement), enregistrement sur le serveur, e-mail aux suiveurs. |
| **Contact** | Personne de la liste unique du navigateur : nom, téléphone et/ou e-mail, cases « Suiveur » et « Contact SOS », cochées par défaut ([RG-CTC-01](02-regles-metier.md#rg-ctc-01)). |
| **Contact SOS** | Contact dont la case « Contact SOS » est cochée ; reçoit les SMS SOS. Il a forcément un numéro de téléphone. |
| **Destinataire SMS** | Suiveur d'une navigation ayant renseigné un numéro de téléphone ; reçoit les SMS ordinaires de cette navigation ([RG-SMS-01](02-regles-metier.md#rg-sms-01)). |
| **SMS ordinaire** | Tout SMS ou MMS autre qu'un SMS SOS : début, positions, notes, photos, notes vocales, fin. |
| **Invitation** | Message (e-mail ou SMS) contenant un lien qui mène à la connexion ou à la création d'un compte, puis donne un accès. |
| **Accès** | Droit d'un suiveur sur les navigations d'un navigateur. Périmètre *navigation* (une seule) ou *navigateur* (toutes, présentes et futures, tous bateaux confondus). |
| **Paramètres généraux** | Réglages par défaut du navigateur (SMS, fréquence), synchronisés entre les applications mobiles et le Web. |
| **Paramètres de navigation** | Copie des paramètres généraux modifiable au démarrage, valable pour cette seule navigation. |
| **Circuit Internet** | Échanges entre les applications et le serveur par API HTTPS. |
| **Circuit SMS** | Envoi de SMS et MMS par la carte SIM du téléphone Android, sans prestataire externe. N'existe pas sur iPhone. |
| **Quota gratuit** | 24 heures de navigation cumulées sur les 7 derniers jours glissants, par compte. |
| **Abonnement** | Offre payante qui lève la limite du quota gratuit, par compte. |
| **Corbeille** | État d'une navigation supprimée, restaurable pendant 30 jours. |
| **Administrateur** | Personne de l'équipe NautiLink qui utilise l'espace administrateur, distinct de l'espace utilisateur. |
