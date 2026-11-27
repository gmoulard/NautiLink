# NautiLink — Glossaire

Ces termes ont le même sens dans tous les documents du dépôt. Un document qui emploie un autre mot pour la même notion doit être corrigé.

| Terme | Définition |
|-------|------------|
| **Utilisateur** | Personne possédant un compte NautiLink. Il n'existe qu'un seul type de compte utilisateur ([RG-CPT-01](02-regles-metier.md#rg-cpt-01)). |
| **Navigateur** | Rôle d'un utilisateur lorsqu'il conduit une navigation avec l'un de ses bateaux, depuis l'application mobile ou l'Application web ([RG-WEB-01](02-regles-metier.md#rg-web-01)). |
| **Ami** | Personne de la liste de contacts du navigateur ([RG-CTC-01](02-regles-metier.md#rg-ctc-01)) : il reçoit les messages des navigations et les alertes SOS par les canaux cochés au démarrage, et suit les navigations quand il a accepté l'invitation, avec son compte. Un même utilisateur peut être navigateur et ami d'un autre navigateur. Remplace les anciens termes *suiveur* et *contact SOS* ([D-176](07-decisions.md#d-176)). |
| **Propriétaire** | Utilisateur qui a créé un bateau. Il est le seul à pouvoir naviguer avec ce bateau ([RG-CPT-05](02-regles-metier.md#rg-cpt-05)). |
| **Bateau** | Navire décrit par une fiche bateau, rattaché à un seul propriétaire. |
| **Fiche bateau** | Description du bateau : nom, type, longueur, immatriculation, port d'attache, photo, caractéristiques techniques ([RG-BAT-01](02-regles-metier.md#rg-bat-01)). |
| **Application mobile** | L'application Android ou l'application iPhone. Elles ont les mêmes fonctions, sauf le circuit SMS qui n'existe que sur Android ([RG-IOS-02](02-regles-metier.md#rg-ios-02)). |
| **Application web** | L'application NautiLink ouverte dans un navigateur Internet : tableau de bord, pages des navigations, gestion du compte et toutes les fonctions de l'application mobile, sans SMS ([RG-WEB-01](02-regles-metier.md#rg-web-01)). Anciennement « plateforme Web » ([D-147](07-decisions.md#d-147)). |
| **Téléphone associé** | Téléphone Android ou iPhone enregistré pour un bateau. Un bateau a au plus un téléphone associé ; un téléphone peut être associé à plusieurs bateaux du même compte. |
| **Navigation** | Période entre le démarrage et la fin d'une sortie en mer, effectuée avec un bateau et un téléphone associé, que d'autres téléphones du compte peuvent rejoindre ([RG-NAV-39](02-regles-metier.md#rg-nav-39)). États : *en cours*, *terminée*, *dans la corbeille*. |
| **Log de nav** | Page d'accueil de l'Application web : navigations de chaque bateau, une ligne par navigation ([D-156](07-decisions.md#d-156)). |
| **Position** | Coordonnées GPS horodatées à l'instant de leur acquisition par le téléphone. |
| **Position automatique** | Position acquise et transmise à la fréquence de la navigation. |
| **Position manuelle** | Position acquise et transmise à la demande du navigateur (« Envoyer position »). |
| **Fréquence** | Intervalle entre deux positions automatiques : 15 minutes, 30 minutes, 1 heure, 2 heures, 3 heures, 6 heures, 12 heures, 1 jour, 2 jours, 10 jours ([RG-NAV-05](02-regles-metier.md#rg-nav-05)). |
| **Journal de bord** | Liste chronologique des événements d'une navigation. |
| **Événement** | Entrée du journal de bord : début, position, note, photo, note vocale, alerte SOS, incident ou avarie, fin, ajout complémentaire. |
| **Incident - avarie** | Événement du journal de bord qui consigne un incident ou une avarie : texte, avec photo et note vocale facultatives ([RG-JRN-11](02-regles-metier.md#rg-jrn-11)). |
| **Chef de bord** | Personne responsable du bateau pendant la navigation, choisie sur l'écran de démarrage, par défaut le navigateur ; texte libre, modifiable ensuite ([RG-NAV-35](02-regles-metier.md#rg-nav-35), [RG-NAV-36](02-regles-metier.md#rg-nav-36)). |
| **Note vocale** | Enregistrement de la voix, conservé sur le serveur et réécoutable, sans transcription ([D-71](07-decisions.md#d-71)). |
| **Alerte SOS** | Alerte de détresse déclenchée depuis l'application mobile ou l'Application web ([RG-WEB-02](02-regles-metier.md#rg-web-02)) : SMS aux amis (Android seulement), enregistrement sur le serveur, e-mail aux amis. |
| **Contact** | Synonyme d'*ami* : personne de la liste unique du navigateur, avec nom, téléphone et/ou e-mail, sans rôle à choisir ([RG-CTC-01](02-regles-metier.md#rg-ctc-01)). |
| **Destinataire SMS** | Ami coché « SMS » pour une navigation et qui a un numéro de téléphone ; reçoit les SMS ordinaires de cette navigation ([RG-SMS-01](02-regles-metier.md#rg-sms-01)). |
| **SMS ordinaire** | Tout SMS ou MMS autre qu'un SMS SOS : début, positions, notes, photos, notes vocales, fin. Sur Android, il s'ouvre prérempli dans l'application SMS et part d'un appui, sauf le SMS de position automatique, qui part automatiquement ([RG-SMS-03](02-regles-metier.md#rg-sms-03)). |
| **Invitation** | Message (e-mail ou SMS) contenant un lien qui mène à la connexion ou à la création d'un compte, puis donne un accès. |
| **Accès** | Droit d'un ami sur les navigations d'un navigateur. Périmètre *navigation* (une seule) ou *navigateur* (toutes, présentes et futures, tous bateaux confondus). |
| **Paramètres généraux** | Réglages par défaut du navigateur (SMS, fréquence), synchronisés entre les applications mobiles et le Web. |
| **Paramètres de navigation** | Copie des paramètres généraux modifiable au démarrage, valable pour cette seule navigation. |
| **Avertissement bêta** | Texte sur la version bêta et la responsabilité, accepté à la création du compte ([RG-CPT-06](02-regles-metier.md#rg-cpt-06), [texte](textes/avertissement-beta.md)). |
| **Circuit Internet** | Échanges entre les applications et le serveur par API HTTPS. |
| **File d'attente** | Envois vers le serveur enregistrés sur le téléphone et pas encore reçus (démarrage, positions, notes, photos, notes vocales, fin, alertes SOS), envoyés dès que la connexion le permet ([RG-GPS-04](02-regles-metier.md#rg-gps-04)). |
| **Circuit SMS** | Envoi de SMS et MMS par la carte SIM du téléphone Android, sans prestataire externe. N'existe pas sur iPhone. |
| **Quota gratuit** | 24 heures de navigation cumulées sur les 7 derniers jours glissants, par compte. |
| **Abonnement** | Offre payante qui lève la limite du quota gratuit, par compte : 15 € payés une fois, pour 10 ans (RG-ECO-06). |
| **Corbeille** | État d'une navigation supprimée, restaurable pendant 30 jours. |
| **Administrateur** | Personne de l'équipe NautiLink qui utilise l'espace administrateur, distinct de l'espace utilisateur. |
| **Suiveur**, **Contact SOS** | Anciens termes, remplacés par *ami* ([D-176](07-decisions.md#d-176)) ; ils restent dans les décisions passées et dans les noms de champs de l'API gardés pour les applications déjà installées. |
