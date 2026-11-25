# NautiLink — Journal des décisions

Chaque arbitrage fonctionnel est tracé ici avec un identifiant `D-nn`, sa date, le problème posé et le choix retenu. Une décision n'est jamais modifiée après coup : une décision qui en remplace une autre reçoit un nouvel identifiant et indique « remplace D-nn ».

Toute décision est reportée dans le même changement dans les règles métier ([02-regles-metier.md](02-regles-metier.md)) et les documents concernés, et la question correspondante est retirée de [06-questions-ouvertes.md](06-questions-ouvertes.md).

## 2026-11-24 — Mise en cohérence des documents initiaux

Les documents d'origine (deux cahiers des charges, règles métier, parcours utilisateur, modèle économique, identité de marque, liste de tâches) se contredisaient sur les points ci-dessous. Arbitrages du porteur du projet, sauf D-25, déduite des parcours existants (à infirmer si besoin).

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-01"></a>D-01 | Type de compte | « Profil unique de type navigateur » d'un côté ; « un seul type de compte, navigateur et suiveur » de l'autre. | Un seul type de compte ; navigateur et suiveur sont des rôles. | RG-CPT-01 |
| <a id="d-02"></a>D-02 | Confirmation du SOS | « Sans confirmation » (cahier fonctionnel, règles métier) contre « demande de confirmation » (cahier des charges, parcours). | Boîte de confirmation avant l'envoi. | RG-SOS-02 |
| <a id="d-03"></a>D-03 | Gestion des contacts SOS | Web seulement (règles métier) contre Web et Android (cahier des charges). | Web et Android, synchronisés par le serveur, copie locale sur Android. | RG-CTC-02, RG-CTC-03 |
| <a id="d-04"></a>D-04 | Périmètre du partage | Par navigation ou par bateau (cahier fonctionnel) contre « toutes les futures navigations du navigateur » (cahier des charges). | Deux périmètres paramétrables : une navigation, ou tout le navigateur. Pas de périmètre par bateau. | RG-PAR-02 |
| <a id="d-05"></a>D-05 | Fréquence des positions | Réglage général stocké sur le serveur contre choix à chaque démarrage. | Valeur par défaut dans les paramètres généraux, modifiable au démarrage pour la navigation seulement. | RG-NAV-05 |
| <a id="d-06"></a>D-06 | Destination | Saisie au démarrage (cahier fonctionnel, règles métier) ; absente de l'écran de démarrage (cahier des charges, parcours). | Facultative, en texte ou sur une carte. | RG-NAV-04 |
| <a id="d-07"></a>D-07 | Note vocale | Dictée transformée en texte (parcours, cahier des charges) contre enregistrement audio (cahier fonctionnel, tâches). | Audio conservé et transcription texte. | RG-JRN-04, RG-SMS-06 |
| <a id="d-08"></a>D-08 | Destinataires des SMS ordinaires | Non défini. | Les suiveurs de la navigation ayant un numéro de téléphone. | RG-SMS-01 |
| <a id="d-09"></a>D-09 | Lien de partage | « Lien de partage » (cahier des charges) contre partage réservé aux comptes. | Un lien de partage est un lien d'invitation ; aucun accès anonyme. | RG-PAR-01, RG-PAR-05 |
| <a id="d-10"></a>D-10 | Invitation | Depuis Android seulement (cahier des charges) contre Web et Android (parcours) ; canal SMS non défini. | Depuis le Web ou Android ; le navigateur choisit le périmètre ; e-mail par le serveur, SMS par la SIM du téléphone. | RG-PAR-03, RG-PAR-04 |
| <a id="d-11"></a>D-11 | Qui navigue avec un bateau | Non défini. | Le propriétaire seul. | RG-CPT-05 |
| <a id="d-12"></a>D-12 | Téléphone et bateaux | « Un seul téléphone par bateau » sans règle pour plusieurs bateaux. | Un téléphone peut servir plusieurs bateaux du compte ; choix du bateau au démarrage, sauf s'il n'y en a qu'un. | RG-BAT-02, RG-NAV-02 |
| <a id="d-13"></a>D-13 | Contenu du SMS SOS | « Toutes les caractéristiques » du bateau, au risque de plusieurs SMS. | Premier SMS avec l'essentiel et le lien Google Maps, second SMS avec le reste de la fiche. | RG-SOS-07, RG-SOS-08 |
| <a id="d-14"></a>D-14 | SOS et suiveurs | Non défini. | Le serveur envoie un e-mail aux suiveurs de la navigation et aux contacts SOS dont l'e-mail est connu. | RG-SOS-06 |
| <a id="d-15"></a>D-15 | Nom d'une navigation | Affiché dans les listes, origine non définie. | Généré automatiquement, modifiable. | RG-NAV-17 |
| <a id="d-16"></a>D-16 | Modification du journal | Seuls les ajouts Web modifiables ; le reste ouvert. | Notes, photos, notes vocales, ajouts : modifiables et supprimables. Début, fin, positions, SOS : figés. | RG-JRN-06, RG-JRN-07 |
| <a id="d-17"></a>D-17 | Suppression d'une navigation | Définitive ou corbeille, à confirmer. | Corbeille 30 jours, navigations terminées seulement. | RG-NAV-20 |
| <a id="d-18"></a>D-18 | Authentification | E-mail, Google, Apple (cahier fonctionnel) ; « à définir » ailleurs. | Les trois, sur le Web et Android. | RG-CPT-02 |
| <a id="d-19"></a>D-19 | Portée du quota | Non défini (un compte peut avoir plusieurs bateaux). | Par compte. | RG-ECO-01 |
| <a id="d-20"></a>D-20 | Quota épuisé en cours de navigation | Non défini. | La navigation continue au plus 24 heures après l'épuisement, puis est clôturée automatiquement. | RG-ECO-05, RG-NAV-15 |
| <a id="d-21"></a>D-21 | Canal de souscription | Non défini. | Google Play et Web, un seul état d'abonnement par compte. | RG-ECO-07 |
| <a id="d-22"></a>D-22 | Périmètre admin au lancement | Versions multiples du Web dans le périmètre admin (cahier fonctionnel) et en évolution future (tâches). | Évolution future. | RG-ADM-05 |
| <a id="d-23"></a>D-23 | Accueil Web | Liste des navigations passées (cahier fonctionnel) contre tableau de bord (cahier des charges). | Tableau de bord : navigations en cours puis historique, filtres navigateur / suiveur, prévisualisation. | [01 §6.1](01-cahier-des-charges.md#61-tableau-de-bord) |
| <a id="d-24"></a>D-24 | Organisation du dépôt | Deux cahiers des charges, noms de fichiers incohérents, liens cassés. | Un fichier par domaine, numéroté ; identifiants de règles, décisions et questions ; `CLAUDE.md`. | — |
| <a id="d-25"></a>D-25 | Création d'une navigation | « Automatique, manuelle ou les deux » ouvert dans les tâches, alors que tous les parcours décrivent un démarrage manuel. | Manuelle uniquement. | RG-NAV-01 |

## 2026-11-24 — Questions bloquantes tranchées

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-26"></a>D-26 | SMS SOS désactivable | Ancienne question 03 : l'interrupteur général ou les préférences peuvent-ils bloquer les SMS SOS ? | Jamais ; avertissement au démarrage s'il n'y a aucun contact SOS. | RG-SOS-14, RG-SMS-02 |
| <a id="d-27"></a>D-27 | SOS hors navigation | Ancienne question 02 : bouton SOS hors navigation ? | Oui, sur l'écran d'accueil, rattaché au bateau du téléphone ; e-mail aux suiveurs de périmètre *navigateur*. | RG-SOS-01, RG-SOS-15 |
| <a id="d-28"></a>D-28 | Invitation par téléphone depuis le Web | Ancienne question 05 : le Web ne peut pas envoyer de SMS. | Le Web affiche le lien ; le navigateur le transmet lui-même. | RG-PAR-04 |
| <a id="d-29"></a>D-29 | Droits des suiveurs | Ancienne question 07 : fiche bateau, export, autres suiveurs, contacts SOS ? | Les quatre, en lecture seule. | RG-PAR-08, RG-NAV-19 |
| <a id="d-30"></a>D-30 | Suiveurs et contacts SOS | Deux listes séparées jusqu'ici. | Une seule liste de contacts ; chaque contact est par défaut suiveur et contact SOS, décochable séparément. | RG-CTC-01, RG-CTC-04, RG-CTC-05 |
| <a id="d-31"></a>D-31 | Application iPhone | iOS exclu du périmètre initial. | Application iPhone ajoutée, pour le navigateur et le suiveur ; l'iPhone ne peut envoyer aucun SMS. | RG-IOS-01, RG-IOS-02, RG-IOS-05, RG-IOS-06 |
| <a id="d-32"></a>D-32 | SOS depuis un iPhone | Sans SMS, comment prévenir les contacts SOS ? | Par Internet seulement : alerte au serveur, e-mails, notifications push ; avertissement clair au démarrage. Pas de prestataire SMS. | RG-IOS-03, RG-IOS-04 |
| <a id="d-33"></a>D-33 | Calendrier de l'iPhone | — | Construite après l'application Android et le Web. | [01 §3](01-cahier-des-charges.md#3-périmètre) |
| <a id="d-34"></a>D-34 | Abonnement sur iPhone | — | Achat intégré de l'App Store, reconnu sur tous les supports. | RG-ECO-07, RG-IOS-07 |

## 2026-11-24 — Décisions du lot 1 (navigations et partage)

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-35"></a>D-35 | Lieux et distance | Ancienne question 01. | Géocodage inverse de la première et de la dernière position, sinon coordonnées ; distance = somme des segments. | RG-NAV-16 |
| <a id="d-36"></a>D-36 | Refus des SMS par un suiveur | Ancienne question 04. | Oui, option « Recevoir les SMS » activée par défaut. | RG-SMS-01 |
| <a id="d-37"></a>D-37 | Validité d'une invitation | Ancienne question 06. | Sans expiration, annulable par le navigateur. | RG-PAR-05 |
| <a id="d-38"></a>D-38 | Informations modifiables | Ancienne question 24. | Nom, destination, bateau, heures de début et de fin. | RG-NAV-17, RG-NAV-22 |
| <a id="d-39"></a>D-39 | Avant la clôture automatique | Ancienne question 32. | Avertissement à l'épuisement et 1 h avant, à l'écran et par notification. | RG-ECO-05 |
| <a id="d-40"></a>D-40 | Photos | Ancienne question 15. | 20 photos par navigation au plus, environ 1 Mo chacune. | RG-JRN-08 |

## 2026-11-24 — Décisions du lot 2 (notifications, quota, abonnement)

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-41"></a>D-41 | E-mails | Ancienne question 16. | En plus de l'invitation, de l'accès et du SOS : e-mail de début de navigation aux suiveurs, désinscription possible. | RG-NOT-02 |
| <a id="d-42"></a>D-42 | Affichage du quota | Ancienne question 18. | Écran « Quota et abonnement » et résumé sur l'accueil. | RG-ECO-09 |
| <a id="d-43"></a>D-43 | Formule d'abonnement | Ancienne question 17, en partie. | Une seule formule, mensuelle ou annuelle, sans période d'essai. Formule remplacée par [D-94](#d-94) : 15 € pour 10 ans. | RG-ECO-06 |
| <a id="d-44"></a>D-44 | Notifications push iPhone | Ancienne question 33. | SOS, début, fin, nouvelle photo, position en retard ; chaque type désactivable sauf le SOS. | RG-IOS-06 |

## 2026-11-24 — Décisions des lots 3, 4 et 5 (administration, données, SMS, GPS, notes vocales)

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-45"></a>D-45 | Conformité | Ancienne question 21. | RGPD de base : conditions et politique de confidentialité relues par un juriste, sessions qui expirent, obligations listées avec leurs sources. | RG-DON-03 |
| <a id="d-46"></a>D-46 | Conservation | Ancienne question 20. | Positions comme la navigation, journaux techniques 1 an, d'administration 3 ans, sauvegarde quotidienne 30 jours, export JSON et GPX. | RG-DON-02 |
| <a id="d-47"></a>D-47 | Administrateurs | Ancienne question 19. | Un seul profil, qui peut tout modifier, SOS et positions compris ; seul le navigateur ne les modifie pas. | RG-ADM-03 |
| <a id="d-48"></a>D-48 | Voie d'envoi des SMS sur Android | Q-12 (étude TODO-2.1). | Play Store ; SMS SOS automatiques au titre de l'exception « urgence » (à vérifier) ; SMS ordinaires et invitations préremplis. | RG-SMS-03, RG-SOS-16 |
| <a id="d-49"></a>D-49 | MMS en échec | Q-13, en partie. | SMS avec le lien vers la photo hébergée. | RG-SMS-05 |
| <a id="d-50"></a>D-50 | Nouvelles tentatives | Ancienne question 11. | SOS : chaque minute jusqu'à réussite ou arrêt ; ordinaires : 3 essais puis « Réessayer ». | RG-SMS-07 |
| <a id="d-51"></a>D-51 | Reprise après redémarrage | Ancienne question 08. | Reprise au lancement suivant de l'application, avec une notification après redémarrage. | RG-NAV-12 |
| <a id="d-52"></a>D-52 | Optimisation de la batterie | Étude TODO-2.2. | Demande d'exclusion et aide propre à la marque au premier démarrage d'une navigation. | RG-GPS-05 |
| <a id="d-53"></a>D-53 | Notes vocales | Ancienne question 14. | AAC `.m4a`, 1 minute au plus, transcription par le moteur du téléphone. | RG-JRN-04 |
| <a id="d-54"></a>D-54 | Localisation sur iPhone | Étude TODO-10.2. | Autorisation « Pendant l'utilisation ». | RG-IOS-08 |

## 2026-11-24 — Copie au navigateur

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-55"></a>D-55 | Copie au navigateur | Demande de l'utilisateur. | Tout SMS envoyé par l'application et tout e-mail de notification part aussi en copie au navigateur (numéro de son profil, adresse de son compte), sans désactivation possible. | RG-SMS-08, RG-NOT-03 |

## 2026-11-24 — Avertissement bêta

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-56"></a>D-56 | Avertissement bêta et responsabilité | Demande de l'utilisateur : signaler la bêta et limiter la responsabilité en termes valables en droit français. | Texte dans `docs/textes/avertissement-beta.md` ; accepté à la création du compte, rappelé avant le premier démarrage d'une navigation sur chaque téléphone, mention « Version bêta » visible. Relecture par un juriste avant la mise en ligne. | RG-CPT-06, RG-CPT-07, RG-NAV-23 |

## 2026-11-24 — Prototype de démonstration et choix techniques

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-57"></a>D-57 | Prototype de démonstration | Demande de l'utilisateur : générer les applications et les relier au site. | D'abord un prototype de démonstration, avec des données d'exemple et sans serveur : application Web de démonstration publiée sur le site, APK Android de démonstration téléchargeable depuis le site. | [TODO-3.6](TODO.md) |
| <a id="d-58"></a>D-58 | Technologie des applications mobiles | Partie de Q-22. | Flutter : un seul code pour Android et iPhone (et la démonstration Web). | [Q-22](06-questions-ouvertes.md#q-22) |
| <a id="d-59"></a>D-59 | Serveur | Partie de Q-22. | Serveur maison (API et hébergement à choisir), pas de service tout fait. | [Q-22](06-questions-ouvertes.md#q-22) |
| <a id="d-60"></a>D-60 | Application iPhone | Pas encore de compte développeur Apple. | Le code iPhone suit le même code Flutter ; le site affiche « iPhone : bientôt » jusqu'à l'ouverture du compte. | RG-IOS-01 |

## 2026-11-24 — Distribution des démonstrations hors des stores

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-61"></a>D-61 | Téléchargement des démonstrations | Demande de l'utilisateur : télécharger les applications de démonstration depuis le site, sans publication dans les stores. | Tout passe par le site GitHub Pages : APK Android (signature de débogage), démonstration Web installable sur l'écran d'accueil, IPA iPhone non signé à installer avec AltStore ou Sideloadly, empreintes SHA-256. Remplace l'affichage « iPhone : bientôt » de D-60 pour la démonstration. | [TODO-3.6](TODO.md) |

## 2026-11-24 — Hébergement du serveur

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-62"></a>D-62 | Hébergement du serveur | Ancienne question 37 : héberger NautiLink sur pi-appliance (demande de l'utilisateur du 2026-11-24). Complète D-59. | Le serveur central lui-même (API, plateforme Web, espace administrateur sous un chemin réservé) tourne sur le Raspberry Pi 4 de `vdl.moulard.org`, sous pi-appliance, en un seul exemplaire ; pas de serveur installé chez les plaisanciers. Écrit en Go. Adresse publique `https://nautilink.moulard.org`, redirigée par Traefik vers `https://vdl.moulard.org/nautilink/`. Installé par « Docker Compose libre » (pas dans le catalogue public) ; base dans le PostgreSQL partagé de pi-appliance ; e-mails par le relais d'envoi de pi-appliance ; abonnement et quota inchangés (RG-ECO). Risque accepté pendant la bêta : une coupure du Pi ou de la box arrête le circuit Internet (e-mails SOS compris ; les SMS partent quand même, RG-COM-01) ; passage chez un hébergeur avant l'ouverture au grand public. Squelette déployable à écrire tout de suite (TODO-3.7). Fonctions qui manquent à pi-appliance : publication d'un Docker Compose libre sous un chemin, PostgreSQL partagé, relais d'e-mails, domaine de redirection (TODO-2.72 à TODO-2.74 et TODO-3.18 de pi-appliance). | Cahier des charges §4 ; [Q-22](06-questions-ouvertes.md#q-22) en partie |

## 2026-11-24 — Demandes de la boîte de réception (application mobile)

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-63"></a>D-63 | Fréquences d'envoi | Demande de l'utilisateur : fréquences de 15 minutes à 10 jours. | 15 minutes, 30 minutes, 1 heure, 2 heures, 3 heures, 6 heures, 12 heures, 1 jour, 2 jours, 10 jours. Remplace les valeurs de D-05. | RG-NAV-05 |
| <a id="d-64"></a>D-64 | Chronomètre du dernier envoi | Demande de l'utilisateur. | Tout envoi réussi (position, note, photo, note vocale) remet à zéro le chronomètre du dernier envoi. | RG-NAV-10 |
| <a id="d-65"></a>D-65 | Affichage des envois | Demande de l'utilisateur. | Chaque résultat d'envoi s'affiche dans une fenêtre avec « OK », fermée seule au bout d'une minute. | RG-COM-03 |
| <a id="d-66"></a>D-66 | Navigation immobile | Demande de l'utilisateur. | Moins de 20 mètres de déplacement en 2 heures : l'application propose de terminer la navigation. | RG-NAV-24 |
| <a id="d-67"></a>D-67 | Accès au quota et à l'abonnement | Demande de l'utilisateur. | Lien « Version gratuite - abonnement » sur l'accueil vers « Quota et abonnement », puis lien vers la page d'information sur l'abonnement du site. | RG-ECO-10 |

## 2026-11-24 — Sponsor

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-68"></a>D-68 | Sponsor SRT | Demande de l'utilisateur, qui a fourni le guidon de la SRT. | NautiLink est présentée comme sponsorisée par la SRT (srtoulon.fr) : bandeau avec le guidon sur toutes les pages du site et en bas de l'accueil de l'application. Le guidon est un logo tiers, utilisé à la demande de l'utilisateur. | [05-identite-marque.md §13](05-identite-marque.md) |

## 2026-11-24 — Design du site

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-69"></a>D-69 | Design du site | Choix parmi la planche météo (TODO-3.9). | Variante 8 « Radar de pluie » : fond ciel, échos radar vert-jaune-rouge, titres Space Grotesk, IBM Plex Mono pour les petites mentions, bleu d'action `#0E6BA8`. Appliquée au site seulement ; l'application garde son style pour l'instant. | [05-identite-marque.md §14](05-identite-marque.md) |

## 2026-11-24 — Design de l'application

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-70"></a>D-70 | Design de l'application | Demande de l'utilisateur après les maquettes. | Le design « Radar de pluie » (D-69) s'applique aussi à l'application : thème clair et sombre, échos radar, Space Grotesk et IBM Plex Mono intégrées (licence OFL, disponibles hors connexion). | [05-identite-marque.md §14](05-identite-marque.md) |

## 2026-11-25 — Remarques de l'utilisateur après essai (boîte de réception)

| Id | Sujet | Question | Décision | Règles |
|----|-------|----------|----------|--------|
| <a id="d-71"></a>D-71 | Note vocale | Le vocal doit être un enregistrement de la voix, pas une transcription. | Enregistrement seul, sans transcription ; le SMS donne un lien d'écoute sur la plateforme Web. Remplace D-07 et la partie transcription de D-53. | RG-JRN-04, RG-SMS-06 |
| <a id="d-72"></a>D-72 | Personnes alertées au démarrage | Liste des personnes alertées, cochées, et ajout possible. | Liste cochée au démarrage ; une personne décochée n'est pas alertée pendant cette navigation ; ajout d'un contact permanent par une page supplémentaire. | RG-NAV-25, RG-NAV-26 |
| <a id="d-73"></a>D-73 | Après « Terminer la navigation » | Arriver sur la page détaillée de la navigation. | La page détaillée de la navigation s'ouvre sur la plateforme Web. | RG-NAV-13 |
| <a id="d-74"></a>D-74 | Batterie | Économiser la batterie au maximum, ne pas interroger le GPS entre deux positions. | GPS allumé seulement pendant l'acquisition d'une position. | RG-GPS-06 |
| <a id="d-75"></a>D-75 | Personnes à bord | Demander le nombre de personnes à bord, à inclure dans le SOS. | Demandé au démarrage, inclus dans le SMS SOS. | RG-NAV-27, RG-SOS-07 |
| <a id="d-76"></a>D-76 | Problème rencontré | Pouvoir ajouter un texte au message SOS. | Champ facultatif « Problème rencontré » dans la confirmation du SOS, repris dans le SMS. | RG-SOS-02, RG-SOS-07 |
| <a id="d-77"></a>D-77 | Journal sur le Web | Consulter notes, photos et vocal ; nom des lieux pour les positions. | Lecture des notes, photos en grand, écoute des notes vocales ; nom du lieu à côté de chaque position. | RG-JRN-09, RG-JRN-10 |
| <a id="d-78"></a>D-78 | Météo | Mémoriser la météo, affichable sur le Web. | Relevé automatique au début et à la fin de la navigation, affiché sur la page de la navigation. | RG-NAV-28 |
| <a id="d-79"></a>D-79 | Carte marine | Intégrer OpenSeaMap et les données gratuites du SHOM. | Fond OpenStreetMap et balisage OpenSeaMap sur la carte de la page d'une navigation ; données du SHOM à étudier (Q-23, priorité lancement). | RG-NAV-29 |

## 2026-11-25 — Autorisations Android (TODO-2.3)

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-80"></a>D-80 | Autorisations Android | Version minimale d'Android, moment des demandes d'autorisations, refus de la localisation précise (ancienne question 31, TODO-2.3). | Android 8.0 (API 26) au minimum ; chaque autorisation demandée au moment où elle sert et redemandée chaque fois que l'application en a besoin ; localisation refusée : navigation sans positions. | RG-AND-01, RG-AND-02, RG-AND-03 |
| <a id="d-81"></a>D-81 | Refus des SMS et réveil du téléphone | Comportement si l'envoi de SMS est refusé ; réveil entre deux positions sans alarme exacte (ancienne question 31, TODO-2.3). | SMS refusé : SOS par Internet plus SMS SOS prérempli ; réveil par une minuterie du service de localisation en continu. | RG-AND-04, RG-AND-05 |

## 2026-11-25 — Réponses aux questions ouvertes

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-82"></a>D-82 | SMS de positions automatiques | Un SMS prérempli demanderait un appui toutes les N minutes, et l'application ne voit pas s'il est parti (ancienne question 36, TODO-1.21). | Les SMS de positions automatiques partent automatiquement (permission d'envoi de SMS), sans appui du navigateur ; risque accepté que Google Play refuse cette permission en dehors de l'exception « urgence ». Nouvelles tentatives limitées aux SMS envoyés automatiquement (SOS et positions automatiques). Les autres SMS ordinaires restent préremplis (D-48). | RG-SMS-03, RG-SMS-07, RG-SMS-08, RG-SOS-16 |
| <a id="d-83"></a>D-83 | Changer les heures d'une navigation | Effet sur le quota et sur les positions hors de la nouvelle plage (ancienne question 34, TODO-1.19). | Le quota reste calculé sur les heures réellement enregistrées par le téléphone ; les positions et événements hors de la nouvelle plage sont gardés, mais masqués du tracé. | RG-NAV-22, RG-ECO-02 |
| <a id="d-84"></a>D-84 | Position en retard | Seuil de la notification push « position en retard » (ancienne question 35, TODO-1.20). | En retard quand aucune position n'a été reçue pendant deux fois la fréquence de la navigation ; une seule notification jusqu'à la position suivante. | RG-IOS-06 |
| <a id="d-85"></a>D-85 | Proposition de fin après « Continuer » | Quand reproposer la fin d'une navigation immobile (ancienne question 38). | Après 2 nouvelles heures sans éloignement de plus de 20 mètres. | RG-NAV-24 |
| <a id="d-86"></a>D-86 | Fichiers, notifications push, sauvegardes | Choix techniques restés ouverts dans Q-22 (TODO-3.1). | Photos et notes vocales stockées dans PostgreSQL. Notifications push : APNs pour l'iPhone et Firebase Cloud Messaging (FCM) pour Android. Sauvegardes : celles de pi-appliance, chaque nuit, gardées 30 jours ; couverture de la base et essai de restauration à vérifier. Hébergeur après la bêta décidé plus tard. | RG-DON-02, RG-IOS-06 |
| <a id="d-87"></a>D-87 | Nom NautiLink | Garder le nom malgré le quasi-homonyme Nauti-Link (Q-26, TODO-8.2). | Nom NautiLink gardé, sous réserve de la consultation des bases de marques INPI, EUIPO et OMPI et d'un avis juridique ; domaines et comptes libres réservés ensuite. | aucune |
| <a id="d-88"></a>D-88 | Service météo | Service qui fournit la météo relevée au début et à la fin d'une navigation (Q-39). | API de Météo-France ; conditions d'accès (clé, quotas) à vérifier. | RG-NAV-28 |
| <a id="d-89"></a>D-89 | Appareil photo, SIM, version d'iOS | Derniers points des autorisations (ancienne question 31, TODO-2.3). | « Photo » ouvre l'appareil photo du téléphone, sans autorisation CAMERA ; sur un téléphone à deux SIM, les SMS partent par la SIM choisie pour les SMS dans les réglages du téléphone ; version minimale d'iOS : celle par défaut de Flutter 3.47.9. | RG-AND-06, RG-AND-07, RG-IOS-09 |
| <a id="d-90"></a>D-90 | Langues | Langues proposées, choix de la langue, langue des messages envoyés (Q-27, TODO-9.2). | Français et anglais au lancement ; langue du téléphone par défaut, modifiable dans les paramètres ; SMS, e-mails et journal envoyés aux suiveurs et aux contacts SOS dans la langue du navigateur. | RG-CPT-03, RG-PRM-03, RG-PRM-04 |
| <a id="d-91"></a>D-91 | Positions automatiques sans SMS | Sort des SMS de positions automatiques si la permission d'envoi de SMS est refusée par Google Play ou par le navigateur (ancienne question 40, TODO-1.26). | Positions automatiques envoyées seulement au serveur, sans SMS ; l'écran de démarrage le dit. | RG-SMS-03 |
| <a id="d-92"></a>D-92 | Notifications push sur Android | Notifications reçues par le suiveur sur Android, FCM étant retenu (D-86, ancienne question 41, TODO-1.27). | Les mêmes que sur iPhone (RG-IOS-06), chaque type désactivable sauf le SOS. | RG-AND-08, RG-NOT-02 |
| <a id="d-93"></a>D-93 | Langue par défaut sur le Web | Pas de téléphone pour choisir la langue sur la plateforme Web (Q-27). | Langue du navigateur Internet par défaut, modifiable dans les paramètres. | RG-PRM-03 |
| <a id="d-94"></a>D-94 | Prix et paiement de l'abonnement | Prix, moyens de paiement sur le Web, renouvellement, résiliation, paiements échoués (ancienne question 17, TODO-1.14). | Remplace la formule mensuelle ou annuelle de D-43 : 15 € payés une seule fois, pour 10 ans, sans renouvellement automatique ; retour à la version gratuite à la fin. Paiement Web par carte bancaire avec Stripe ; achat unique intégré sur Google Play et l'App Store. Paiement échoué : pas d'abonnement, le compte reste en version gratuite. | RG-ECO-06, RG-ECO-11, RG-IOS-07 |
| <a id="d-95"></a>D-95 | Accessibilité | Règles d'accessibilité des écrans (Q-30). | WCAG 2.2 niveau AA sur l'application mobile et la plateforme Web. | RG-PRM-05 |
| <a id="d-96"></a>D-96 | Architecture technique | Validation du document d'architecture et de ses propositions (Q-22, TODO-3.1). | [08-architecture.md](08-architecture.md) validé : après la bêta, serveur virtuel dans l'Union européenne avec la même image Docker et un PostgreSQL dédié (hébergeur et date à choisir) ; e-mails par le relais de l'hébergeur avec SPF, DKIM et DMARC ; géocodage inverse par Nominatim (OpenStreetMap), appelé par le serveur avec un cache. | RG-NAV-16, RG-JRN-10 |
| <a id="d-97"></a>D-97 | Thème sombre | Couleurs du thème sombre (ancienne question 25, TODO-3.3). | Couleurs proposées dans les maquettes validées : fond `#08172A`, écrans `#0F2438`, surfaces `#15314D`, texte `#E3EEF7`, actions `#5AAEE6`, SOS `#E35D5D`. Le bandeau du sponsor SRT prend la couleur de fond de l'application, en clair comme en sombre. | aucune |
| <a id="d-98"></a>D-98 | Logo | Validation du logo et de son repère GPS orange absent de la palette (ancienne question 25, TODO-8.1). | Logo validé tel quel ; l'orange `#F89D29` entre dans la palette, réservé au repère GPS du logo. Restent à produire : fichiers vectoriels, icônes Android et iPhone, déclinaisons claire, sombre et monochrome. | aucune |

## 2026-11-25 — Synchronisation et API (TODO-3.2)

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-99"></a>D-99 | Modifications faites sur deux supports | Contact, paramètres généraux ou informations d'une navigation modifiés sur le Web et sur l'application mobile hors connexion (ancienne question 42). | La dernière modification reçue par le serveur l'emporte, champ par champ ; l'application mobile affiche ensuite la version du serveur, sans message. Écart corrigé : l'API proposée refusait (409) une modification fondée sur une version dépassée ; ce refus est supprimé de [08-architecture.md §4](08-architecture.md#4-api-et-synchronisation) et de [`api/openapi.yaml`](api/openapi.yaml), et les paramètres généraux se modifient champ par champ (`PATCH /v1/parametres` au lieu de `PUT`). | RG-COM-04 |
| <a id="d-100"></a>D-100 | Durée des sessions | « Sessions qui expirent » sans durée (RG-DON-03, ancienne question 43). | Expiration après 90 jours sans usage, sur mobile et sur le Web ; jamais sur le téléphone associé pendant une navigation en cours ; la déconnexion ne vide pas la file d'attente du téléphone. | RG-CPT-08 |
| <a id="d-101"></a>D-101 | Liens des SMS de photo et de note vocale | Ouverture du lien par un destinataire SMS non connecté (ancienne question 44). | Le lien mène à la connexion, puis à la photo ou à la note vocale dans la page de la navigation ; aucun accès sans compte. | RG-SMS-09 |
| <a id="d-102"></a>D-102 | Envois reçus après une clôture automatique | Positions, notes ou fin acquises hors connexion après la clôture par épuisement du quota (ancienne question 45). | Événements acquis avant l'heure de clôture gardés, ceux d'après refusés ; au premier échange, l'application apprend la clôture, arrête les positions automatiques et le dit au navigateur ; un SOS acquis après la clôture est enregistré comme un SOS depuis l'accueil. | RG-ECO-12 |
| <a id="d-103"></a>D-103 | Affichage des annonces | Où et combien de temps s'affichent les annonces de l'administrateur (RG-ADM-02, ancienne question 46). | Bandeau en haut de l'accueil de l'application mobile et du tableau de bord Web, jusqu'à la date de fin choisie ou jusqu'à sa fermeture par l'utilisateur. | RG-ADM-06 |
| <a id="d-104"></a>D-104 | Portée des désinscriptions du suiveur | E-mails de début et notifications push : pour tous les navigateurs suivis ou pour un seul (ancienne question 47). | Réglage unique du compte du suiveur, valable pour tous les navigateurs qu'il suit. | RG-NOT-04 |

## 2026-11-25 — Comptes, téléphones et paramètres (TODO-4.1 à TODO-4.4)

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-105"></a>D-105 | Adresse e-mail non confirmée | Ce que peut faire un compte avant de confirmer son adresse, et durée du lien (ancienne question 48). | Lien valable 7 jours ; avant la confirmation, ni démarrage d'une navigation ni invitation ; tout le reste permis ; un SOS n'est jamais bloqué. | RG-CPT-09 |
| <a id="d-106"></a>D-106 | Mot de passe oublié | Aucune règle pour changer un mot de passe oublié (ancienne question 49). | Lien envoyé par e-mail, valable 1 heure ; changer le mot de passe ferme toutes les sessions du compte. | RG-CPT-10 |
| <a id="d-107"></a>D-107 | Téléphone déjà associé à un autre compte | Un autre utilisateur se connecte sur un téléphone déjà enregistré (ancienne question 50). | Le téléphone passe au nouveau compte ; il est retiré des bateaux du premier compte, dont le propriétaire est prévenu par e-mail. | RG-BAT-04 |
| <a id="d-108"></a>D-108 | Google ou Apple avec l'adresse d'un compte existant | Connexion par un fournisseur avec l'adresse d'un compte inscrit par e-mail (ancienne question 51). | Rattachée au compte si le fournisseur garantit que l'adresse est vérifiée ; sinon refus. | RG-CPT-11 |
| <a id="d-109"></a>D-109 | Paramètres d'un nouveau compte | Valeurs de départ de l'interrupteur SMS, des types, du MMS de photo et de la fréquence (ancienne question 52). | SMS activés, tous les types cochés, pas de MMS de photo, fréquence de 30 minutes. | RG-PRM-06 |

## 2026-11-25 — Questions bloquant la version de production

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-110"></a>D-110 | File d'attente et doublons | Mécanisme de renvoi après une coupure, sans doublon (ancienne question 10, TODO-2.7). | Proposition de [08-architecture.md §5](08-architecture.md#5-file-dattente-et-doublons) validée telle quelle : identifiant unique tiré par le téléphone et numéro d'ordre pour chaque élément, renvoi sans doublon, SOS en priorité, fichiers après les éléments légers. Reste l'essai d'une coupure de 2 heures (TODO-2.7). | RG-GPS-04, RG-COM-05 |
| <a id="d-111"></a>D-111 | Navigations antérieures à un accès de périmètre *navigateur* | Le suiveur voit-il les navigations commencées avant que l'accès lui soit accordé (ancienne question 54) ? | Oui : il voit tout l'historique du navigateur, navigations terminées avant l'accès comprises, hors corbeille, comme la fiche du bateau (proposition validée). | RG-PAR-02, RG-PAR-09 |
| <a id="d-112"></a>D-112 | Quota redevenu disponible avant la clôture automatique | Des minutes redeviennent disponibles pendant les 24 heures qui précèdent la clôture (ancienne question 55). | La clôture est maintenue ; seul un abonnement l'annule. | RG-ECO-05 |
| <a id="d-113"></a>D-113 | Désignation des administrateurs | Qui obtient le profil d'administrateur, et comment (ancienne question 53). | Proposition validée : variable `NAUTILINK_ADMINS` du serveur, liste d'adresses e-mail ; compte NautiLink à l'adresse confirmée ; retrait immédiat quand l'adresse est retirée ; session de l'espace administrateur fermée après 12 heures sans usage. | RG-ADM-07 |
| <a id="d-114"></a>D-114 | Fonctionnement hors connexion | Comportement de chaque écran mobile sans Internet, sans réseau mobile ou sans les deux (ancienne question 29, TODO-2.6). | Tableau proposé validé en entier, propositions comprises. | RG-COM-06 |
| <a id="d-115"></a>D-115 | Environnements et API | Validation des trois environnements et de l'API (Q-22, TODO-3.2, TODO-3.4). | Environnements de développement, de test et de production de [08-architecture.md §6](08-architecture.md#6-environnements) validés ; API [`api/openapi.yaml`](api/openapi.yaml) validée telle que rédigée. Restent ouverts dans Q-22 : hébergeur après la bêta, sauvegardes. | — |
| <a id="d-116"></a>D-116 | Jetons de session sur le téléphone | Où l'application mobile garde ses jetons, verrouillage à l'ouverture. | Jetons gardés dans les préférences de l'application, sans chiffrement matériel (ni Keystore Android ni Trousseau iPhone) ; aucun code ni empreinte demandé à l'ouverture. | RG-CPT-12 |

## 2026-11-25 — Logo, alertes SOS, corbeille, mémo sécurité

| Id | Sujet | Contradiction ou manque | Décision | Règles |
|----|-------|-------------------------|----------|--------|
| <a id="d-117"></a>D-117 | Logo vectoriel | Le logo validé (D-98) n'existait qu'en image PNG ; TODO-8.1 l'a redessiné en vectoriel. | Redessin de `docs/assets/logo/` validé comme source officielle du logo et des icônes, avec ses déclinaisons claire, sombre et monochrome (05-identite-marque.md §5.5). | — |
| <a id="d-118"></a>D-118 | Contenu des e-mails SOS et de début | Destinataires décrits, pas le contenu (ancienne question 56). | Proposition validée : sujet « SOS — <bateau> : alerte de <navigateur> », contenu des deux SMS SOS, heures en UTC, lien vers la navigation ; copie avec la liste des adresses prévenues ; e-mail de début avec navigateur, navigation, bateau, heure, destination, lien, désinscription ; langue du navigateur. | RG-SOS-17, RG-NOT-05 |
| <a id="d-119"></a>D-119 | E-mail SOS refusé par le relais | Rien sur les nouveaux essais (ancienne question 57). | Nouvel essai chaque minute pendant 24 heures, destinataires recalculés. | RG-SOS-18 |
| <a id="d-120"></a>D-120 | SOS après la fin normale d'une navigation | Ancienne question 58 ; la proposition (SOS depuis l'accueil) n'est pas retenue. | Le SOS reste rattaché à la navigation terminée : journal de bord et destinataires de la navigation. Après une clôture automatique, RG-ECO-12 inchangée. | RG-SOS-19 |
| <a id="d-121"></a>D-121 | SOS depuis l'accueil vu des suiveurs | Ancienne question 59. | Visible des suiveurs de périmètre *navigateur* seulement. | RG-SOS-20 |
| <a id="d-122"></a>D-122 | Personne ajoutée pendant une navigation | Ancienne question 60. | Prévenue des SOS de la navigation (suiveurs et contacts SOS). | RG-SOS-21 |
| <a id="d-123"></a>D-123 | Navigation dans la corbeille | Ancienne question 70. | Visible du navigateur, non modifiable avant restauration ; envois en attente du téléphone acceptés. | RG-NAV-30 |
| <a id="d-124"></a>D-124 | Accès après la suppression définitive | Ancienne question 71. | Accès de périmètre *navigation* retirés ; contact gardé ; périmètre *navigateur* inchangé. | RG-PAR-10 |
| <a id="d-125"></a>D-125 | Mémo sécurité en mer dans les applications | Ancienne question 80. | Intégré à l'application, lisible hors connexion, ouvert depuis l'accueil ; texte rédigé sur le site, copié à chaque construction. | RG-SOS-22 |
| <a id="d-126"></a>D-126 | SOS hors des heures affichées | Après D-120, un SOS peut tomber hors des heures affichées d'une navigation : rien ne disait s'il compte dans le résumé ni s'il figure sur la carte. | Point d'alerte sur la carte, gardé dans le journal ; ni dans la distance ni dans les lieux de départ et d'arrivée. | RG-NAV-31 |
