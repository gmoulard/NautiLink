# NautiLink — Questions ouvertes et études

Tout ce qui n'est pas encore décidé est ici, et seulement ici. Chaque question a un identifiant `Q-nn` stable, cité par les autres documents.

- **Priorité** : *bloquant* (à trancher avant de développer la fonction concernée), *lancement* (avant la mise en service), *plus tard*.
- **Proposition** : choix par défaut suggéré, **non validé**. Ne pas l'implémenter tant que le porteur du projet ne l'a pas confirmé.
- Quand une question est tranchée : ajouter une décision dans [07-decisions.md](07-decisions.md), reporter la règle dans [02-regles-metier.md](02-regles-metier.md) et les autres documents, puis supprimer la question d'ici (son identifiant n'est pas réutilisé). Le travail correspondant est suivi dans le [TODO](TODO.md).

## 1. Questions fonctionnelles

### <a id="q-39"></a>Q-39 — Service météo : conditions d'accès

- Priorité : avant la version réelle.
- Décidé (D-88) : la météo du début et de la fin d'une navigation (RG-NAV-28) vient de l'API de Météo-France.
- Reste à vérifier : conditions d'accès (clé, quotas, usage par un serveur) et présence des données demandées par RG-NAV-28 (vent, état de la mer, pression).
- Prévu (2026-11-25) : le porteur du projet ouvre le compte sur le portail API de Météo-France ; la météo est intégrée avant la sortie de la version réelle. Mode d'emploi et points à vérifier : [meteofrance-connexion.md](etudes/meteofrance-connexion.md).

### <a id="q-93"></a>Q-93 — Texte des SMS ordinaires

- Priorité : avant la version Android réelle (TODO-5.4).
- Cas : les règles disent quand partent les SMS ordinaires (début, positions, notes, photos, notes vocales, fin : RG-SMS-01 à RG-SMS-03), ce qu'ils disent sans GPS (RG-SMS-04), et le lien d'une photo ou d'une note vocale (RG-SMS-05, RG-SMS-06, RG-SMS-09), mais pas leur texte. Le contenu des SMS SOS, lui, est fixé (RG-SOS-07, RG-SOS-08).
- Proposition (non validée) : une première ligne « NautiLink <bateau> — <type d'envoi> à <heure>. », l'heure selon RG-PRM-07 (types : « début de navigation », « position », « note », « photo », « note vocale », « fin de navigation ») ; puis, selon le type : « Destination : <destination>. » au début ; « Position <latitude>, <longitude> : <lien Google Maps> » ou « GPS NON DISPONIBLE » pour le début, les positions et la fin ; « Note : <texte> » ; « Photo : <lien> » ou « Note vocale : <lien> » vers l'élément dans la page de la navigation ; « Suivre la navigation : <lien de la page> » au début. Dans la langue du navigateur (RG-PRM-04). Le second SMS SOS commence par « SOS <bateau> (suite). ».
- Appliqué en attendant dans l'application (`app/lib/reel/sms_navigation.dart`, textes `sms…` de `app/lib/l10n/`).

### <a id="q-99"></a>Q-99 — Conduite d'une navigation depuis l'Application web

