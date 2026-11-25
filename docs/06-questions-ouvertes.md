# NautiLink — Questions ouvertes et études

Tout ce qui n'est pas encore décidé est ici, et seulement ici. Chaque question a un identifiant `Q-nn` stable, cité par les autres documents.

- **Priorité** : *bloquant* (à trancher avant de développer la fonction concernée), *lancement* (avant la mise en service), *plus tard*.
- **Proposition** : choix par défaut suggéré, **non validé**. Ne pas l'implémenter tant que le porteur du projet ne l'a pas confirmé.
- Quand une question est tranchée : ajouter une décision dans [07-decisions.md](07-decisions.md), reporter la règle dans [02-regles-metier.md](02-regles-metier.md) et les autres documents, puis supprimer la question d'ici (son identifiant n'est pas réutilisé). Le travail correspondant est suivi dans le [TODO](TODO.md).

## 1. Questions fonctionnelles

### <a id="q-39"></a>Q-39 — Service météo : conditions d'accès

- Priorité : avant la version réelle.
- Décidé (D-88) : la météo du début et de la fin d'une navigation (RG-NAV-28) vient de l'API de Météo-France.
- Reste à vérifier : conditions d'accès (clé, quotas, usage par un serveur) et présence des données demandées par RG-NAV-28 (vent, état de la mer, pression).
- Prévu (2026-11-25) : le porteur du projet ouvre le compte sur le portail API de Météo-France ; la météo est intégrée avant la sortie de la version réelle. Mode d'emploi et points à vérifier : [meteofrance-connexion.md](etudes/meteofrance-connexion.md).

### <a id="q-80"></a>Q-80 — Mémo sécurité en mer dans les applications mobiles

- Priorité : avant la version Android réelle (TODO-5.1).
- Cas : l'utilisateur a demandé (2026-11-25) que le mémo sécurité en mer du site (`site/securite.html`) soit accessible dans les applications mobiles. Rien ne dit s'il faut ouvrir la page du site, qui demande Internet, ou l'intégrer à l'application pour qu'il reste lisible hors connexion, en mer ; ni où le placer (accueil, assistance).
- Proposition (non validée) : intégrer le mémo à l'application, lisible hors connexion, ouvert depuis l'accueil par « Mémo sécurité en mer » ; le contenu reste rédigé une seule fois, sur le site, et copié dans l'application à chaque construction. Ce qui est fait (TODO-3.12) : dans le prototype, le lien de l'accueil ouvre la page du site dans le navigateur du téléphone.

### <a id="q-70"></a>Q-70 — Navigation dans la corbeille, côté navigateur

- Priorité : avant la plateforme Web (TODO-4.8, TODO-6.5).
- Cas : RG-NAV-20 retire l'accès aux suiveurs pendant le séjour dans la corbeille, mais ne dit pas ce que peut encore faire le navigateur : ouvrir la page de la navigation, la modifier (nom, heures, journal de bord, suiveurs), et ce que deviennent les envois du téléphone encore en attente pour elle.
- Proposition (non validée) : le navigateur voit encore la page de la navigation (état « corbeille ») mais ne la modifie plus avant de l'avoir restaurée ; les envois en attente du téléphone (positions, notes, photos, notes vocales, fin rejouée) restent acceptés, pour que rien ne manque après une restauration. Ce qui est fait (TODO-4.8) : cette proposition, appliquée en attendant.

### <a id="q-71"></a>Q-71 — Accès de périmètre *navigation* après la suppression définitive

- Priorité : avant la plateforme Web (TODO-4.8).
- Cas : RG-NAV-20 supprime définitivement la navigation au bout de 30 jours dans la corbeille ; rien ne dit ce que deviennent les accès de périmètre *navigation* (RG-PAR-02) donnés sur elle.
- Proposition (non validée) : ils sont retirés avec la navigation ; le contact reste dans la liste des contacts du navigateur, et les accès de périmètre *navigateur* ne changent pas. Ce qui est fait (TODO-4.8) : cette proposition, appliquée en attendant.

## 2. Études techniques

### <a id="q-09"></a>Q-09 — GPS en arrière-plan et batterie

- Priorité : bloquant.
- Étude : enregistrement GPS application en arrière-plan ou écran éteint, consommation de batterie, comportement selon les marques et versions d'Android, et sur iPhone (localisation en arrière-plan, règles de l'App Store).
- Étude documentaire Android : [gps-arriere-plan-android.md](etudes/gps-arriere-plan-android.md).
- Étude documentaire iPhone : [localisation-arriere-plan-iphone.md](etudes/localisation-arriere-plan-iphone.md).

### <a id="q-12"></a>Q-12 — Restrictions Android sur l'envoi de SMS

