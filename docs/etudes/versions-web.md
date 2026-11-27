# Plusieurs versions de l'Application web

Étude de [Q-28](../06-questions-ouvertes.md#q-28) (TODO-9.3) : déploiement et compatibilité de plusieurs versions de l'Application web, avec des utilisateurs sur des versions différentes ([RG-ADM-05](../02-regles-metier.md#rg-adm-05) : évolution future, hors lancement).

> **État** : rédigé le 2026-11-27 d'après l'architecture actuelle ([08-architecture.md](../08-architecture.md)) et la gestion des versions ([09-versions.md](../09-versions.md), [D-128](../07-decisions.md#d-128)). Rien n'est décidé.

## 1. Situation actuelle

- L'Application web est servie par le serveur lui-même (pages de `server/web/`, même image Docker, même version que le serveur, [D-62](../07-decisions.md#d-62)) : elle ne peut pas être en retard sur le serveur. Un navigateur Internet qui recharge la page a toujours la dernière version.
- Les applications mobiles, elles, restent installées dans leur version : elles parlent au serveur par l'API `/api/v1` ([docs/api/openapi.yaml](../api/openapi.yaml)), et la [matrice de compatibilité](../09-versions.md) dit quelles versions vont ensemble.
- Un seul serveur, sur pi-appliance pendant la bêta : une seule version déployée à la fois.

## 2. Ce que « plusieurs versions » peut vouloir dire

| Cas | Besoin | Moyen |
|-----|--------|-------|
| A. Essayer une nouvelle version avant tout le monde | quelques comptes voient la nouvelle Application web | une seconde instance (image suivante) sur une autre adresse, branchée sur la même base, réservée à des comptes choisis |
| B. Garder une ancienne version pour certains | des utilisateurs restent sur l'ancienne présentation | deux instances de versions différentes sur la même base |
| C. Changer l'API sans casser les téléphones | anciennes applications mobiles encore en service | API versionnée : `/api/v1` gardée tant qu'une version mobile de la matrice l'utilise, `/api/v2` à côté |

## 3. Contraintes

- **Base de données commune** : deux versions du serveur sur la même base imposent des migrations compatibles dans les deux sens pendant la période (ajouter des colonnes, ne rien supprimer ni renommer avant que l'ancienne version soit arrêtée).
- **Tâches de fond** (clôture automatique, corbeille, e-mails SOS, météo) : une seule instance doit les jouer, sinon elles partent deux fois.
- **Sessions** : un utilisateur qui passe d'une instance à l'autre garde sa session si les deux partagent la même base et le même format de session.
- **E-mails et liens** : les liens des e-mails (invitation, SOS) pointent vers une seule adresse publique (`NAUTILINK_ADRESSE_PUBLIQUE`).

## 4. Proposition (non validée)

Reportée dans [Q-28](../06-questions-ouvertes.md#q-28) :

1. Garder une seule version de l'Application web en service ; pas de version choisie par l'utilisateur (cas B écarté : double maintenance pour un petit service).
2. Pour une évolution risquée, cas A : une instance d'essai de la version suivante sur une adresse à part (par exemple `<chemin>-essai`), même base, tâches de fond désactivées par une variable d'environnement, ouverte aux administrateurs (RG-ADM-07) ; migrations de base compatibles avec la version en service.
3. Cas C, pour les applications mobiles : `/api/v1` gardée tant qu'une version mobile de la matrice l'utilise ; une rupture passe par `/api/v2` servie à côté, et la matrice de [09-versions.md](../09-versions.md) dit quand `/api/v1` peut être retirée.
