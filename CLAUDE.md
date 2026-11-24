# CLAUDE.md — NautiLink

Dépôt de spécification fonctionnelle de NautiLink (Android + Web + serveur). Tout est rédigé en français. Pas encore de code.

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
- Noms de fichiers : minuscules, sans accents ni espaces, préfixe numérique pour l'ordre de lecture.
- Markdown GitHub ; schémas en Mermaid.

## Trancher une question

Dans un même commit :

1. ajouter une ligne `D-nn` datée dans `07-decisions.md` (problème, choix, règles touchées) ;
2. écrire ou modifier les règles dans `02-regles-metier.md` ;
3. mettre à jour les autres documents qui citent le sujet (`grep -rn "Q-nn\|<mot-clé>" docs README.md`) ;
4. supprimer la question de `06-questions-ouvertes.md`.

## Vérifications avant commit

```bash
# identifiants cités mais non définis (doit être vide)
grep -rhoE '\b(RG-[A-Z]+-[0-9]{2}|Q-[0-9]{2}|D-[0-9]{2})\b' docs README.md | sort -u > /tmp/cites
grep -rhoE 'id="(rg-[a-z]+-[0-9]{2}|q-[0-9]{2}|d-[0-9]{2})"' docs | sed -E 's/id="(.*)"/\1/' | tr a-z A-Z | sort -u > /tmp/definis
comm -23 /tmp/cites /tmp/definis
```

## Paramètres des skills

- **`spec-sync`** :
  - spécification de référence : `docs/02-regles-metier.md` (français), complétée par `docs/01-cahier-des-charges.md` ;
  - traductions : aucune ;
  - évolutions futures : `docs/01-cahier-des-charges.md` §9 et `docs/06-questions-ouvertes.md` §5 ;
  - schémas : `docs/01-cahier-des-charges.md` §4 (Mermaid) ;
  - arborescence du dépôt : `README.md` (tableau « Documents ») et `CLAUDE.md` ;
  - historique : `docs/07-decisions.md`.
- **`clarify-request`** : toute question fonctionnelle sans réponse dans `docs/` se pose à l'utilisateur, puis se trace en `D-nn`.
