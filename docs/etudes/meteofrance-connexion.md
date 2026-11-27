# Connexion à l'API de Météo-France

Créer le compte, obtenir les codes d'accès (identifiant d'application, jeton), les ranger et les utiliser pour la météo de chaque navigation ([RG-NAV-28](../02-regles-metier.md#rg-nav-28), [D-88](../07-decisions.md#d-88), [D-172](../07-decisions.md#d-172)).

> **État** : rédigé le 2026-11-25 sans accès direct au portail (injoignable depuis l'environnement de rédaction), d'après la FAQ du portail et la documentation Open Data de Météo-France vues par une recherche web (sources en fin de page). Les points marqués **à vérifier** se confirment en ouvrant le compte ; reporter alors le constat ici.

## 1. Ce dont NautiLink a besoin

Au début et à la fin de chaque navigation, le serveur relève la météo au point de départ et au point d'arrivée : vent, état de la mer, pression (RG-NAV-28). Cela fait quelques appels par navigation, à l'heure du début et à celle de la fin, toujours par le serveur, jamais par l'application mobile (aucun code Météo-France dans l'application).

## 2. Créer le compte

1. Aller sur le portail des API de Météo-France : <https://portail-api.meteofrance.fr/>.
2. « Créer un compte » : adresse e-mail et mot de passe. Prendre une adresse du projet plutôt qu'une adresse personnelle si possible, pour qu'un autre membre de l'équipe puisse reprendre le compte.
3. Valider le compte avec le lien reçu par e-mail, puis se connecter.
4. Lire les conditions générales d'utilisation. **À vérifier** : usage par un serveur pour une application publique autorisé, mention de la source « Météo-France » exigée sur la page de la navigation, usage gratuit maintenu après la bêta (abonnement payant de NautiLink).

## 3. S'abonner aux API

Sur le portail, chaque API se souscrit à part (souscription gratuite). Un jeton créé **avant** une souscription ne vaut pas pour l'API ajoutée ensuite : générer un nouveau jeton après chaque nouvelle souscription.

API à souscrire (**à vérifier** sur le catalogue du portail : noms exacts et données disponibles en un point latitude/longitude) :

| Donnée (RG-NAV-28) | Piste | Remarque |
|--------------------|-------|----------|
| Vent, pression | Prévisions du modèle AROME (API « AROME » ou « Paquet AROME »), ou observations des stations (« Données Publiques Observation ») | AROME couvre la France et ses côtes sur une grille fine ; une station peut être loin d'un point en mer. |
| État de la mer (hauteur des vagues, houle) | « Paquet modèles de vague et surcote » (modèles MFWAM et WaveWatch III) | Données en grille : le serveur prend le point de grille le plus proche. Si aucune API ne donne l'état de la mer en un point, revenir vers le porteur du projet (D-88 serait à revoir). |

## 4. Choisir le type de code

Le portail propose deux façons de s'identifier, pour une « application » créée dans l'espace du compte.

| | Identifiant d'application (OAuth2) — **proposé** | Clé d'API (API Key) |
|---|---|---|
| Ce qu'on garde | Identifiant d'application (« client » et secret), sans date de fin | La clé elle-même |
| Utilisation | Le serveur demande un jeton, valable environ 1 heure, et le redemande quand il a expiré | Envoyée telle quelle à chaque appel |
| Durée | Pas d'expiration de l'identifiant ; jeton court | Choisie à la création, 3 ans au plus selon la documentation (**à vérifier**) |
| Risque | Rien à renouveler à la main | Panne le jour où la clé expire, si personne ne l'a renouvelée |

Retenu le 2026-11-27 ([D-172](../07-decisions.md#d-172)) : identifiant d'application OAuth2, pour qu'aucune date d'expiration ne coupe la météo en pleine saison.

## 5. Ranger les codes

- **Jamais** dans le dépôt, dans un ticket, dans un e-mail ni dans une conversation avec un assistant.
- Production (Raspberry Pi sous pi-appliance) : variable d'environnement du serveur, comme les autres secrets (08-architecture.md §6) ; comment la poser : § 5.1. Nom retenu ([D-172](../07-decisions.md#d-172)) : `NAUTILINK_METEOFRANCE`, qui contient l'identifiant d'application encodé tel que le portail le donne pour l'en-tête `Authorization: Basic` (identifiant et secret en base64 : un codage, pas un chiffrement).
- Développement : variable posée dans le terminal du développeur, jamais écrite dans un fichier suivi par Git.
- Test : pas de code ; le serveur de test ne relève pas la météo (aucun envoi réel, 08-architecture.md §6).
- Ou bien, en production, écran « Réglages » de l'espace administrateur (§ 5.1), gardé dans la base du serveur, prioritaire sur la variable.
- Sans variable ni code posé sur l'écran, le serveur ne relève pas la météo et la page de la navigation ne l'affiche pas, sans erreur.

### 5.1 Poser le code sur pi-appliance

**Le plus simple, depuis le serveur de 2026-11-27 (TODO-7.2, [RG-ADM-08](../02-regles-metier.md#rg-adm-08), [D-174](../07-decisions.md#d-174))** : Application web → menu « Administration » → connexion à l'espace administrateur → « Réglages » → coller la chaîne du portail (ou « identifiant:secret ») dans « Nouveau code d'accès » → « Enregistrer ». Le serveur vérifie le code auprès de Météo-France avant de l'enregistrer et le garde dans sa base : rien à refaire après une mise à jour du serveur, ni fichier `.env` à toucher, ni redémarrage. « Vérifier auprès de Météo-France » contrôle le code en service à tout moment. Les façons ci-dessous restent possibles (le code de l'écran l'emporte sur la variable) ; pour éviter deux endroits, ne garder que l'écran.

Le serveur est installé par « Docker Compose libre » (service `nautilink`, [`server/compose.yaml`](../../server/compose.yaml)). Dans les deux cas ci-dessous, le fichier Compose doit reprendre la variable, dans `environment` du service `nautilink` (ajoutée le 2026-11-27 avec le client Météo-France, TODO-4.10) :

```yaml
NAUTILINK_METEOFRANCE: "${NAUTILINK_METEOFRANCE:-}"
```

**Avant l'évolution TODO-2.85 de pi-appliance** (console jusqu'à la 0.2.8 au moins) : la console n'a pas d'écran pour le fichier `.env` d'un Docker Compose libre, et elle le réécrit à chaque réinstallation (seule façon de mettre à jour un Docker Compose libre : changer l'image dans le fichier et réinstaller) avec ses seules variables (`PI_INSTANCE`, `PI_HOST`, `PI_SMTP_…`). Deux façons, au choix :

- **Par « Réglages avancés »** (proposé, sans ligne de commande) : fiche du service `nautilink` → « Réglages avancés » → conteneur `nautilink` → variable `NAUTILINK_METEOFRANCE=<valeur>` → enregistrer ; la console redémarre le service et remet les réglages d'avant s'il ne repart pas. La variable est posée directement dans le conteneur : la ligne du fichier Compose ci-dessus n'est pas nécessaire (elle ne gêne pas : la variable des réglages avancés l'emporte). Limites : la valeur reste lisible en clair par tout administrateur qui ouvre cet écran ; à vérifier : réglage gardé après une réinstallation.
- **Par le fichier `.env`** : depuis le terminal de Cockpit (marketplace de la console) ou en SSH, `sudo nano /var/lib/pi-appliance/services/nautilink/.env` (dossier des données de pi-appliance, sur le disque USB s'il y est), ajouter la ligne `NAUTILINK_METEOFRANCE='<valeur>'` sans toucher aux lignes `PI_…` (pas d'apostrophe dans la valeur, pas de commentaire : la console les efface), puis « Reconstruire » dans la fiche du service (données et `.env` gardés). **La ligne est perdue à chaque réinstallation** : la remettre après chaque mise à jour du serveur, comme `NAUTILINK_ADMINS`, `NAUTILINK_GOOGLE_CLIENTS` et les autres réglages du `.env`.

**Après l'évolution TODO-2.85 de pi-appliance** (champ « Contenu du fichier .env » d'un Docker Compose libre ; tranché le 2026-11-27, pas encore réalisé ; version de la console à noter ici quand elle sortira) :

- **À l'installation** : coller dans le champ « Contenu du fichier .env » la ligne `NAUTILINK_METEOFRANCE=<valeur>`, avec les autres réglages du `.env` de NautiLink (`NAUTILINK_ADMINS`, `NAUTILINK_GOOGLE_CLIENTS`…). Les variables `PI_…` restent à la console : le champ les refuse.
- **Changer le code** (renouvellement, fuite, § 7) : « Réglages avancés » de la fiche du service, où le `.env` se modifie ; le service redémarre, et l'ancien `.env` est remis s'il ne repart pas.
- **Mise à jour du serveur** (réinstallation après une désinstallation qui garde les données) : le champ est prérempli avec l'ancien `.env` ; vérifier qu'il contient la ligne, puis installer.
- **« Reconstruire »** garde le `.env` ; **« Réinitialisation d'usine »** demande s'il faut le garder : répondre oui, sinon le code est à reposer.
- **« Source »** montre le `.env` avec le fichier Docker Compose (réservé aux administrateurs) : ne pas copier son contenu dans un ticket, un e-mail ni une conversation avec un assistant.
- Dès cette version installée sur le Pi, passer de « Réglages avancés » (variable du conteneur) au champ `.env`, et retirer la variable des réglages avancés pour qu'il n'y ait qu'un seul endroit.

## 6. Utilisation par le serveur

Points 4 à 6 : tranchés le 2026-11-27 ([D-172](../07-decisions.md#d-172), RG-NAV-38) ; nouveaux essais pendant 1 heure en cas d'échec.

1. **Obtenir un jeton** (OAuth2) : `POST https://portail-api.meteofrance.fr/token` avec le corps `grant_type=client_credentials` et l'en-tête `Authorization: Basic <identifiant d'application>`. La réponse contient `access_token` et sa durée (`expires_in`, environ 3 600 secondes). **À vérifier** : adresse exacte du point `/token`.
2. **Garder le jeton en mémoire** jusqu'à quelques minutes avant son expiration, puis en redemander un. Un refus 401 fait aussi redemander un jeton, une fois.
3. **Appeler l'API** avec l'en-tête `Authorization: Bearer <jeton>`. Avec une clé d'API à la place, l'en-tête est `apikey: <clé>` ou `Authorization: Bearer <clé>` selon les sources : **à vérifier**.
4. **Limite** : 60 requêtes par minute et par compte selon la FAQ (**à vérifier**). NautiLink en est très loin, mais les appels passent par une file avec un délai entre deux appels, comme pour Nominatim.
5. **Échec** (service indisponible, quota dépassé) : nouvel essai plus tard ; la navigation n'est jamais bloquée par la météo ; la page affiche « Météo indisponible ».
6. La météo relevée est gardée avec la navigation (colonnes `meteo_depart` et `meteo_arrivee`), avec l'heure du relevé et la source.

## 7. Renouveler ou révoquer

- Fuite d'un code : le révoquer sur le portail, en créer un nouveau, le poser sur l'écran « Réglages » de l'espace administrateur (§ 5.1, sans redémarrage) ou dans la variable.
- Clé d'API (si ce choix est fait) : noter sa date d'expiration dans le TODO et la renouveler un mois avant.
- Changement de responsable : transférer le compte ou créer un nouvel identifiant sous le compte du projet.

## 8. Avant la mise en service

- [x] Compte créé et validé (2026-11-26).
- [ ] Conditions d'utilisation lues : usage serveur, gratuité, mention de la source.
- [x] API souscrites (2026-11-26, § 9).
- [ ] Vent, pression et état de la mer obtenus pour un point au large de Lorient (§ 10, étape 3).
- [ ] Type de code choisi, nom de la variable validé, code posé sur pi-appliance.
- [ ] Ce document corrigé d'après ce qui a été constaté.

## 9. Souscription Nautilink

API Package Modèles de vague et surcote. : 
https://public-api.meteofrance.fr/public/wavesmodels/1.0

API Modèle AROME
https://public-api.meteofrance.fr/public/arome/1.0

API Modèle ARPEGE
https://public-api.meteofrance.fr/public/arpege/1.0

API Environnement
https://public-api.meteofrance.fr/previnum/DPPaquetENVIRONNEMENT/v1

Identifiant d'application OAuth2 créé ; son secret est gardé par le porteur du projet, hors du dépôt (§ 5).

Correction (essai du 2026-11-27) : l'adresse de l'API « Package Modèles de vague et surcote » notée ci-dessus répond 404 sur toutes ses ressources ; l'adresse qui fonctionne est `https://public-api.meteofrance.fr/previnum/DPPaquetWAVESMODELS/v1` (ressources listées sur la page de l'API du portail, `PaquetWAVESMODELS`).

### 9.1 Constats de l'essai du 2026-11-27

Jeton généré sur le portail par le porteur du projet, utilisé sans être recopié ; point d'essai au large de Lorient, au sud de Groix (47,55° N ; 3,55° O).

- **Jeton** : un seul jeton (type `at+jwt`, valable 1 heure, émis par `https://portail-api.meteofrance.fr/oauth2/token`) ouvre les quatre API : elles appartiennent à la même application. En-tête `Authorization: Bearer <jeton>`.
- **AROME** (`/public/arome/1.0/wcs/MF-NWP-HIGHRES-AROME-001-FRANCE-WCS/…`, service WCS 2.0.1) : domaine de 12° O à 16° E et de 37,5° N à 55,4° N ; nouveau calcul toutes les 3 heures ; échéances horaires. Couvertures utiles : `WIND_SPEED__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND` (hauteurs 10, 20, 50, 100 m), `WIND_SPEED_GUST__…`, composantes U et V (direction), `PRESSURE__MEAN_SEA_LEVEL`. `GetCoverage` sur une petite zone autour du point (`subset=long(…)`, `subset=lat(…)`, `subset=height(10)`, `subset=time(…)`) rend une grille de 3 × 3 points en TIFF (3 Ko, valeurs lisibles directement) ou en GRIB2 (193 octets). Valeurs obtenues pour 23:00 UTC le 2026-11-26 : vent à 10 m 3,7 m/s (environ 7 nœuds), pression 101 643 Pa (1016,4 hPa). **Vent et pression en un point : obtenus.**
- **ARPEGE** (`/public/arpege/1.0/wcs/…`, même service WCS) : catalogues `MF-NWP-GLOBAL-ARPEGE-01-EUROPE-WCS` (0,1°) et `MF-NWP-GLOBAL-ARPEGE-025-GLOBE-WCS` (0,25°) lus ; utile hors du domaine d'AROME (valeurs non relevées).
- **Vagues et surcote** (`/previnum/DPPaquetWAVESMODELS/v1`) : modèles MFWAM, WW3-MARP, WW3-WARP, WW3-MARO. MFWAM : grilles 0,025° et 0,1° ; paquet `SP1` « Paramètres courants à la surface » : MWD, MWP, SWH (hauteur significative des vagues), MDWW, MPWW, SHWW (mer du vent), MDPS, MPPS, SHPS (houle primaire), MDSS, MPSS, SHSS, MDS, MPS, SHS, PP1D, WIND, DWI ; calculs toutes les 6 heures, gardés environ 3 jours ; échéances horaires (`time=001H`, `002H`…). Téléchargement : `/models/MFWAM/grids/0.025/packages/SP1/productMFWAM?referencetime=2026-11-26T12:00:00Z&time=011H&format=grib2`. **Pas d'extraction en un point** : chaque échéance est un fichier GRIB2 entier de 5,3 Mo (18 messages, grille de 801 × 601 points, de 38° à 53° N et de 8° O à 12° E), compressé en CCSDS (modèle de représentation 5.42). Fichier décodé avec la bibliothèque `eccodes` de l'ECMWF (version 2.50.1, sur le poste d'essai) ; point de grille exactement au point d'essai. Valeurs pour 23:00 UTC le 2026-11-26 (calcul de 12:00 UTC, échéance 011H) : hauteur significative des vagues (SWH) 0,84 m, période moyenne 8,1 s, direction moyenne 266° ; mer du vent 0,07 m (1,7 s, de 203°) ; houle totale 0,84 m (8,1 s, de 266°), dont houle primaire 0,82 m (7,9 s, de 266°) et secondaire 0,15 m (15 s, de 279°) ; période de pic 8,9 s ; vent du modèle de vagues à 10 m 4,8 m/s de 187° (forçage différent d'AROME, qui donne 3,7 m/s au même point). **État de la mer au point : obtenu**, à condition de décoder le GRIB2 CCSDS.
- **Environnement** (`/previnum/DPPaquetENVIRONNEMENT/v1`, modèle PHEALTH) : indice UV maximal sur 24 heures seulement ; n'apporte rien à RG-NAV-28 : la souscription peut être retirée.

## 10. Prochaines étapes

Dans cet ordre ; reporter chaque constat dans ce document.

1. ~~**Jeton**~~ (fait le 2026-11-27, § 9.1 ; reste à faire demander le jeton par l'identifiant d'application, sans le portail) : les quatre souscriptions faites, (re)générer le jeton ou vérifier que l'identifiant d'application couvre bien les quatre API (un jeton créé avant une souscription ne vaut pas pour elle, § 3). Essai depuis un poste, sans écrire le secret dans un fichier suivi par Git : demander un jeton (§ 6, étape 1) et noter ici l'adresse exacte du point `/token` constatée.
2. **Conditions d'utilisation** : les lire et cocher la ligne du § 8 (usage par un serveur pour une application publique, gratuité après la bêta, mention de la source « Météo-France »).
3. **Données en un point** (fait le 2026-11-27 : vent, pression et état de la mer obtenus, § 9.1) : pour un point au large de Lorient, à l'heure courante, constater et noter ici, API par API, ce qui est obtenu et sous quelle forme (valeur en un point, ou fichier de grille, GRIB2 par exemple, à découper au point de grille le plus proche) :
   - vent et pression : API « Modèle AROME » (côtes françaises) ; API « Modèle ARPEGE » pour un point hors de la zone d'AROME (**à vérifier** : couverture de chaque modèle) ;
   - état de la mer (hauteur des vagues, houle) : API « Package Modèles de vague et surcote » ;
   - API « Environnement » : noter ce qu'elle apporte à RG-NAV-28 ; si rien, la souscription peut être retirée.
   Si l'une des trois données manque, revenir vers le porteur du projet (D-88 à revoir).
   Décisions du 2026-11-27 ([D-168](../07-decisions.md#d-168), puis [D-169](../07-decisions.md#d-169)) : AROME pour le vent et la pression ; MFWAM (paquet `SP1`, GRIB2) pour l'état de la mer, décodé par le serveur. Les souscriptions « Environnement » et « ARPEGE » (sauf besoin hors de la zone d'AROME) peuvent être retirées ; garder « Package Modèles de vague et surcote ». Décodage côté serveur : la lecture marche avec `eccodes` (bibliothèque C, avec la compression CCSDS de `libaec`) ; bibliothèques Go sans dépendance C annoncées pour le modèle 5.42, non encore essayées : `dmarkham/grib2` (MIT, valeur au point le plus proche), `knoweather/simple-grib` (MIT), `pspoerri/go-tiled-eccodes` (MIT), `shyrmapp/aec` (Apache-2.0, décompression seule) ; toutes récentes et peu utilisées : à vérifier sur un vrai fichier contre `eccodes` avant de choisir (TODO-4.10).
4. ~~**Décisions à prendre avec le porteur du projet**~~ (tranchées le 2026-11-27, [D-172](../07-decisions.md#d-172)) : type de code (identifiant OAuth2, proposé au § 4), nom de la variable (`NAUTILINK_METEOFRANCE`, proposé au § 5), comportement en cas d'échec et conservation (§ 6, points 4 à 6), API retenue pour chaque donnée d'après l'étape 3. 
5. **Code du serveur** (fait le 2026-11-27 : `server/meteo.go`, lecture GRIB2 et CCSDS en Go seul dans `server/grib2.go`, vérifiée contre eccodes sur des fichiers CCSDS fabriqués par `server/testdata/fabrique-grib2.py` ; reste la vérification sur un vrai fichier MFWAM) : action [TODO-4.10](../TODO.md) : client Météo-France (jeton en mémoire, file d'appels, nouvel essai), relevé au début et à la fin de chaque navigation, colonnes `meteo_depart` et `meteo_arrivee`, affichage sur la page de la navigation de l'Application web et dans le PDF, essais avec un faux Météo-France ; sans variable posée, aucun relevé et aucune erreur.
6. **Mise en service** : poser la variable sur pi-appliance (§ 5.1, avant ou après TODO-2.85 de pi-appliance), démarrer puis terminer une navigation d'essai et constater la météo sur sa page ; cocher le § 8.

## Sources

- [FAQ du portail API de Météo-France](https://portail-api.meteofrance.fr/web/faq)
- [Guide de démarrage rapide des API de Météo-France (Open Data Météo-France)](https://confluence-meteofrance.atlassian.net/wiki/spaces/OpenDataMeteoFrance/pages/1447788546/Guide+de+d+marrage+rapide+d+couvrir+les+APIs+de+M+t+o-France)
- [Durée maximale d'une clé d'API (Open Data Météo-France)](https://confluence-meteofrance.atlassian.net/wiki/spaces/OpenDataMeteoFrance/pages/457803483/Quelle+est+la+dur+e+maximum+pour+un+token+API+Key)
- [API « Paquet modèles de vague et surcote » sur data.gouv.fr](https://www.data.gouv.fr/dataservices/api-package-modeles-de-vague-et-surcote)
- [Services de données de Météo-France sur data.gouv.fr](https://www.data.gouv.fr/organizations/meteo-france/dataservices)