- Priorité : avant la conduite d'une navigation depuis l'Application web (TODO-6.8).
- Cas : D-150 donne à l'Application web toutes les fonctions de l'application mobile, conduite d'une navigation et SOS compris (RG-WEB-01, RG-WEB-02). Les règles de la conduite supposent un téléphone : position par son GPS (RG-GPS-01), positions automatiques en arrière-plan (RG-GPS-03), téléphone associé au bateau (RG-BAT-02, RG-NAV-03, RG-NAV-34), reprise par le téléphone d'une navigation que le serveur dit en cours (RG-NAV-33), fuseau du téléphone pour les heures (RG-PRM-07), photo par l'appareil photo et note vocale en AAC (RG-AND-06, RG-JRN-04). Une page Web ne garde pas la position écran éteint, et la plupart des navigateurs Internet n'enregistrent pas l'AAC.
- Points à décider : 1) position (début, position manuelle, note, SOS, fin) : localisation du navigateur Internet avec l'accord de la personne, saisie à la main, ou aucune ; 2) positions automatiques : tant que la page reste ouverte, ou aucune ; 3) téléphone : navigation démarrée sur le Web sans téléphone, ou rattachée au téléphone associé du bateau, qui la reprend (RG-NAV-33) ; 4) bateau au démarrage et pour un SOS hors navigation : choix parmi tous les bateaux du compte ; 5) photo et note vocale : fichier choisi (JPEG, AAC `.m4a`, comme les ajouts) ou prise par l'appareil photo et le micro du navigateur Internet (autre format audio à accepter) ; 6) fuseau des heures : celui du navigateur Internet (lu par JavaScript), sinon UTC.
- Proposition (non validée) : 1) localisation du navigateur Internet si la personne l'accepte, sinon sans position (SOS : dernière position connue, RG-SOS-10) ; 2) tant que la page reste ouverte, à la fréquence de la navigation, avec un avertissement ; 3) sans téléphone, reprise par le téléphone associé du bateau s'il s'y connecte (RG-NAV-33) ; 4) tous les bateaux du compte ; 5) fichier choisi, que le téléphone peut prendre avec son appareil photo ; 6) fuseau du navigateur Internet.
- Appliqué en attendant dans l'Application web : pendant une navigation en cours, note, photo et note vocale par fichier choisi, fin et SOS, sans position (le SOS prend la dernière position du journal, RG-SOS-10) ; heures dans le fuseau du téléphone au début de la navigation ; SOS hors navigation : bateau choisi parmi ceux du compte, heure en UTC. Démarrage et positions depuis le Web : pas encore faits.

### <a id="q-100"></a>Q-100 — Chef de bord : forme, affichage, modification

- Priorité : avant la version suivante de l'application mobile (TODO-5.10).
- Cas : RG-NAV-35 (D-153) fait du chef de bord un réglage de l'écran de démarrage, prérempli avec le nom du navigateur et modifiable. Restent : sa forme (texte libre ou personne des contacts), sa modification après le démarrage, où il apparaît (page de la navigation, export PDF, SMS SOS, e-mail SOS, e-mail de début) et son champ dans l'API.
- Proposition (non validée) : texte libre ; modifiable ensuite comme le nom de la navigation (RG-NAV-22) ; affiché sur la page de la navigation et dans l'export PDF, et ajouté au SMS SOS et à l'e-mail SOS (« Chef de bord : <nom> ») ; champ `chefDeBord` de la navigation dans l'API (texte ; absent : nom du navigateur).

### <a id="q-101"></a>Q-101 — Incident ou avarie : création dans l'application mobile

- Priorité : avant la version suivante de l'application mobile (TODO-5.11).
- Cas : RG-JRN-11 (D-154) crée le type « Incident - avarie » ; l'utilisateur n'a pas retenu l'option « Bouton Incident - avarie sur l'écran de navigation », sans dire comment il se crée. Le serveur range une seule pièce jointe par événement, alors que la photo et la note vocale sont toutes deux facultatives.
- Options : A) bouton « Incident - avarie » sur l'écran de navigation ; B) choix « Incident - avarie » dans la fenêtre de « NOTE » ; C) entrée dans un menu de l'écran de navigation. Pièce jointe : une photo ou une note vocale, ou les deux.
- Proposition (non validée) : B, qui n'ajoute pas de bouton à l'écran de navigation ; une seule pièce jointe, photo ou note vocale (appliqué en attendant par le serveur).
### <a id="q-102"></a>Q-102 — Remarques de relecture de l'application Android

