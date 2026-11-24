# NautiLink — prototype de démonstration

Application Flutter, un seul code pour Android, iPhone et la démonstration Web ([D-57](../docs/07-decisions.md#d-57), [D-58](../docs/07-decisions.md#d-58)).

**Démonstration seulement** : données d'exemple, aucun serveur, rien n'est réellement envoyé (ni SMS, ni e-mail, ni position). La spécification fait foi : [`docs/02-regles-metier.md`](../docs/02-regles-metier.md).

## Ce que montre le prototype

- avertissement bêta à accepter (RG-CPT-06) et rappel avant la première navigation (RG-NAV-23) ;
- accueil mobile : « Démarrer navigation », « Reprendre la dernière navigation », « Navigations enregistrées », bouton SOS ;
- démarrage : bateau, destination facultative, fréquence, paramètres de la navigation ;
- navigation en cours : deux chronomètres, position, NOTE, Photo, Vocal, SOS avec confirmation, fin ;
- contacts (cases « Suiveur » et « Contact SOS »), paramètres SMS, quota ;
- tableau de bord Web : navigations en cours et historique, filtre navigateur / suiveur, carte du tracé, journal.

Sur le Web, un premier écran propose de jouer le navigateur (dans un cadre de téléphone) ou le suiveur.

## Commandes

Flutter 3.47.9 (version fixée aussi dans `.github/workflows/pages.yml`).

```bash
flutter test                                  # parcours avertissement → SOS → fin
flutter analyze
flutter build web --release --base-href /NautiLink/app/ --no-web-resources-cdn
flutter build apk --release                   # APK de démonstration (signature de débogage)
```

Le site GitHub Pages publie la démonstration Web sous `app/` et l'APK sous `downloads/nautilink-demo.apk`, construits par le workflow « Site GitHub Pages ».
