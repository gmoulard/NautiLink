# Publier NautiLink sur l'App Store

Mode d'emploi pour l'utilisateur ([D-194](../07-decisions.md#d-194), TODO-10.9, TODO-10.7). Il suit l'ordre à respecter : chaque étape a besoin de la précédente. Compter une à deux heures pour la première fois, sans la relecture d'Apple (un à trois jours en général).

Ce qui est automatique : à chaque changement de `app/` poussé sur `main`, le workflow « Site GitHub Pages » (`.github/workflows/pages.yml`, job « ios » sur macOS) construit l'IPA non signée du site (toujours publiée, pour Sideloadly et AltStore), puis, si les quatre secrets de l'étape 4 sont posés, une version signée pour l'App Store qu'il envoie à App Store Connect. Ce qui reste à la main : tout ce qui se passe dans les sites d'Apple (identifiant, application, clé, fiche, soumission), et la pose des secrets dans GitHub.

Rien de secret ne va dans le dépôt ni dans une conversation : la clé `.p8` n'est collée que dans le formulaire des secrets de GitHub.

Identifiants à reprendre tels quels :

| Quoi | Valeur |
|------|--------|
| Identifiant de l'application iPhone (« Bundle ID ») | `org.moulard.nautilink` (Android garde `fr.nautilink.nautilink`) |
| Nom de l'application | NautiLink |
| Achat intégré | `nautilink_abonnement_10_ans` (achat unique, 15 € pour 10 ans, [D-193](../07-decisions.md#d-193), RG-ECO-06) |
| Version | celle de `app/pubspec.yaml` (partie avant « + », par exemple `0.5.5`) |
| Numéro de build | numéro d'exécution du workflow (« run number »), qui augmente à chaque exécution |

## 1. Enregistrer l'identifiant de l'application

Site : [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), avec le compte Apple Developer.

1. « Identifiers », bouton « + », choisir « App IDs », « Continue », puis « App », « Continue ».
2. « Description » : `NautiLink`. « Bundle ID » : choisir « Explicit » et taper `org.moulard.nautilink`.
3. Dans « Capabilities », cocher :
   - **Push Notifications** : notifications de l'ami (RG-IOS-06) ;
   - **Sign In with Apple** : l'application propose « Se connecter avec Apple » (RG-CPT-02, paquet `sign_in_with_apple`) ; laisser « Enable as a primary App ID » ;
   - **In-App Purchase** est déjà actif pour toute application (case grisée) : rien à faire.

   Rien d'autre : pas d'App Groups, d'iCloud, de HealthKit, etc. Les deux droits utilisés sont aussi déclarés dans `app/ios/Runner/Runner.entitlements`.
4. « Continue », puis « Register ».
5. **Enregistrer votre iPhone** (« Devices », bouton « + ») : nom de l'iPhone et son identifiant (UDID). La signature automatique d'Apple passe par une signature de développement au moment de l'archive, qui demande au moins un appareil enregistré dans l'équipe ; sans lui, l'envoi échoue avec « Your team has no devices from which to generate a provisioning profile ». L'UDID se lit dans le Finder sur Mac (cliquer sous le nom de l'iPhone jusqu'à voir « UDID »), dans iTunes sur Windows (cliquer sur le numéro de série) ou dans Sideloadly, l'iPhone branché.

## 2. Créer l'application dans App Store Connect

Site : [App Store Connect](https://appstoreconnect.apple.com/), « Apps ».

1. Bouton « + », « Nouvelle app ».
2. Remplir :
   - **Plateformes** : iOS ;
   - **Nom** : `NautiLink` (le nom doit être libre sur l'App Store ; s'il est pris, voir l'[étude du nom](nom-nautilink.md)) ;
   - **Langue principale** : Français ;
   - **Identifiant de lot (Bundle ID)** : `org.moulard.nautilink` dans la liste (il y apparaît après l'étape 1) ;
   - **SKU** : une référence interne, jamais affichée, par exemple `nautilink-ios` ;
   - **Accès des utilisateurs** : « Accès complet ».
3. « Créer ».
4. Pour l'achat intégré, avant la fiche : « Accords, impôts et opérations bancaires » (menu « Entreprise ») : accepter l'**accord des apps payantes** et remplir les coordonnées bancaires et fiscales. Sans cet accord, l'achat intégré ne peut pas être vendu ni essayé en bac à sable (TODO-10.6).

## 3. Créer la clé d'API App Store Connect et relever le Team ID

Cette clé permet au workflow de signer et d'envoyer l'application sans votre mot de passe.

1. App Store Connect, « Utilisateurs et accès », onglet « Intégrations », « Clés de l'API App Store Connect », section « Clés d'équipe ». La première fois, il faut demander l'accès à l'API (« Demander l'accès »), accordé aussitôt au titulaire du compte.
2. « Générer une clé d'API » (ou « + ») :
   - **Nom** : `NautiLink GitHub` ;
   - **Accès** : **Admin**. La signature gérée par Apple (« cloud signing ») utilise un certificat de distribution géré dans le nuage, que seuls le titulaire du compte, les administrateurs et les personnes à qui cet accès a été donné peuvent utiliser ; une clé d'API ne peut pas recevoir cet accès à part. Avec une clé « App Manager », l'envoi seul marche, mais la signature échoue avec « Cloud signing permission error » (retours d'usage, Apple ne l'écrit pas en toutes lettres). C'est une question pour vous : voir § 10.
3. « Générer ». Sur la ligne de la clé, relever :
   - **ID de la clé** (« Key ID », 10 caractères, par exemple `ABC123DEFG`) ;
   - **ID de l'émetteur** (« Issuer ID », en haut de la liste, forme `69a6de70-…`).
4. « Télécharger » la clé : fichier `AuthKey_<Key ID>.p8`. **Apple ne le donne qu'une fois** : le garder dans un endroit sûr (gestionnaire de mots de passe). Perdu, il faut révoquer la clé et en créer une autre.
5. **Team ID** : [compte Apple Developer](https://developer.apple.com/account), « Membership details » (« Détails de l'adhésion »), ligne « Team ID » (10 caractères).

Cette clé n'est ni la clé APNs des notifications push (`NAUTILINK_APNS_*` du serveur, TODO-10.5) ni la clé de l'App Store Server API des achats (`NAUTILINK_APP_STORE_*` du serveur, onglet « Achats intégrés » des mêmes « Intégrations », TODO-10.6) : trois clés différentes.

## 4. Poser les secrets dans GitHub

Dépôt `gmoulard/NautiLink` sur GitHub : « Settings », « Secrets and variables », « Actions », bouton « New repository secret ». Un secret à la fois : « Name » exactement comme ci-dessous, « Secret » avec la valeur, puis « Add secret ».

| Name | Valeur |
|------|--------|
| `APPLE_TEAM_ID` | le Team ID (étape 3.5) |
| `APP_STORE_CONNECT_KEY_ID` | l'ID de la clé (étape 3.3) |
| `APP_STORE_CONNECT_ISSUER_ID` | l'ID de l'émetteur (étape 3.3) |
| `APP_STORE_CONNECT_KEY_P8` | **le contenu du fichier `.p8` en clair** : l'ouvrir avec un éditeur de texte (Bloc-notes, TextEdit), tout copier, lignes `-----BEGIN PRIVATE KEY-----` et `-----END PRIVATE KEY-----` comprises, et le coller tel quel. Le contenu encodé en base64 est aussi accepté. |

Le workflow écrit la clé dans `~/.appstoreconnect/private_keys/AuthKey_<Key ID>.p8` sur la machine de construction, le temps de l'étape, puis l'efface. Tant qu'un des quatre secrets manque, l'étape « App Store » s'affiche comme sautée (« Étape sautée : secrets absents : … ») sans faire échouer l'exécution.

## 5. Premier envoi

1. GitHub, onglet « Actions », workflow « Site GitHub Pages », « Run workflow » sur `main` (laisser la case « iphone » cochée), ou pousser un changement de `app/`.
2. Dans l'exécution, job « ios », étape « App Store (version signée envoyée à App Store Connect, D-194) » : elle se termine par « Version …, build … envoyée à App Store Connect ». Compter 10 à 20 minutes pour le job.
3. App Store Connect, « Apps », NautiLink, onglet « TestFlight » : le build apparaît « En traitement », puis prêt après **10 à 30 minutes** ; Apple envoie un e-mail. Pour l'essayer avant la soumission, l'ajouter à un groupe de testeurs internes (vous) et l'installer avec l'application TestFlight : c'est un essai privé, pas un TestFlight public ([D-194](../07-decisions.md#d-194)).

Un échec de cette étape ne bloque pas le site : l'IPA non signée est publiée quand même, et l'étape est marquée en échec dans le résumé de l'exécution. Messages courants :

| Message | Cause et remède |
|---------|-----------------|
| `Cloud signing permission error` | Clé sans le rôle « Admin » (§ 3). |
| `Your team has no devices from which to generate a provisioning profile` | Aucun iPhone enregistré (§ 1.5). |
| `No profiles for 'org.moulard.nautilink' were found` ou `doesn't support the Push Notifications capability` | Identifiant non enregistré ou sans les capacités du § 1.3. |
| `The bundle version must be higher than the previously uploaded version` | Build déjà envoyé avec ce numéro : relancer le workflow (nouveau numéro). |
| `Missing Compliance` dans TestFlight | Ne devrait plus arriver : `ITSAppUsesNonExemptEncryption` vaut « non » dans `app/ios/Runner/Info.plist` (chiffrement du système, HTTPS, seulement). |
| `Invalid Pre-Release Train` ou version refusée | La version de `app/pubspec.yaml` est déjà publiée sur l'App Store : changer de version. |

À chaque nouvelle création de certificat de développement par la machine de construction, Apple peut en garder un de plus dans « Certificates » ; si la limite est atteinte, révoquer les anciens certificats « Apple Development » créés par la clé (à constater au fil des envois).

## 6. Fiche App Store

App Store Connect, NautiLink, onglet « Distribution », version « 1.0 Prepare for Submission » (renommer la version en celle de `pubspec.yaml`, par exemple `0.5.5`). Les textes proposés ci-dessous sont des propositions à relire.

### 6.1 Textes

- **Sous-titre** (30 caractères au plus) : proposition « Sécurité en mer et journal » (26).
- **Texte promotionnel** (facultatif, 170 caractères) : proposition « Partagez votre position en mer avec vos proches, tenez votre journal de bord et déclenchez une alerte SOS. »
- **Description** (4 000 caractères au plus), proposition tirée du site : « NautiLink, le compagnon connecté du navigateur. Avant de partir, indiquez votre destination et les personnes à bord ; pendant la navigation, votre position est envoyée automatiquement à vos amis, même écran éteint ; ajoutez notes, photos et notes vocales au journal de bord ; en cas de problème, une alerte SOS prévient vos amis par e-mail et notification. Sur iPhone, tout passe par Internet : sans réseau, les envois sont gardés et partent au retour de la connexion. NautiLink ne remplace pas les moyens officiels de secours en mer (VHF canal 16, 196, balise de détresse). » La dernière phrase compte pour la relecture (§ 9).
- **Mots-clés** (100 caractères au plus, séparés par des virgules, sans espace) : proposition `voile,bateau,plaisance,navigation,sécurité,mer,SOS,position,suivi,journal de bord,marin` (87).
- **URL d'assistance** (obligatoire) : `https://nautilink.moulard.org/` (le site, section FAQ).
- **URL marketing** (facultative) : la même.
- **Copyright** : par exemple `2026 Guillaume Moulard`.

### 6.2 Captures d'écran

1 à 10 captures par taille, en PNG ou JPEG, sans transparence :

| Appareil | Taille | Pixels (portrait) |
|----------|--------|-------------------|
| iPhone 6,9 pouces (iPhone 16 Pro Max, 15 Pro Max…) | obligatoire | 1320 × 2868 (ou 1290 × 2796) |
| iPhone 6,5 pouces (iPhone 11 Pro Max, XS Max…) | demandée si la 6,9 pouces manque ; reprise automatiquement sinon | 1284 × 2778 (ou 1242 × 2688) |
| iPad 13 pouces | **obligatoire, car l'application se déclare aussi pour l'iPad** | 2064 × 2752 (ou 2048 × 2732) |

L'application se déclare aujourd'hui pour l'iPhone et l'iPad (`TARGETED_DEVICE_FAMILY = "1,2"` dans `app/ios/Runner.xcodeproj/project.pbxproj`). Apple essaie alors aussi l'application sur iPad et demande ses captures. Si l'iPad n'est pas prévu, on peut limiter à l'iPhone (`TARGETED_DEVICE_FAMILY = 1`) : non changé ici, c'est une question (§ 10). Les captures se font sur un vrai iPhone 6,9 pouces ou dans le simulateur d'Xcode (Mac nécessaire).

### 6.3 Confidentialité (« Confidentialité de l'app »)

- **URL de la politique de confidentialité** : obligatoire. Elle n'existe pas encore (RG-DON-03, TODO-8.3 : texte à rédiger et à faire relire par un juriste) : sans elle, la soumission est impossible. Question au § 10.
- **Données collectées** (« Commencer » puis cocher), proposition d'après [`02-regles-metier.md`](../02-regles-metier.md) et [`08-architecture.md`](../08-architecture.md). Pour toutes : « liées à l'identité de l'utilisateur » : oui ; « utilisées pour le suivi » (pistage publicitaire) : **non** ; finalité : « Fonctionnalités de l'app » seulement (pas de publicité, pas de statistiques d'usage, pas d'outil d'analyse ni de rapport de plantage).

| Catégorie Apple | Type | Pourquoi dans NautiLink |
|-----------------|------|-------------------------|
| Coordonnées | Nom, adresse e-mail, numéro de téléphone | Compte (RG-CPT-02) ; amis saisis par le navigateur, prévenus par e-mail ou SMS (aucun accès au carnet d'adresses de l'iPhone) |
| Localisation | Localisation précise | Positions de la navigation et du SOS (RG-IOS-08) |
| Contenu utilisateur | Photos ou vidéos | Photos du journal de bord et du bateau (RG-BAT-01) |
| Contenu utilisateur | Données audio | Notes vocales du journal |
| Contenu utilisateur | Autre contenu de l'utilisateur | Notes, destination, personnes à bord, fiche du bateau |
| Identifiants | Identifiant utilisateur | Compte du serveur |
| Identifiants | Identifiant de l'appareil | Identifiant du téléphone associé au bateau et jeton des notifications push (à garder si la question est posée ainsi) |
| Achats | Historique d'achat | Abonnement de 10 ans (RG-IOS-07) |

Pas de données de santé, financières (le paiement passe par Apple), de navigation web, d'historique de recherche, de contacts de l'appareil ni de données de diagnostic envoyées par l'application.

### 6.4 Classement par âge

Répondre « Aucun » ou « Non » à toutes les rubriques (violence, contenu sexuel, jeux d'argent, etc.). Sur les rubriques récentes : pas de navigation web libre (la seule page web affichée dans l'application est le mémo sécurité, embarqué), pas de messagerie publique ni de contenu partagé avec des inconnus (le journal n'est vu que des amis invités). Résultat attendu : **4+**.

### 6.5 Prix et disponibilité

- **Prix** : gratuit (0 €) ; l'abonnement s'achète dans l'application.
- **Disponibilité** : à choisir (par exemple France seule, ou tous les pays) : l'application est en français et en anglais.

### 6.6 Achat intégré

NautiLink, « Monétisation », « Achats intégrés », « + » :

- **Type** : **Non consommable**. Vérifié dans le code : l'application l'achète avec `buyNonConsumable` (`app/lib/reel/achats.dart`) ; il n'expire pas pour Apple, c'est le serveur qui compte les 10 ans (RG-ECO-06). Pas d'« abonnement auto-renouvelable ».
- **Nom de référence** : `Abonnement 10 ans`. **ID de produit** : `nautilink_abonnement_10_ans` (exactement, attendu par l'application et le serveur, `NAUTILINK_PRODUIT`).
- **Prix** : 15,00 € (choisir le prix de base en euros, Apple calcule les autres pays).
- **Localisation française** : nom affiché « Abonnement 10 ans », description « Navigations sans limite pendant 10 ans, sur tous vos appareils. »
- **Informations pour la relecture** : une capture de l'écran d'achat dans l'application et une phrase d'explication.
- Le premier achat intégré se soumet **avec** la version : dans la page de la version, section « Achats intégrés et abonnements », l'ajouter avant de soumettre.

### 6.7 Informations pour la relecture d'Apple

- **Connexion requise** : oui, l'application demande un compte. Apple exige un **compte de démonstration** (identifiant et mot de passe) qui fonctionne pendant toute la relecture, sur le serveur de production, avec un bateau et si possible une navigation terminée et un ami. Question au § 10.
- **Coordonnées** : nom, téléphone et e-mail pour qu'Apple puisse vous joindre.
- **Notes**, proposition : « NautiLink aide les plaisanciers à partager leur navigation avec des proches qu'ils ont eux-mêmes invités. La localisation est demandée "Pendant l'utilisation de l'app" seulement ; le mode d'arrière-plan "location" sert uniquement pendant une navigation que l'utilisateur démarre à l'écran ("Démarrer navigation") et s'arrête à "Terminer la navigation" : les positions sont envoyées à ses amis pendant que l'écran est éteint. L'alerte SOS prévient seulement les amis choisis par l'utilisateur (e-mail et notification) ; ce n'est pas un service d'urgence et l'application renvoie vers les moyens officiels (VHF canal 16, 196). Pour essayer : se connecter avec le compte de démonstration, ouvrir "Démarrer navigation", puis verrouiller l'écran. » ([D-54](../07-decisions.md#d-54), RG-IOS-08).
- **Pièce jointe** (facultative) : une courte vidéo de l'iPhone qui démarre une navigation et continue écran éteint ; Apple la demande souvent pour la localisation en arrière-plan.

## 7. Soumettre à la relecture

1. Dans la page de la version : section « Build », « Ajouter un build » et choisir le build reçu à l'étape 5.
2. Vérifier que l'achat intégré est joint (§ 6.6).
3. « Ajouter pour vérification », puis « Soumettre à la vérification ».
4. Choisir la publication : « Publier automatiquement cette version » ou « manuellement » après l'acceptation.
5. Réponse d'Apple en général en 1 à 3 jours, dans « Centre de résolution » en cas de refus : y répondre ou corriger puis renvoyer un build (relancer le workflow).

Les versions suivantes : changer la version dans `app/pubspec.yaml`, pousser, puis dans App Store Connect « + » à côté de « iOS App », nouvelle version, choisir le build et soumettre.

## 8. Une fois l'application acceptée

1. Relever l'adresse de l'App Store : App Store Connect, NautiLink, « Distribution », lien « Voir sur l'App Store » ; forme `https://apps.apple.com/fr/app/nautilink/id1234567890` (les chiffres après `id` sont l'« Apple ID » de l'application, dans « Informations sur l'app »).
2. La donner pour mettre à jour le site (TODO-10.7) : elle s'écrit seule sur une ligne de `site/app-store.txt` (les lignes qui commencent par `#` sont des commentaires). Au prochain passage du workflow, les blocs « Télécharger dans l'App Store » de `site/index.html` (marqués `<!-- app-store:debut -->` et `<!-- app-store:fin -->`, dans « Install iPhone » et dans `#iphone`) sont montrés avec ce lien ; tant que le fichier ne donne pas d'adresse, ils sont retirés des pages publiées et rien ne change à l'écran. Une adresse qui ne commence pas par `https://apps.apple.com/` fait échouer la publication du site, pour éviter un lien faux.
3. Le lien est aujourd'hui un bouton texte « Télécharger dans l'App Store ». Pour le badge officiel « Télécharger dans l'App Store », le prendre sur le [site des outils marketing d'Apple](https://tools.applemarketingtools.com/) (badge français, noir), le copier tel quel dans `site/` (Apple interdit de le modifier) et l'utiliser comme image du lien.
4. Ensuite, à décider : garder ou retirer l'IPA non signée et la section Sideloadly du site ([D-194](../07-decisions.md#d-194) : le lien de l'App Store la remplace).

## 9. Risques de refus connus

| Règle d'Apple | Risque pour NautiLink | Parade proposée |
|---------------|-----------------------|-----------------|
| 5.1.5 : les API de localisation ne doivent pas servir à des services d'urgence ([étude](localisation-arriere-plan-iphone.md#3-règles-de-lapp-store)) | Le SOS (RG-IOS-03) peut être lu comme un service d'urgence. | Présenter l'alerte comme envoyée à des proches choisis, pas aux secours ; renvoyer aux moyens officiels dans la description, les notes et l'application (mémo sécurité). Décision encore ouverte dans l'étude. |
| 2.5.4 : modes d'arrière-plan à leur seul usage | Mode `location` déclaré. | Notes du § 6.7, vidéo ; autorisation « Pendant l'utilisation » seulement (D-54). |
| 5.1.1 (i) : politique de confidentialité | Absente aujourd'hui (TODO-8.3). | Bloquant : à rédiger avant la soumission. |
| 5.1.1 (v) : suppression du compte | Une application qui permet de créer un compte doit permettre de le supprimer depuis l'application. Aucune règle de suppression du compte n'existe aujourd'hui dans la spécification ni dans l'application. | Question au § 10. |
| 2.1 : application complète, compte de démonstration | Connexion obligatoire. | Compte de démonstration (§ 6.7). |
| 2.2 : pas de version bêta, démonstration ou essai sur l'App Store | L'application et le site affichent un avertissement « version bêta » ([avertissement](../textes/avertissement-beta.md)). | À relire avant la soumission ; Apple réserve les bêtas à TestFlight. |
| 3.1.1 : achats numériques par l'achat intégré seulement | L'application ouvre la section « Tarifs » du site, qui peut mener au paiement Web (Stripe). | Vérifier que l'application iPhone ne renvoie pas vers un autre moyen de paiement que l'achat intégré. |
| 4.8 : connexion avec Apple quand une connexion tierce est proposée | Google est proposé. | Déjà fait : « Se connecter avec Apple » (RG-CPT-02) ; serveur : `NAUTILINK_APPLE_CLIENTS` doit contenir `org.moulard.nautilink`. |
| 2.3 : fiche exacte | Fonctions annoncées et non ouvertes (notifications push, achat). | Ne décrire que ce qui marche dans le build soumis. |

## 10. Questions à trancher avant la soumission

Non tranchées ici ([D-194](../07-decisions.md#d-194) ne les couvre pas) :

1. iPad : limiter l'application à l'iPhone (`TARGETED_DEVICE_FAMILY = 1`, pas de captures iPad, pas d'essai sur iPad par Apple) ou garder l'iPad ?
2. Politique de confidentialité : adresse et texte (RG-DON-03, TODO-8.3), obligatoires pour soumettre.
3. Compte de démonstration pour la relecture d'Apple : lequel, sur quel serveur, avec quelles données ?
4. Rôle de la clé d'API : « Admin » (signature gérée par Apple) ou une autre manière de signer (certificat et profil de distribution posés à la main en secrets, clé « App Manager ») ?
5. Suppression du compte depuis l'application (règle 5.1.1 (v) d'Apple) : à ajouter à la spécification ?
6. Présentation du SOS face à la règle 5.1.5 (question déjà posée par l'[étude](localisation-arriere-plan-iphone.md#6-questions-pour-lutilisateur-non-tranchées)) et mention « bêta » (règle 2.2).