- Priorité : avant la version suivante de l'application mobile (TODO-5.12).
- Demande de l'utilisateur du 2026-11-26 : document de relecture de l'application Android (captures commentées, TODO-5.12). Certaines remarques changent une règle ou un libellé écrit dans les règles :
  1. personnes alertées : un choix e-mail et un choix SMS par personne sur l'écran de démarrage, au lieu d'une seule case (RG-NAV-25) ;
  2. « Le personnes son toujours suiveur et contact SOS il n'y a pas de difference » : contredit les deux cases « Suiveur » et « Contact SOS » de chaque contact (RG-CTC-01, RG-CTC-04, RG-CTC-05 : un contact SOS a un numéro, un suiveur une invitation acceptée) ;
  3. libellés : « Début de navigation » au lieu de « Envoi message – Début de navigation » (RG-NAV-08), « Envoyer position » au lieu de « Envoyer information position » (glossaire), « Depuis le dernier envoi position » pour le second chronomètre (RG-NAV-10 compte tout envoi, pas seulement les positions) ;
  4. lien vers « la page MTO » sur l'écran de navigation : la météo n'est relevée qu'au début et à la fin et affichée sur l'Application web (RG-NAV-28), son service n'est pas ouvert ([Q-39](#q-39)) ;
  5. mémo sécurité en mer « sur toutes les pages comme le pied de page » (RG-SOS-22 : depuis l'accueil) ;
  6. « Enlevé la notion de limité à 1 minute » : retirer seulement la mention à l'écran, ou la limite elle-même (RG-JRN-04, D-53).
- Proposition (non validée) : 1) deux cases « E-mail » et « SMS » par personne, cochées ; une personne décochée des deux n'est pas alertée, SOS compris (comme RG-NAV-25) ; 2) garder les deux cases sur la fiche du contact (un contact SOS doit avoir un numéro), mais ne plus les afficher dans la liste de l'écran de démarrage ; 3) libellés adoptés, le second chronomètre gardant sa règle (tout envoi le remet à zéro) ; 4) lien vers la prévision marine de Météo-France pour la position actuelle, sans relevé par NautiLink ; 5) lien « Mémo sécurité en mer » dans le pied de page de chaque écran ; 6) retirer la mention seulement, la limite d'une minute restant (taille des fichiers et des MMS).
- Appliqué en attendant dans l'application 0.2.0 (TODO-5.12) ; lien météo : page « Météo marine » de Météo-France (<https://meteofrance.com/meteo-marine>), sans la position actuelle.

## 2. Études techniques

### <a id="q-09"></a>Q-09 — GPS en arrière-plan et batterie

- Priorité : bloquant.
- Étude : enregistrement GPS application en arrière-plan ou écran éteint, consommation de batterie, comportement selon les marques et versions d'Android, et sur iPhone (localisation en arrière-plan, règles de l'App Store).
- Étude documentaire Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md).
- Étude documentaire iPhone : [localisation-arriere-plan-iphone.md](etudes/localisation-arriere-plan-iphone.md).

### <a id="q-12"></a>Q-12 — Restrictions Android sur l'envoi de SMS

- Priorité : bloquant, à étudier en premier.
- Décidé (D-48) : exception « urgence » de Google Play pour les SMS SOS ; SMS ordinaires préremplis.
- Décidé (D-82) : les SMS de positions automatiques partent aussi automatiquement ; la demande de permission auprès de Google Play doit couvrir ce cas, avec le risque accepté d'un refus en dehors de l'exception « urgence » ; sans cette permission, positions au serveur seulement (D-91).
- Décidé (D-157) : avec la permission, tous les SMS de l'application partent automatiquement, invitations comprises ; la demande auprès de Google Play doit couvrir cet usage, hors de la seule exception « urgence ».
- Reste : lire la page officielle de Google Play et vérifier que l'exception existe et couvre NautiLink. Si elle est refusée, revenir vers l'utilisateur.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md) (voies possibles §3).

### <a id="q-13"></a>Q-13 — MMS