- Priorité : bloquant, à étudier en premier.
- Décidé (D-48) : exception « urgence » de Google Play pour les SMS SOS ; SMS ordinaires préremplis.
- Décidé (D-82) : les SMS de positions automatiques partent aussi automatiquement ; la demande de permission auprès de Google Play doit couvrir ce cas, avec le risque accepté d'un refus en dehors de l'exception « urgence » ; sans cette permission, positions au serveur seulement (D-91).
- Reste : lire la page officielle de Google Play et vérifier que l'exception existe et couvre NautiLink. Si elle est refusée, revenir vers l'utilisateur.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md) (voies possibles §3).

### <a id="q-13"></a>Q-13 — MMS

- Priorité : lancement.
- Décidé (D-49) : en cas d'échec, SMS avec le lien vers la photo.
- Reste : taille maximale des pièces jointes et compatibilité des opérateurs, à mesurer.
- Étude documentaire : [sms-mms-android.md](etudes/sms-mms-android.md#5-mms-todo-24).

### <a id="q-22"></a>Q-22 — Architecture et développement

- Priorité : bloquant.
- Décidé (D-58, D-59) : applications mobiles Android et iPhone en Flutter, un seul code ; serveur maison.
- Décidé (D-62) : serveur en Go, hébergé pendant la bêta sur un Raspberry Pi sous pi-appliance, base PostgreSQL.
- Décidé (D-86) : photos et notes vocales stockées dans PostgreSQL ; notifications push par APNs pour l'iPhone et Firebase Cloud Messaging pour Android (contenu sur Android : D-92, RG-AND-08) ; sauvegardes de pi-appliance, chaque nuit, gardées 30 jours (RG-DON-02).
- Décidé (D-96) : [08-architecture.md](08-architecture.md) validé, propositions comprises (serveur virtuel dans l'Union européenne après la bêta, relais d'e-mails avec SPF, DKIM et DMARC, géocodage par Nominatim).
- Décidé (D-115) : API ([`api/openapi.yaml`](api/openapi.yaml)) et environnements de développement, de test et de production ([08-architecture.md §6](08-architecture.md#6-environnements)) validés.
- Reste : nom de l'hébergeur et date du passage après la bêta ; vérifier que les sauvegardes de pi-appliance couvrent la base, puis faire un essai de restauration (TODO-3.11).

## 3. Données, sécurité, conformité

## 4. Marque et interface

### <a id="q-26"></a>Q-26 — Nom et présence en ligne

- Priorité : lancement.
- À vérifier : disponibilité juridique du nom NautiLink, noms de domaine, comptes sur les réseaux sociaux.
- Étude : [nom NautiLink](etudes/nom-nautilink.md) (2026-11-25) : pas d'homonyme exact repéré parmi les applications ; quasi-homonyme Nauti-Link (conseil en cession d'entreprises du nautisme, France) ; bases de marques, domaines et comptes non consultés.
- Décidé (D-87) : le nom NautiLink est gardé, sous réserve des vérifications ci-dessous.
- Reste : consulter les bases de marques INPI, EUIPO et OMPI ; obtenir un avis juridique (cas Nauti-Link) ; puis réserver les domaines et les comptes libres.

### <a id="q-30"></a>Q-30 — Maquettes et accessibilité

- Priorité : bloquant pour le développement des écrans.
- Décidé (D-95) : WCAG 2.2 niveau AA (RG-PRM-05).
- Reste : validation des [maquettes](../site/designs/app.html) des écrans Android et Web.

## 5. Évolutions futures

### <a id="q-23"></a>Q-23 — Cartes marines du SHOM

- Priorité : lancement (demande de l'utilisateur du 2026-11-24, D-79).
- Étude : quelles données du SHOM sont gratuites et réutilisables sur la carte de la page d'une navigation (licence, clé d'accès, conditions d'affichage), et comment les superposer au fond OpenStreetMap et à OpenSeaMap (RG-NAV-29).

### <a id="q-27"></a>Q-27 — Autres langues

- Priorité : plus tard.
- Décidé (D-90) : français et anglais au lancement ; langue du téléphone par défaut, modifiable dans les paramètres ; messages envoyés aux suiveurs et aux contacts SOS dans la langue du navigateur (RG-PRM-03, RG-PRM-04).
- Essai dans le prototype (TODO-9.2) : textes des écrans dans `app/lib/l10n/app_fr.arb` (français, langue de référence) et `app_en.arb` (anglais), code généré par `flutter gen-l10n`.
- Décidé (D-93) : sur la plateforme Web, langue du navigateur Internet par défaut (RG-PRM-03).
- Reste : relecture de la traduction anglaise ; ajout d'autres langues après le lancement, sans gestion des langues dans l'espace administrateur (RG-ADM-04).

### <a id="q-28"></a>Q-28 — Versions multiples du Web

- Priorité : plus tard.
- Étude : déploiement et compatibilité de plusieurs versions de l'application Web, utilisateurs sur des versions différentes (RG-ADM-05).
