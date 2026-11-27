# NautiLink — Règles graphiques des interfaces

Statut : relevé du 2026-11-27 des règles appliquées par les trois interfaces, d'après l'identité graphique du 2026-11-26 ([D-157](07-decisions.md#d-157)) ; écarts encore ouverts : §11.

Ce document dit **comment** l'identité graphique est appliquée à chaque interface : couleurs par rôle, typographie, composants, mise en page, thème sombre, accessibilité. Il ne la redéfinit pas :

- la marque, le logo, les couleurs de la marque et les valeurs de l'identité graphique sont dans [05-identite-marque.md](05-identite-marque.md) (§5, §6 et surtout §15) ;
- l'accessibilité exigée est [RG-PRM-05](02-regles-metier.md#rg-prm-05) (WCAG 2.2 AA) ; l'affichage sur téléphone de l'Application web est [RG-WEB-04](02-regles-metier.md#rg-web-04) ;
- en cas d'écart, l'ordre de priorité de `CLAUDE.md` s'applique : une règle métier ou une décision l'emporte sur ce document.

## 1. Interfaces concernées

| Interface | Fichier de référence | Thème sombre |
|-----------|----------------------|--------------|
| Site de présentation (GitHub Pages) | `site/style.css` ; `site/securite.html` a ses propres styles (copié dans l'application, [D-161](07-decisions.md#d-161)) | selon le réglage de l'appareil (`prefers-color-scheme`) |
| Application web et espace administrateur | `server/web/static/style.css` | selon le réglage de l'appareil |
| Application mobile (Android, iPhone, démonstration Web) | `app/lib/theme.dart` (`NlColors`, `nlTheme`) | selon le réglage du téléphone |

Une valeur graphique se change d'abord dans ce fichier de référence, jamais en dur dans une page ou un écran (§11 liste les exceptions encore présentes). La démonstration V0 figée garde le design « Radar de pluie » ([05-identite-marque.md §14](05-identite-marque.md), D-144) et n'est pas couverte ici.

## 2. Principes

1. **Une seule identité** pour les trois interfaces ([D-157](07-decisions.md#d-157)) : ciel et mer, cartes blanches arrondies, boutons turquoise en pilule, titres bleu marine.
2. **Couleurs réservées** ([05-identite-marque.md §6](05-identite-marque.md#6-couleurs)) : le turquoise signale une action ; le rouge, le SOS et les alertes, jamais un décor ; l'orange, le repère GPS du logo.
3. **Utilisable à bord** : grandes zones à toucher, contrastes AA, lisible au soleil, rien ne dépend de la seule couleur (un état a aussi un texte ou une icône).
4. **Clair et sombre** : chaque couleur a sa valeur dans les deux thèmes ; aucune couleur n'est fixée pour un seul thème, sauf le décor des photos et des dessins (§9).

## 3. Couleurs par rôle

Valeurs : [05-identite-marque.md §15](05-identite-marque.md#15-identite-graphique-du-2026-11-26). Le tableau donne le nom de la variable dans chaque interface.

| Rôle | Site (`--…`) | Application web (`--…`) | Application mobile (`NlColors.…`) |
|------|--------------|--------------------------|-----------------------------------|
| Fond de page (bas du dégradé) | `page` | `fond` | `sky` / `skyDark` |
| Haut du dégradé ciel | `sky` | `ciel` | `skyTop` / `skyTopDark` |
| Cartes, champs, surfaces | `surface` | `surface` | `white` / `surfaceDark` (`colorScheme.surface`) |
| Titres, texte | `fg` | `texte` | `ink` / `inkDark` |
| Texte secondaire, aides | `muted` | `texte2` | `ink2` |
| Filets, séparateurs, bordures | `line` | `filet` | `line` / `lineDark` |
| Fond des boutons d'action | `action` | `bouton` | `button` / `buttonDark` (`colorScheme.primary`) |
| Texte sur un bouton d'action | `action-fg` | `sur-action` | `white` / `onAccentDark` |
| Liens, icônes des fonctions | `link`, `icon` | `action` | `accent` / `accentDark` |
| Traits, soulignés, décors turquoise | `teal` | — | `turquoise` |
| SOS, alerte | `alert` | `sos` | `alert` / `alertDark` (`colorScheme.error`) |
| Avertissement bêta | `alert-bg`, `alert-text`, `alert-line` | `beta`, `sur-beta` | `betaBg`, `betaFg` (et `…Dark`) |
| Ombre | `shadow` | `ombre` | `shadowColor` du thème |

Règles :

- **Boutons d'action** : fond turquoise foncé `#0B7F86` en thème clair, sur les trois interfaces ; le turquoise `#17A2B0` ne donne que 3,1:1 avec du texte blanc et reste aux traits, soulignés, vagues et décors ([D-161](07-decisions.md#d-161), RG-PRM-05). Thème sombre : `#2BC0C6`, texte `#08172A`.
- **Survol** d'un bouton : un ton plus foncé (site : `action-hover`) ou légèrement éclairci (Application web : `filter: brightness(1.06)`) ; jamais une autre teinte.
- **Couleurs propres au site**, hors §15 : mer du bandeau et vagues (`sea-1` à `sea-3`, `wave-1`, `wave-2`) et pied de page bleu `#0D4F8C`, texte `#E6F0F5` (7,2:1) ; elles ont aussi leurs valeurs sombres dans `site/style.css`.
- **Sponsor SRT** : bleu `#1E3296` et jaune `#F8D818` uniquement dans la mention du sponsor ([05-identite-marque.md §13](05-identite-marque.md#13-sponsor)) ; en thème sombre, texte de la mention en couleur de texte.
- **Espace administrateur** : en-tête plein en couleur de texte (bleu marine en clair), marque et menu en couleur de fond, pour qu'on ne le confonde pas avec l'Application web.

## 4. Typographie

Inter partout ([05-identite-marque.md §15](05-identite-marque.md#15-identite-graphique-du-2026-11-26)) ; repli `system-ui, -apple-system, "Segoe UI", Roboto, sans-serif` sur le Web. Chargement : application mobile, police embarquée dans `app/assets/fonts/` (licence OFL) ; site, Google Fonts (Inter 400 à 800 et 500 italique) ; Application web, aucune police chargée : Inter si elle est installée sur l'appareil, sinon la police du système (§11).

| Usage | Graisse | Site | Application web | Application mobile |
|-------|---------|------|-----------------|--------------------|
| Texte courant | 400 | 17 px (16 px sous 560 px), interligne 1,6 | 16 px (`1rem`), interligne 1,5 | taille Material par défaut |
| Titre de page (`h1`) | 800, resserré (−0,015 à −0,02 em) | 1,8 à 2,5 rem (pages de texte), 1,9 à 3,2 rem (accueil) | 1,8 rem (1,5 rem sous 720 px) | `headlineSmall` 24 |
| Titre de section (`h2`) | 800 | 1,35 à 2,05 rem | 1,2 rem | `titleLarge` 20 |
| Sous-titre (`h3`) | 800 / 700 | 1,05 à 1,1 rem | 1,05 rem | `titleMedium` 16, 700 |
| Bouton | 700 (600 sur l'Application web) | taille du texte, 1,1 rem pour `.large` | 1 rem, 1,05 rem pour `.pleine` | 17 (plein), 16 (contour) |
| Nom « NautiLink » de l'en-tête | 800 | 2,1 rem (1,7 rem sous 560 px) | 1,6 rem ; 2 rem sur les écrans d'accès | `displayStyle` |
| Signature | 500 italique | 1 rem | 0,9 rem | — |
| Mentions, aides, pied de page | 400 / 600 | 0,85 à 0,92 rem | 0,85 à 0,9 rem ; ligne de construction 0,75 rem | `bodySmall`, 11 pour la ligne de construction |

- Titres équilibrés sur plusieurs lignes (`text-wrap: balance`) sur le site.
- Chiffres : chiffres tabulaires pour les chronomètres et durées de l'application ; titres du log de nav de l'Application web en police à chasse fixe du système.
- Pas de texte en capitales, sauf les petites étiquettes (« Version bêta », surtitres `.kicker` du site), espacées de 0,06 à 0,12 em.

## 5. Formes, espacements, ombres

| Élément | Règle |
|---------|-------|
| Cartes | coins de 16 px (Application web, application mobile) à 18 px (site) ; filet de 1 px ; ombre douce (`0 6px 20px` à `0 8px 24px`, bleu marine à 8-9 % ; noir à 35 % en sombre) |
| Champs | coins de 12 px (Web) ou 14 px (application) ; filet de 1 px ; fond de surface |
| Boutons | en pilule (rayon 999 px, `StadiumBorder`) |
| Messages, photos, carte | coins de 8 px |
| Écrans d'accès (connexion, création du compte, mot de passe oublié) | carte de 440 px au plus, coins de 24 px |
| Logo de l'en-tête | carré arrondi : 64 px (site, 52 px sous 560 px), 44 px (Application web), 72 px (écrans d'accès) ; rayon de 12 à 16 px |
| Largeur du contenu | site : 1140 px (820 px pour le texte) ; Application web : 860 px |
| Marges latérales | 16 px au moins (12 px sur téléphone dans l'Application web), zones sûres de l'écran respectées |
| Espacement | multiples de 4 px : 8, 12, 16, 20, 24 px entre blocs ; 16 px entre cartes |

## 6. Composants

### 6.1 En-tête

- Logo devant « NautiLink » en gras, signature en italique ; site : mention « Version bêta » en étiquette rouge sur rose.
- Site : fond blanc, menu avec icône maison, page courante soulignée en turquoise (3 px), bouton « Télécharger » ; fixé en haut au-dessus de 820 px seulement ([D-161](07-decisions.md#d-161), [D-171](07-decisions.md#d-171)).
- Application web : barre blanche translucide floutée, fixée en haut ; sous 720 px, menu replié derrière « Menu » ([RG-WEB-04](02-regles-metier.md#rg-web-04)).
- Application mobile : barre d'application blanche (ciel sombre en thème sombre), sans ombre au repos, filet en bas, titre à gauche.

### 6.2 Boutons

| Type | Apparence | Usage |
|------|-----------|-------|
| Action principale | fond turquoise foncé, texte blanc, ombre turquoise légère | l'action attendue de l'écran ; une seule par zone |
| Secondaire | fond de surface, filet, texte couleur de lien (Web) ou de texte (application) | les autres actions |
| Bleu marine (site, `.navy`) | fond couleur de texte, texte couleur de surface | action sur un fond turquoise ou photo |
| Danger (Application web, `.danger`) | contour rouge de 2 px, texte rouge, fond transparent | suppression, mise à la corbeille |
| SOS | fond rouge, texte blanc gras, icône SOS | « Envoyer un SOS » uniquement (RG-SOS-01) |

- Hauteur minimale : 44 px (Application web), 48 px (site, bouton pleine largeur des écrans d'accès), 56 px (bouton plein de l'application), 52 px (bouton à contour), 64 px (SOS de l'application).
- Libellé : verbe à l'infinitif, entre guillemets français dans les documents (« Démarrer navigation »).
- Focus clavier visible : contour de 3 px couleur de lien, décalé de 2 px.

### 6.3 Cartes

Fond de surface, coins arrondis, ombre douce (§5). Une carte regroupe un sujet ; titre en `h2`. Site : cartes de l'accueil avec photo découpée dans l'étude ([D-171](07-decisions.md#d-171)) ; carte « SOS » marquée d'un filet rouge de 4 px en haut.

### 6.4 Champs de formulaire

- Libellé au-dessus, en 600 ; aide dessous en texte secondaire.
- Hauteur de 44 px au moins (48 px avec icône sur les écrans d'accès) ; icône à gauche dans le champ, bouton « œil » de 44 px à droite des mots de passe.
- Cases à cocher de 20 px, libellé cliquable sur toute la ligne.

### 6.5 Messages et alertes

- Information : cadre de 2 px turquoise foncé ; erreur : cadre de 2 px rouge ; toujours avec un texte qui dit l'état.
- Alerte SOS : filet rouge de 4 px à gauche ; dans l'application, carte rose `#FBE9E9` et icône rouge (« Aucun contact SOS coché », par exemple ; §11).
- Annonce de l'administrateur ([RG-ADM-06](02-regles-metier.md#rg-adm-06)) : carte à cadre de 2 px couleur de lien.

### 6.6 Avertissement bêta

Texte rouge foncé sur rose, précédé de ⚠ ([05-identite-marque.md §15](05-identite-marque.md#15-identite-graphique-du-2026-11-26)) ; contraste 5,6:1 en clair, 9,5:1 en sombre. Site : en bas de chaque page, avec la mention du sponsor à droite ([D-161](07-decisions.md#d-161)) ; Application web : bandeau en haut de page ; application mobile : bandeau de démonstration en haut (`DemoBanner`).

### 6.7 Sponsor

Mention et guidon de la SRT : [05-identite-marque.md §13](05-identite-marque.md#13-sponsor) et [D-131](07-decisions.md#d-131). Application mobile : bandeau sur le fond de l'écran, filet jaune `#F8D818` de 3 px au-dessus, guidon de 30 px ; site : guidon de 48 px. Le guidon n'est jamais recoloré.

### 6.8 Pied de page

- Vagues turquoise et bleues au-dessus du pied de page sur les trois interfaces (`Vagues` dans l'application, SVG en fond sur le Web).
- Contenu : [D-128](07-decisions.md#d-128) et [D-149](07-decisions.md#d-149) (droits, lien vers le site, version, build, commit) en petit texte secondaire.

### 6.9 Tableaux et listes

Filet de 1 px entre les lignes, pas de cadre ; intitulés à gauche. Sous 720 px, tableaux empilés avec l'intitulé de chaque colonne devant la valeur ([RG-WEB-04](02-regles-metier.md#rg-web-04)). Journal de bord : un filet de 3 px à gauche de chaque événement, couleur de lien pour le début et la fin, rouge pour le SOS.

### 6.10 Icônes

Icônes au trait, simples, en SVG en ligne sur le Web ([D-161](07-decisions.md#d-161)), icônes Material dans l'application ; couleur de lien (`icon`) ou couleur du texte voisin. Taille : 1,15 em dans le texte, 36 px dans la rangée des fonctions du site. Une icône seule a un nom accessible.

## 7. Carte d'une navigation

Fond OpenStreetMap et balisage OpenSeaMap avec leurs mentions de source ([RG-NAV-29](02-regles-metier.md#rg-nav-29)). Couleurs du tracé et des points, dans `server/web/static/style.css` (`svg.carte`, `.pastille`) ; elles sont les mêmes en clair et en sombre (la carte reste claire) :

| Élément | Couleur |
|---------|---------|
| Mer (sans dalle) | `#AAD3DF` |
| Tracé, positions | bleu `#0E6BA8`, trait de 3 px arrondi |
| Départ | turquoise `#13A6AD` |
| Arrivée, dernière position | bleu marine `#0E2A47` |
| Événement (note, photo, note vocale) | jaune `#F2C14E` |
| SOS | rouge `#D94343` |
| Incident | orange `#E8833A` (à trancher : [Q-94](06-questions-ouvertes.md#q-94)) |

Chaque point a un contour blanc de 2 px ; une légende à pastilles accompagne la carte. La carte tient dans la largeur de l'écran, coins de 8 px.

## 8. Mise en page et tailles d'écran

| Interface | Points de rupture | Ce qui change |
|-----------|-------------------|---------------|
| Site | 980 px, 820 px, 560 px | rangée des six fonctions sur 6, 3 puis 2 colonnes ; cartes et blocs sur une colonne ; en-tête centré et non fixé ; logo et nom réduits |
| Application web | 720 px | menu replié, tableaux empilés, marges de 12 px, zones à toucher de 44 px ([RG-WEB-04](02-regles-metier.md#rg-web-04), [D-162](07-decisions.md#d-162)) |
| Application mobile | — | colonne unique ; boutons pleine largeur ; pied de page en fin de page (vraie application) ou fixé en bas (démonstration) |

Rien n'est plus large que l'écran : images, cartes, vidéos et longs textes (`overflow-wrap: anywhere`) se plient à la largeur.

## 9. Décor

- Fond des écrans : dégradé ciel du haut (`skyTop`) vers le fond de page, sur 45 % de la hauteur (application) ou 360 px (Application web).
- Site : bandeau d'accueil avec la photo de mer et de voilier ([D-170](07-decisions.md#d-170)), voile claire à gauche pour la lisibilité du titre, titre et signature en bleu marine dans les deux thèmes (la photo ne change pas).
- Écrans d'accès de l'Application web : dessin de ciel, mer et voilier en SVG ; ses couleurs ont une variante sombre.
- Le décor ne porte jamais d'information ; pas de fausse donnée « en direct ».

## 10. Accessibilité

Exigence : [RG-PRM-05](02-regles-metier.md#rg-prm-05). Contrastes relevés (texte normal : 4,5:1 au moins ; grand texte, 24 px ou 19 px gras : 3:1) :

| Couple | Thème clair | Thème sombre |
|--------|-------------|--------------|
| Texte sur surface | 14,2:1 | 11,3:1 |
| Texte secondaire sur surface | 6,2:1 | 6,2:1 |
| Lien sur surface | 5,7:1 | 5,5:1 |
| Texte de bouton sur bouton d'action | 4,8:1 | 8,1:1 |
| Texte blanc sur SOS | 4,3:1 (grand texte seulement) | 3,5:1 (grand texte seulement) |

- Le SOS rouge n'est lisible en blanc qu'en grand texte gras : le bouton SOS de l'application (19 px, gras) l'est ; celui de l'Application web (16 px) ne l'est pas (§11).
- Zones à toucher : 44 × 44 px au moins.
- Focus visible sur tous les éléments actifs (§6.2) ; texte masqué pour les lecteurs d'écran (`.masque`, `.visually-hidden`) plutôt qu'absent.
- Textes agrandis : tailles en `rem` sur le Web ; aucune hauteur fixe qui couperait un texte agrandi.
- Animations : défilement doux désactivé quand l'appareil demande moins d'animations (`prefers-reduced-motion`).

## 11. Écarts constatés le 2026-11-27

À corriger (TODO-3.21) :

1. **Couleurs en dur dans l'application mobile** : rose `#FBE9E9` (alertes, `navigation.dart`, `navigation_reel.dart`), bleu pâle `#DCEFF8` (zones photo et carte), `#DCEFF3` et `#B9DCE3` (fond de carte du tableau de bord), sans variante sombre : à passer dans `NlColors`.
2. **Bouton SOS de l'Application web** : rouge `#D94343` fixé en dur, aussi en thème sombre, et texte de 16 px (contraste 4,3:1, sous l'AA du texte normal) : à passer en variable `--sos` et en grand texte gras, comme l'application.
3. **Police de l'Application web** : Inter n'est pas chargée ; la plupart des appareils affichent la police du système.
4. **Couleurs de la carte** (§7) : reprises du design « Radar de pluie » (`#0E6BA8`, `#0E2A47`, `#13A6AD`) et fixées en dur ; la pastille « incident » est orange alors que l'orange est réservé au repère GPS du logo ([D-98](07-decisions.md#d-98)) : [Q-94](06-questions-ouvertes.md#q-94).