- Priorité : lancement.
- Décidé (D-49) : en cas d'échec, SMS avec le lien vers la photo.
- Reste : taille maximale des pièces jointes et compatibilité des opérateurs, à mesurer.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md#5-mms-todo-24).

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- Décidé (D-58, D-59) : applications mobiles Android et iPhone en Flutter, un seul code ; serveur maison.
- Décidé (D-62) : serveur en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance, base PostgreSQL ; base propre au service dans `server/compose.yaml` (D-130).
- Décidé (D-86) : photos et notes vocales stockées dans PostgreSQL ; notifications push par APNs pour l'iPhone et Firebase Cloud Messaging pour Android (contenu sur Android : D-92, RG-AND-08) ; sauvegardes de pi-appliance, chaque nuit, gardées 30 jours (RG-DON-02).
- Décidé (D-96) : [08-architecture.md](08-architecture.md) validé, propositions comprises (serveur virtuel dans l'Union européenne après la bêta, relais d'e-mails avec SPF, DKIM et DMARC, géocodage par Nominatim).
- Décidé (D-115) : API ([`api/openapi.yaml`](api/openapi.yaml)) et environnements de développement, de test et de production ([08-architecture.md §6](08-architecture.md#6-environnements)) validés.
- Reste : nom de l'hébergeur et date du passage après la bêta ; sauvegarde de la base du Pi ([Q-85](#q-85)), puis essai de restauration (TODO-3.11).

## 3. Données, sécurité, conformité

### <a id="q-85"></a>Q-85 — Sauvegarde de la base du Pi

- Priorité : avant la mise en service sur le Pi (TODO-3.7).
- Cas : depuis [D-130](07-decisions.md#d-130), la base est le service `base` de `server/compose.yaml` (volume `nautilink-base`) et non plus le PostgreSQL partagé de pi-appliance, sauvegardé chaque nuit. RG-DON-02 demande une sauvegarde quotidienne gardée 30 jours.
- Proposition (non validée) : vérifier d'abord si les sauvegardes de pi-appliance couvrent les volumes des services « Docker Compose libre » ; sinon, un service de sauvegarde dans `compose.yaml` qui fait chaque nuit un `pg_dump` de la base dans un second volume, en gardant les 30 derniers, et un essai de restauration (TODO-3.11).

## 4. Marque et interface

### <a id="q-26"></a>Q-26 — Nom et présence en ligne

- Priorité : lancement.
- À vérifier : disponibilité juridique du nom NautiLink, noms de domaine, comptes sur les réseaux sociaux.
- Étude : [nom NautiLink](etudes/nom-nautilink.md) (2026-11-25) : pas d'homonyme exact repéré parmi les applications ; quasi-homonyme Nauti-Link (conseil en cession d'entreprises du nautisme, France) ; bases de marques, domaines et comptes non consultés.
- Décidé (D-87) : le nom NautiLink est gardé, sous réserve des vérifications ci-dessous.
- Reste : consulter les bases de marques INPI, EUIPO et OMPI ; obtenir un avis juridique (cas Nauti-Link) ; puis réserver les domaines et les comptes libres.

### <a id="q-30"></a>Q-30 — Maquettes et accessibilité

- Priorité : bloquant pour le développement des écrans.
- Décidé (D-95) : WCAG 2.2 niveau AA (RG-PRM-05).
- Reste : validation des [maquettes](../site/designs/app.html) des écrans Android et Web.

## 5. Évolutions futures

### <a id="q-23"></a>Q-23 — Cartes marines du SHOM

- Priorité : lancement (demande de l'utilisateur du 2026-11-24, D-79).
- Étude : quelles données du SHOM sont gratuites et réutilisables sur la carte de la page d'une navigation (licence, clé d'accès, conditions d'affichage), et comment les superposer au fond OpenStreetMap et à OpenSeaMap (RG-NAV-29).

### <a id="q-27"></a>Q-27 — Autres langues

- Priorité : plus tard.
- Décidé (D-90) : français et anglais au lancement ; langue du téléphone par défaut, modifiable dans les paramètres ; messages envoyés aux suiveurs et aux contacts SOS dans la langue du navigateur (RG-PRM-03, RG-PRM-04).
- Essai dans le prototype (TODO-9.2) : textes des écrans dans `app/lib/l10n/app_fr.arb` (français, langue de référence) et `app_en.arb` (anglais), code généré par `flutter gen-l10n`.
- Décidé (D-93) : sur l'Application web, langue du navigateur Internet par défaut (RG-PRM-03).
- Reste : relecture de la traduction anglaise ; ajout d'autres langues après le lancement, sans gestion des langues dans l'espace administrateur (RG-ADM-04).

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).
