# Données du SHOM sur la carte de l'Application web

Étude de [Q-23](../06-questions-ouvertes.md#q-23) (TODO-9.1) : quelles données du SHOM peuvent s'afficher, gratuitement, sur la carte de la page d'une navigation, au-dessus du fond OpenStreetMap et du balisage d'OpenSeaMap ([RG-NAV-29](../02-regles-metier.md#rg-nav-29)).

> **État** : rédigé le 2026-11-27 à partir de la fiche de métadonnées du produit RasterMarine, de la description du service WMTS du SHOM et de deux essais sans clé sur ce service. Les tarifs et la licence de chaque couche thématique restent **à vérifier** auprès du SHOM avant toute décision.

## 1. Service du SHOM

- Service de tuiles WMTS public : `https://services.data.shom.fr/INSPIRE/wmts`, en projection Web Mercator (EPSG:3857) seulement, celle des dalles OpenStreetMap déjà utilisées par la carte (`server/carte.go`).
- Ses capacités (`GetCapabilities`, essai du 2026-11-27) annoncent « Soumis à abonnement » et des contraintes d'accès « otherRestrictions » pour le service en général : la licence se regarde couche par couche.

## 2. Cartes marines (RasterMarine) : payantes

- Le produit « Assembled nautical charts (RasterMarine) », images des cartes marines du SHOM, porte dans sa fiche de métadonnées : accès et usage « Restricted », « Fees apply to user rights for this data. A specific contract must be signed for the commercial re-use of data. », « Do not use for navigation. », redevance de réutilisation selon le décret n° 2016-1617.
- Essai du 2026-11-27 : une tuile de la couche `RASTER_MARINE_3857_WMTS` demandée sans clé répond **401** ; la couche n'est pas dans la liste des couches publiques du service.
- NautiLink est payant au-delà du quota gratuit ([04-modele-economique.md](../04-modele-economique.md)) : l'affichage des cartes marines serait une réutilisation commerciale, avec licence, redevance et contrat. **Coût : à demander au SHOM** (devis sur diffusion.shom.fr ; la tarification 2026 applique au flux WMS/WMTS un coefficient du tarif de référence de la licence, par exemple 0,3 pour un an, selon le document de licences 2026).

## 3. Couches thématiques : servies sans clé

- Le service public sert sans clé des couches thématiques, par exemple : épaves et obstructions (`EPAVES_PYR-PNG_WLD_3857_WMTS`, tuile PNG reçue lors de l'essai), balisage (`BALISAGE_PYR_PNG_3857_WMTS`), câbles et conduites, réglementation de la navigation (`REGLEMENTATION_NAVIGATION_PYR_PNG_3857_WMTS`), dispositifs de séparation du trafic, délimitations maritimes, zones de marée, toponymie.
- Certaines données du SHOM sont diffusées sous la licence ouverte Etalab 2.0, avec une mention de source (par exemple « © Shom-IGN, 2021 » pour la limite terre-mer) ; **la licence de chaque couche retenue est à vérifier** dans sa fiche de métadonnées avant de l'afficher.
- Le balisage est déjà affiché par OpenSeaMap ; les épaves et la réglementation de la navigation seraient les ajouts les plus utiles à un suiveur.

## 4. Faisabilité

- La carte de la page d'une navigation assemble déjà des dalles Web Mercator (OpenStreetMap, puis OpenSeaMap par-dessus) : une couche WMTS du SHOM s'ajoute de la même façon, avec sa mention de source dans la légende ([RG-NAV-29](../02-regles-metier.md#rg-nav-29)).
- Les dalles WMTS du SHOM se demandent par `GetTile` (`tilematrixset=3857`, `tilematrix`, `tilerow`, `tilecol`, comme les numéros de dalles OpenStreetMap).
- Charge : quelques dalles par page affichée ; à confirmer : limites d'usage du service public.

## 5. Proposition (non validée)

Reportée dans [Q-23](../06-questions-ouvertes.md#q-23) :

1. Pas de cartes marines RasterMarine au lancement (licence et redevance pour une réutilisation commerciale, coût inconnu) ; demander un devis au SHOM si l'utilisateur le souhaite.
2. Ajouter la couche « Épaves et obstructions » du SHOM au-dessus d'OpenSeaMap, si sa licence le permet (licence ouverte et mention de source), après vérification de sa fiche de métadonnées.

## Sources

- [Fiche de métadonnées RasterMarine (catalogue du SHOM)](https://services.data.shom.fr/geonetwork/srv/api/records/CARTO_RASTER_MARINE.xml)
- [Service WMTS du SHOM (aide de services.data.shom.fr)](https://services.data.shom.fr/support/en/node/8)
- [Capacités du service WMTS](https://services.data.shom.fr/INSPIRE/wmts?service=WMTS&version=1.0.0&request=GetCapabilities)
- [Document de licences 2026 du SHOM](https://diffusion.shom.fr/media/wysiwyg/licence/Document_RIP_2026-VF.pdf)
- [Décision de tarification 2026 du SHOM](https://www.shom.fr/sites/default/files/2025-12/168_decision_Tarification_2026.pdf)
