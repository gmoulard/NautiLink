# NautiLink — Identité de marque et charte graphique

Statut : identité définie, logo validé avec son repère GPS orange ([D-98](07-decisions.md#d-98)) ; fichiers vectoriels, icônes et déclinaisons produits, à valider (TODO-8.1, §5.5).

![Proposition de logo NautiLink](assets/logo-nautilink.png)

*Logo validé ([D-98](07-decisions.md#d-98)) : [assets/logo-nautilink.png](assets/logo-nautilink.png) (image d'origine) ; fichiers vectoriels et déclinaisons : §5.5.*

## 1. La marque

NautiLink est une marque de navigation de plaisance, de partage de position et de sécurité. Elle représente le lien entre le navigateur, son bateau, sa position en mer, et ses proches qui suivent sa navigation.

Elle doit inspirer confiance, simplicité, modernité et sérénité.

## 2. Nom

**NautiLink** : *Nauti* (l'univers nautique) + *Link* (le lien, le partage). Toujours écrit NautiLink, avec N et L majuscules.

## 3. Signature

**Your sea, your safety, your story.**

- *Your sea* : la liberté de naviguer.
- *Your safety* : la sécurité et le partage de position avec les proches.
- *Your story* : la mémoire des navigations et le journal de bord.

La signature reste en anglais, y compris dans les supports en français.

## 4. Positionnement

NautiLink est le compagnon connecté du navigateur : navigation de plaisance, partage de position, lien avec les proches, sécurité, suivi des navigations, journal de bord numérique.

NautiLink ne se présente pas comme une simple application GPS ou de cartographie. Sa valeur est de rapprocher le navigateur de ceux qui comptent pour lui, tout en gardant une trace de ses navigations.

## 5. Logo

### 5.1 Idée

*Plusieurs personnes peuvent savoir où tu es.* Le bateau et le navigateur sont au centre ; autour, les proches qui suivent sa position.

### 5.2 Éléments

Un bateau (le navigateur), un repère GPS (sa position), plusieurs silhouettes (les suiveurs), des ondes ou lignes de connexion (le partage). Éviter un voilier ou une boussole seuls, qui ne traduisent pas le partage.

### 5.3 Style

Moderne, simple, reconnaissable, lisible en petit, adapté à une icône Android et iPhone et au Web, lisible sur fond clair comme sur fond sombre.

### 5.4 Déclinaisons à produire

1. Logo complet : symbole et nom.
2. Version avec la signature.
3. Symbole seul pour les icônes Android et iPhone.
4. Version monochrome.
5. Version pour fond sombre.
6. Version pour fond clair.

### 5.5 Fichiers

Dans [`assets/logo/`](assets/logo/), produits par [`generer.py`](assets/logo/generer.py) (redessin vectoriel de l'image validée ; textes convertis en tracés, polices Montserrat ExtraBold Italic et Open Sans Medium Italic sous licence OFL dans `assets/logo/polices/`) :

| Fichier | Contenu |
|---------|---------|
| `nautilink-icone.svg` | Logo validé complet, sur son carré arrondi dégradé |
| `nautilink-symbole-<variante>.svg` | Symbole seul (§5.4, point 3) |
| `nautilink-logo-<variante>.svg` | Symbole et nom (point 1) |
| `nautilink-logo-signature-<variante>.svg` | Symbole, nom et signature (point 2) |
| `png/` | Rendus PNG des fichiers ci-dessus (1024 px de large) |
| `icones/` | Sources et rendus des icônes : Android (avant-plan, arrière-plan, monochrome 432 px), Google Play 512 px, iPhone 1024 px (normale, sombre, teintée) |

Variantes : `sombre` (couleurs d'origine, pour fond sombre), `clair` (pour fond clair), `monochrome` (bleu marine `#082B46`), `monochrome-blanc` (blanc, pour fond sombre ou photo).

Icônes du prototype : `app/android/app/src/main/res/mipmap-*` (icône classique, icône adaptative et icône monochrome Android 13), `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `app/web/` (favicon, icônes du manifeste).

Choix graphiques faits sans décision, à valider (TODO-8.1) :

- Icônes : symbole seul, sans nom ni signature (illisibles en petit), sur le dégradé bleu du logo d'origine, aussi pour l'arrière-plan de l'icône adaptative Android.
- Version claire : le blanc devient bleu marine `#082B46`, le cyan de « Link », du souligné et des vagues devient turquoise `#13A6AD` (le cyan est illisible sur blanc), les ondes autour du repère sont en bleu `#0E6BA8` ; le repère reste orange.
- Versions monochromes : le point blanc du repère devient un trou ; un filet vide sépare la coque et les vagues.
- Icônes iPhone sombre et teintée (iOS 18) : produites dans `assets/logo/icones/`, pas encore déclarées dans `Contents.json` (format Flutter gardé tel quel) ; à brancher avec l'application iPhone (LOT-16).
- Le symbole reste détaillé : en très petit (favicon, 20 à 29 px), les suiveurs et les ondes se lisent mal.

## 6. Couleurs

| Couleur | Code | Utilisation |
|---------|------|-------------|
| Bleu marine | `#082B46` | Couleur principale, fonds, titres, navigation |
| Turquoise | `#13A6AD` | Boutons et éléments interactifs |
| Aqua | `#7EDDE4` | Éléments secondaires et accents |
| Blanc | `#FFFFFF` | Fonds, textes sur fond sombre |
| Gris clair | `#F2F5F7` | Fonds secondaires, séparateurs |
| Rouge alerte | `#D94343` | SOS et alertes importantes uniquement |
| Orange repère | `#F89D29` | Repère GPS du logo uniquement ([D-98](07-decisions.md#d-98)) |

- Le bleu marine (mer, confiance, sécurité) domine.
- Le turquoise (connexion, partage) est réservé aux actions.
- Le rouge est réservé au SOS et aux alertes ; jamais décoratif.

Couleurs du thème sombre : §14 ([D-97](07-decisions.md#d-97)). L'orange est réservé au repère GPS du logo ([D-98](07-decisions.md#d-98)).

## 7. Typographie

- **Montserrat SemiBold** : titres, éléments de marque.
- **Inter Regular** : texte courant.
- **Inter Medium** : boutons, informations importantes.

## 8. Style des interfaces

- Thème clair : fonds blancs ou gris très clair, bleu marine pour titres et zones principales.
- Thème sombre : couleurs du §14 ([D-97](07-decisions.md#d-97)).
- Turquoise pour les actions, rouge pour le SOS.
- Icônes simples, boutons assez grands pour une utilisation à bord.
- Cartes et informations GPS clairement présentées (Web).

## 9. Ton

Simple, rassurant, direct, moderne, positif, axé sur la liberté et la sécurité. Éviter le jargon technique et les messages anxiogènes, sauf pour le SOS qui doit être explicite.

## 10. Présentation commerciale

> NautiLink est votre compagnon connecté de navigation.
>
> Que vous naviguiez en voilier ou en bateau à moteur, NautiLink vous permet de partager votre position avec vos proches, de suivre vos navigations, de transmettre des informations importantes et de conserver un journal de bord complet.
>
> Grâce à ses applications Android et iPhone et à sa plateforme Web, NautiLink rapproche le navigateur de ceux qui comptent pour lui.
>
> Naviguez. Partagez. Gardez une trace.

## 11. Messages clés

- **Naviguez en toute liberté.** Profitez de vos sorties en mer et gardez une trace de vos navigations.
- **Restez connecté à vos proches.** Partagez votre position et laissez plusieurs personnes suivre votre navigation.
- **Gardez le souvenir de chaque sortie.** Retrouvez vos positions, notes, photos et événements dans votre journal de bord.

## 12. À finaliser

Validation des fichiers du logo et des choix graphiques du §5.5 : TODO-8.1. Voir aussi [Q-26](06-questions-ouvertes.md#q-26) (disponibilité juridique du nom, domaines, réseaux sociaux).

## 13. Sponsor

NautiLink est sponsorisée par la SRT ([srtoulon.fr](https://srtoulon.fr/), [D-68](07-decisions.md#d-68)).

- Mention : « Sponsorisée par la SRT », toujours accompagnée du guidon de la SRT ([`site/assets/sponsor-srt.png`](../site/assets/sponsor-srt.png)).
- Place : bandeau blanc à filet jaune en bas de chaque page du site, et en bas de l'écran d'accueil de l'application.
- Couleurs du guidon : bleu `#1E3296`, jaune `#F8D818`, rouge des ancres. Elles servent au bandeau sponsor ; leur usage comme base de toute l'identité NautiLink est la proposition 11 de la [planche de designs](../site/designs/index.html), à choisir ([TODO-3.9](TODO.md)).
- Le guidon reste la propriété de la SRT : ne pas le modifier ni le recolorer.

## 14. Design du site : « Radar de pluie »

Choisi le 2026-11-24 ([D-69](07-decisions.md#d-69)) parmi les [variantes météo](../site/designs/meteo.html) (n° 8). Appliqué au site de présentation (`site/style.css`, bloc « Radar de pluie ») et à l'application ([D-70](07-decisions.md#d-70) : `app/lib/theme.dart`, polices dans `app/assets/fonts/` sous licence OFL). Maquettes : [`site/designs/app.html`](../site/designs/app.html).

| Rôle | Valeur |
|------|--------|
| Fond du bandeau d'accueil et du menu | ciel `#EAF4FB` |
| Texte | encre `#0E2A47` |
| Actions, liens, accents | bleu `#0E6BA8` |
| Échos radar (décor) | vert, jaune, rouge en dégradés transparents |
| Titres | Space Grotesk |
| Petites mentions, signature | IBM Plex Mono |

Pas de fausse donnée météo « en direct » sur le site : les échos radar restent un décor.

Thème sombre, validé le 2026-11-25 ([D-97](07-decisions.md#d-97)) :

| Rôle | Valeur |
|------|--------|
| Fond de la page (Web) | `#08172A` |
| Fond des écrans de l'application, bandeaux | ciel sombre `#0F2438` |
| Cartes, champs, surfaces | `#15314D` |
| Texte | `#E3EEF7` |
| Texte secondaire | `#9BB4C9` |
| Filets, séparateurs | `#24476A` |
| Actions, liens | bleu éclairci `#5AAEE6`, texte `#08172A` dessus |
| SOS | `#E35D5D` |
| Bandeau bêta | `#F2C14E`, inchangé |

Bandeau du sponsor SRT : sur le fond de l'application, en thème clair comme en sombre (filet jaune `#F8D818` au-dessus ; texte bleu SRT `#1E3296` en clair, texte `#E3EEF7` en sombre). Sous la mention du sponsor, un petit lien souligné « Site de NautiLink » vers le site de présentation (TODO-3.13).

