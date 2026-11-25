# CLAUDE.md — NautiLink

Dépôt de spécification fonctionnelle de NautiLink (Android + iPhone + Web + serveur), avec le site de présentation et un prototype de démonstration Flutter (`app/`, données d'exemple, sans serveur). Tout est rédigé en français. La spécification fait foi sur le prototype.

## Où trouver quoi

| Besoin | Fichier |
|--------|---------|
| Sens d'un mot | `docs/00-glossaire.md` |
| Périmètre, écrans, architecture | `docs/01-cahier-des-charges.md` |
| Comportement exact, cas limites | `docs/02-regles-metier.md` (`RG-<DOMAINE>-<nn>`) |
| Enchaînement des écrans | `docs/03-parcours-utilisateur.md` |
| Quota, abonnement | `docs/04-modele-economique.md` |
| Couleurs, polices, ton, logo | `docs/05-identite-marque.md` |
| Ce qui n'est pas décidé | `docs/06-questions-ouvertes.md` (`Q-nn`) |
| Pourquoi une règle est ainsi | `docs/07-decisions.md` (`D-nn`) |
| Architecture technique : serveur, base, fichiers, e-mails, push | `docs/08-architecture.md` |
| API du serveur (OpenAPI), formats de données, synchronisation | `docs/api/openapi.yaml`, `docs/08-architecture.md` §4 |
| Scénarios de tests fonctionnels | `docs/tests/scenarios-fonctionnels.md` (`TS-<DOMAINE>-<nn>`) |
| Ce qu'il reste à faire, dans quel ordre | `docs/TODO.md` (`TODO-x.y`), `docs/Todo-done.md` |
| Demandes en vrac de l'utilisateur | `docs/Todo-ithem-for-todo.md` |
| Textes affichés aux utilisateurs (avertissement bêta) | `docs/textes/` |
| Prototype de démonstration (Flutter : Android, iPhone, Web) | `app/` (`lib/`, `test/`), voir `app/README.md` ; Flutter 3.47.9 |
| Serveur central (Go, hébergé sur pi-appliance, D-62) | `server/`, voir `server/README.md` ; image publiée par `.github/workflows/serveur.yml` |
| Site de présentation (GitHub Pages) | `site/` (`index.html`, `telecharger.html`, `abonnement.html`, `securite.html`, `avertissement.html`, `style.css`), publié par `.github/workflows/pages.yml` |
| Envoi de SMS et MMS sur Android (Google Play, API, MMS) | `docs/etudes/sms-mms-android.md` |
| GPS en arrière-plan sur Android, batterie, reprise | `docs/etudes/gps-arriere-plan-android.md` |
| Autorisations Android, versions visées, Google Play | `docs/etudes/autorisations-android.md` |
| Localisation en arrière-plan sur iPhone, App Store | `docs/etudes/localisation-arriere-plan-iphone.md` |
| Notes vocales : format audio, transcription | `docs/etudes/notes-vocales.md` |
| Disponibilité du nom NautiLink : marques, domaines, réseaux sociaux | `docs/etudes/nom-nautilink.md` |

## Ordre de priorité en cas d'écart

1. `02-regles-metier.md`
2. `07-decisions.md` (la plus récente l'emporte)
3. `01-cahier-des-charges.md`
4. `03-parcours-utilisateur.md`, `04-modele-economique.md`
5. `05-identite-marque.md` pour l'apparence uniquement

Un écart entre documents est un défaut : le signaler et le corriger, ne pas choisir silencieusement.

## Règles de rédaction

- **Une information, un seul endroit.** Une règle est écrite dans `02-regles-metier.md` ; les autres documents la citent par son identifiant (`RG-NAV-05`) au lieu de la recopier.
- **Ne rien inventer.** Un comportement non décidé va dans `06-questions-ouvertes.md` (avec une proposition marquée non validée), jamais directement dans les règles. Pour trancher, demander à l'utilisateur (skill `clarify-request`).
- **Identifiants stables.** `RG-…`, `Q-nn`, `D-nn` ne sont jamais renumérotés ni réutilisés. Nouvelle règle : numéro suivant du domaine. Règle abandonnée : la barrer avec un renvoi vers la décision.
- **Ancres** : chaque identifiant porte une ancre HTML minuscule (`<a id="rg-nav-05"></a>`, `<a id="q-12"></a>`, `<a id="d-07"></a>`) pour les liens entre fichiers.
- **Vocabulaire** du glossaire uniquement : *navigateur*, *suiveur*, *navigation*, *contact SOS*, *destinataire SMS*, *accès* de périmètre *navigation* ou *navigateur*, etc. Nouveau terme : l'ajouter au glossaire.
- **Libellés d'interface** entre guillemets français, tels qu'affichés : « Démarrer navigation », « Envoyer un SOS ».
- Noms de fichiers : minuscules, sans accents ni espaces, préfixe numérique pour l'ordre de lecture ; exception : `TODO.md`, `Todo-done.md` et `Todo-ithem-for-todo.md`, noms imposés par le skill `todo`.
- Markdown GitHub ; schémas en Mermaid.

## Feuille de route

Skill `todo` ; les actions sont groupées en lots (`LOT-n`) réalisés par l'agent `todo-lot`. Lire `docs/Todo-ithem-for-todo.md` avant de travailler : chaque demande devient une action du TODO (ou une question `Q-nn` si c'est une décision à prendre), puis est retirée du fichier. Mettre le TODO à jour dans le même commit que le travail : `[~]` quand c'est fait mais pas validé, `[x]` et déplacement dans `Todo-done.md` quand les critères d'acceptation sont constatés. Une question tranchée débloque l'action `[!]` correspondante de la section 1.

## Trancher une question

Dans un même commit :

1. ajouter une ligne `D-nn` datée dans `07-decisions.md` (problème, choix, règles touchées) ;
2. écrire ou modifier les règles dans `02-regles-metier.md` ;
3. mettre à jour les autres documents qui citent le sujet (`grep -rn "Q-nn\|<mot-clé>" docs README.md`) ;
4. supprimer la question de `06-questions-ouvertes.md` ;
5. cocher l'action correspondante du TODO et la déplacer dans `docs/Todo-done.md`.

## Vérifications avant commit

Prototype (`app/`) : `flutter analyze` et `flutter test` sans erreur.

Serveur (`server/`) : `gofmt -l .` vide, `go vet ./...` et `go test ./...` sans erreur. Les essais avec PostgreSQL demandent `NAUTILINK_BASE_TEST` sur une base jetable (voir `server/README.md`).


```bash
# identifiants cités mais non définis (doit être vide)
grep -rhoE '\b(RG-[A-Z]+-[0-9]{2}|Q-[0-9]{2,3}|D-[0-9]{2,3})\b' docs README.md | sort -u > /tmp/cites
grep -rhoE 'id="(rg-[a-z]+-[0-9]{2}|q-[0-9]{2,3}|d-[0-9]{2,3})"' docs | sed -E 's/id="(.*)"/\1/' | tr a-z A-Z | sort -u > /tmp/definis
comm -23 /tmp/cites /tmp/definis
```

## Paramètres des skills

- **`spec-sync`** :
  - spécification de référence : `docs/02-regles-metier.md` (français), complétée par `docs/01-cahier-des-charges.md` ;
  - traductions : aucune ;
  - évolutions futures : `docs/01-cahier-des-charges.md` §9 et `docs/06-questions-ouvertes.md` §5 ;
  - schémas : `docs/01-cahier-des-charges.md` §4 (Mermaid) ;
  - arborescence du dépôt : `README.md` (tableau « Documents ») et `CLAUDE.md` ;
  - avancement : `docs/TODO.md` ;
  - historique : `docs/07-decisions.md`.
- **`todo`** :
  - TODO : `docs/TODO.md` ; actions réalisées : `docs/Todo-done.md` ; boîte de réception : `docs/Todo-ithem-for-todo.md` ;
  - spécification : `docs/02-regles-metier.md` et `docs/01-cahier-des-charges.md` ;
  - filtres : non (pas de site publié) ;
  - lots : tableau « Lots » en tête de `docs/TODO.md`.
- **Agent `todo-lot`** :
  - branche de push : `main`, une action = un commit poussé ;
  - vérification après chaque action : commandes de la section « Vérifications avant commit » ;
  - lancement depuis la session principale : « Réalise LOT-n avec l'agent todo-lot », un lot à la fois ; les questions qu'il rend sont posées à l'utilisateur par la session principale.
- **`clarify-request`** : toute question fonctionnelle sans réponse dans `docs/` se pose à l'utilisateur, puis se trace en `D-nn`.
