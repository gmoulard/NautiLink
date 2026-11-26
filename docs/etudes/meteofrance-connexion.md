# Connexion à l'API de Météo-France

Créer le compte, obtenir les codes d'accès (identifiant d'application, jeton), les ranger et les utiliser pour la météo de chaque navigation ([RG-NAV-28](../02-regles-metier.md#rg-nav-28), [D-88](../07-decisions.md#d-88), [Q-39](../06-questions-ouvertes.md#q-39)).

> **État** : rédigé le 2026-11-25 sans accès direct au portail (injoignable depuis l'environnement de rédaction), d'après la FAQ du portail et la documentation Open Data de Météo-France vues par une recherche web (sources en fin de page). Les points marqués **à vérifier** se confirment en ouvrant le compte ; reporter alors le constat ici et dans Q-39.

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

Proposition (non validée) : identifiant d'application OAuth2, pour qu'aucune date d'expiration ne coupe la météo en pleine saison.

## 5. Ranger les codes

- **Jamais** dans le dépôt, dans un ticket, dans un e-mail ni dans une conversation avec un assistant.
- Production (Raspberry Pi sous pi-appliance) : variable d'environnement posée par la console de pi-appliance, comme les autres secrets (08-architecture.md §6). Nom proposé (non validé) : `NAUTILINK_METEOFRANCE`, qui contient l'identifiant d'application encodé tel que le portail le donne pour l'en-tête `Authorization: Basic`.
- Développement : variable posée dans le terminal du développeur, jamais écrite dans un fichier suivi par Git.
- Test : pas de code ; le serveur de test ne relève pas la météo (aucun envoi réel, 08-architecture.md §6).
- Sans variable posée, le serveur ne relève pas la météo et la page de la navigation ne l'affiche pas, sans erreur.

## 6. Utilisation par le serveur

Proposition (non validée) pour les points 4 à 6 : comportement en cas d'échec et conservation, à trancher dans Q-39.

1. **Obtenir un jeton** (OAuth2) : `POST https://portail-api.meteofrance.fr/token` avec le corps `grant_type=client_credentials` et l'en-tête `Authorization: Basic <identifiant d'application>`. La réponse contient `access_token` et sa durée (`expires_in`, environ 3 600 secondes). **À vérifier** : adresse exacte du point `/token`.
2. **Garder le jeton en mémoire** jusqu'à quelques minutes avant son expiration, puis en redemander un. Un refus 401 fait aussi redemander un jeton, une fois.
3. **Appeler l'API** avec l'en-tête `Authorization: Bearer <jeton>`. Avec une clé d'API à la place, l'en-tête est `apikey: <clé>` ou `Authorization: Bearer <clé>` selon les sources : **à vérifier**.
4. **Limite** : 60 requêtes par minute et par compte selon la FAQ (**à vérifier**). NautiLink en est très loin, mais les appels passent par une file avec un délai entre deux appels, comme pour Nominatim.
5. **Échec** (service indisponible, quota dépassé) : nouvel essai plus tard ; la navigation n'est jamais bloquée par la météo ; la page affiche « Météo indisponible ».
6. La météo relevée est gardée avec la navigation (colonnes `meteo_depart` et `meteo_arrivee`), avec l'heure du relevé et la source.

## 7. Renouveler ou révoquer

- Fuite d'un code : le révoquer sur le portail, en créer un nouveau, mettre à jour la variable sur pi-appliance, redémarrer le serveur.
- Clé d'API (si ce choix est fait) : noter sa date d'expiration dans le TODO et la renouveler un mois avant.
- Changement de responsable : transférer le compte ou créer un nouvel identifiant sous le compte du projet.

## 8. Avant de cocher Q-39

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

## 10. Prochaines étapes

Dans cet ordre ; reporter chaque constat dans ce document et dans [Q-39](../06-questions-ouvertes.md#q-39).

1. **Jeton** : les quatre souscriptions faites, (re)générer le jeton ou vérifier que l'identifiant d'application couvre bien les quatre API (un jeton créé avant une souscription ne vaut pas pour elle, § 3). Essai depuis un poste, sans écrire le secret dans un fichier suivi par Git : demander un jeton (§ 6, étape 1) et noter ici l'adresse exacte du point `/token` constatée.
2. **Conditions d'utilisation** : les lire et cocher la ligne du § 8 (usage par un serveur pour une application publique, gratuité après la bêta, mention de la source « Météo-France »).
3. **Données en un point** : pour un point au large de Lorient, à l'heure courante, constater et noter ici, API par API, ce qui est obtenu et sous quelle forme (valeur en un point, ou fichier de grille, GRIB2 par exemple, à découper au point de grille le plus proche) :
   - vent et pression : API « Modèle AROME » (côtes françaises) ; API « Modèle ARPEGE » pour un point hors de la zone d'AROME (**à vérifier** : couverture de chaque modèle) ;
   - état de la mer (hauteur des vagues, houle) : API « Package Modèles de vague et surcote » ;
   - API « Environnement » : noter ce qu'elle apporte à RG-NAV-28 ; si rien, la souscription peut être retirée.
   Si l'une des trois données manque, revenir vers le porteur du projet (D-88 à revoir).
4. **Décisions à prendre avec le porteur du projet** (Q-39) : type de code (identifiant OAuth2, proposé au § 4), nom de la variable (`NAUTILINK_METEOFRANCE`, proposé au § 5), comportement en cas d'échec et conservation (§ 6, points 4 à 6), API retenue pour chaque donnée d'après l'étape 3. Puis trancher Q-39 (`D-nn`, règles, selon « Trancher une question » de `CLAUDE.md`).
5. **Code du serveur** : action [TODO-4.10](../TODO.md) : client Météo-France (jeton en mémoire, file d'appels, nouvel essai), relevé au début et à la fin de chaque navigation, colonnes `meteo_depart` et `meteo_arrivee`, affichage sur la page de la navigation de l'Application web et dans le PDF, essais avec un faux Météo-France ; sans variable posée, aucun relevé et aucune erreur.
6. **Mise en service** : poser la variable sur pi-appliance par la console (§ 5), redémarrer le serveur, démarrer puis terminer une navigation d'essai et constater la météo sur sa page ; cocher le § 8.

## Sources

- [FAQ du portail API de Météo-France](https://portail-api.meteofrance.fr/web/faq)
- [Guide de démarrage rapide des API de Météo-France (Open Data Météo-France)](https://confluence-meteofrance.atlassian.net/wiki/spaces/OpenDataMeteoFrance/pages/1447788546/Guide+de+d+marrage+rapide+d+couvrir+les+APIs+de+M+t+o-France)
- [Durée maximale d'une clé d'API (Open Data Météo-France)](https://confluence-meteofrance.atlassian.net/wiki/spaces/OpenDataMeteoFrance/pages/457803483/Quelle+est+la+dur+e+maximum+pour+un+token+API+Key)
- [API « Paquet modèles de vague et surcote » sur data.gouv.fr](https://www.data.gouv.fr/dataservices/api-package-modeles-de-vague-et-surcote)
- [Services de données de Météo-France sur data.gouv.fr](https://www.data.gouv.fr/organizations/meteo-france/dataservices)
