# Actions réalisées

Actions de la [feuille de route](TODO.md) réalisées et validées (`[x]`), retirées du TODO pour le garder lisible. Mêmes numéros et mêmes sections que le TODO ; les identifiants renvoient aux [règles métier](02-regles-metier.md) et au [journal des décisions](07-decisions.md). Une action réalisée dont un point reste ouvert reste dans le TODO.

## 0. Ménage du dépôt

- [x] **TODO-0.1**: Fusion des deux cahiers des charges, noms de fichiers sans accents ni espaces, logo dans `docs/assets/`, liens du README corrigés (2026-11-24, D-24).
- [x] **TODO-0.2**: Règles métier numérotées `RG-…`, glossaire, questions ouvertes `Q-nn`, journal des décisions `D-nn`, `CLAUDE.md` (2026-11-24).
- [x] **TODO-0.3**: Feuille de route `TODO.md`, `Todo-done.md` et `Todo-ithem-for-todo.md` selon le modèle du skill `todo` (2026-11-24).

## 1. Décisions

- [x] **TODO-1.1**: Contradictions des documents d'origine arbitrées par l'utilisateur : SOS, contacts, partage, fréquence, destination, notes vocales, SMS, quota, journal, corbeille, connexion, abonnement (2026-11-24, D-01 à D-25).
- [x] **TODO-1.2**: SMS SOS non désactivables, SOS depuis l'accueil, invitation par téléphone depuis le Web, droits des suiveurs (2026-11-24, D-26 à D-29).
- [x] **TODO-1.3**: Suiveurs et contacts SOS : une seule liste, les deux cases cochées par défaut (2026-11-24, D-30).
- [x] **TODO-1.18**: Application iPhone ajoutée : navigateur et suiveur, aucun SMS, SOS par Internet, après Android, abonnement App Store (2026-11-24, D-31 à D-34).
- [x] **TODO-1.4**: Lieux et distance d'une navigation (2026-11-24, D-35).
- [x] **TODO-1.5**: Refus des SMS par un suiveur (2026-11-24, D-36).
- [x] **TODO-1.6**: Invitation sans expiration, annulable (2026-11-24, D-37).
- [x] **TODO-1.7**: Informations modifiables d'une navigation (2026-11-24, D-38).
- [x] **TODO-1.8**: Avertissement avant la clôture automatique (2026-11-24, D-39).
- [x] **TODO-1.11**: Photos : 20 par navigation, environ 1 Mo (2026-11-24, D-40).
- [x] **TODO-1.12**: Notifications par e-mail (2026-11-24, D-41).
- [x] **TODO-1.13**: Affichage du quota (2026-11-24, D-42).
- [x] **TODO-1.9**: Reprise après redémarrage : au lancement suivant (2026-11-24, D-51).
- [x] **TODO-1.10**: Nouvelles tentatives des SMS (2026-11-24, D-50).
- [x] **TODO-1.15**: Un seul profil d'administrateur (2026-11-24, D-47).
- [x] **TODO-1.16**: Conservation et export des données (2026-11-24, D-46).
- [x] **TODO-1.17**: Conformité au lancement (2026-11-24, D-45).
- [x] **TODO-1.22**: Copie au navigateur de tous les SMS et e-mails de notification (2026-11-24, D-55).
- [x] **TODO-1.23**: Avertissement bêta et responsabilité : texte, acceptation à la création du compte, rappel avant la première navigation (2026-11-24, D-56).
- [x] **TODO-1.24**: Prototype de démonstration, Flutter, serveur maison, iPhone « bientôt » (2026-11-24, D-57 à D-60).
- [x] **TODO-1.25**: Hébergement du serveur sur pi-appliance (ancienne question 37, 2026-11-24, D-62).
- [x] **TODO-1.19**: Changer les heures d'une navigation : quota sur les heures enregistrées, positions hors plage masquées du tracé (2026-11-25, D-83).
- [x] **TODO-1.20**: Position en retard : deux fois la fréquence, une seule notification (2026-11-25, D-84).
- [x] **TODO-1.21**: SMS de positions automatiques envoyés automatiquement, nouvelles tentatives pour les seuls SMS automatiques (2026-11-25, D-82).
- [x] **TODO-1.26**: Positions automatiques sans permission d'envoi de SMS : envoyées seulement au serveur (2026-11-25, D-91).
- [x] **TODO-1.27**: Notifications push du suiveur sur Android, les mêmes que sur iPhone (2026-11-25, D-92).
- [x] **TODO-1.14**: Prix et paiement de l'abonnement : 15 € payés une seule fois pour 10 ans (2026-11-25, D-94).

## 2. Études techniques

- [x] **TODO-2.6**: Fonctionnement hors connexion de chaque écran Android (2026-11-25, D-114, RG-COM-06).

## 3. Préparation du développement

- [x] **TODO-3.2**: API et formats de données, synchronisation Android ↔ serveur ↔ Web (2026-11-25, D-115 ; [`api/openapi.yaml`](api/openapi.yaml)).
- [x] **TODO-3.1**: Architecture technique : [08-architecture.md](08-architecture.md) validé avec ses propositions (2026-11-25, D-86, D-96).

## 8. Lancement

- [x] **TODO-8.1**: Fichiers du logo : redessin vectoriel validé, déclinaisons claire, sombre et monochrome, icônes Android, iPhone et Web ([`assets/logo/`](assets/logo/), 2026-11-25, D-117).

## 9. Évolutions futures

- [x] **TODO-9.4**: ~~Application iOS.~~ Retiré le 2026-11-24 : l'application iPhone entre dans le périmètre (D-31), voir la section 10 du TODO.
- [x] **TODO-9.5**: ~~Serveur et plateforme Web installables depuis la marketplace de pi-appliance.~~ Tranché le 2026-11-24 (D-62) : le serveur central lui-même est sur pi-appliance, voir TODO-3.7.

## 10. Étape 5 — iPhone (15)

- [x] **TODO-10.1**: Notifications push du suiveur sur iPhone (2026-11-24, D-44).
