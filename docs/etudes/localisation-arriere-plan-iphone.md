# Étude : localisation en arrière-plan sur iPhone, batterie et App Store

Action : [TODO-10.2](../TODO.md) · Questions : [Q-09](../06-questions-ouvertes.md#q-09), [D-51](../07-decisions.md#d-51) · Règles : RG-GPS-03, RG-NAV-05, RG-NAV-12, RG-IOS-01, RG-IOS-03.

**Statut : recherche documentaire faite (novembre 2026). Le prototype sur deux modèles d'iPhone reste à faire** : aucune mesure n'est donnée ici. Rien de ce document n'est une décision.

## 1. Besoin

Comme sur Android ([gps-arriere-plan-android.md](gps-arriere-plan-android.md)) : une position à la fréquence de la navigation (3 minutes à 1 heure, RG-NAV-05), écran verrouillé, avec ou sans réseau (RG-GPS-03), pendant plusieurs heures.

## 2. Ce que dit la documentation Apple

### 2.1 Suspension des applications et mode d'arrière-plan « Location updates »

- Sur iOS, le système suspend la plupart des applications peu après leur passage en arrière-plan ; suspendue, une application ne reçoit pas de positions (elles sont mises en file et livrées quand elle tourne de nouveau). Pour recevoir les positions à temps, l'application peut demander au système de ne pas la suspendre tant que la localisation est active. Apple cite parmi les usages légitimes « suivre le trajet précis d'une randonnée » et « produire des notifications urgentes ». Source : [Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).
- Il faut activer la capacité *Background Modes > Location updates* (clé `UIBackgroundModes` avec la valeur `location` dans `Info.plist`). Même source.
- `allowsBackgroundLocationUpdates = true` : si la localisation est démarrée au premier plan, Core Location garde l'application en vie pour des mises à jour continues en arrière-plan et affiche l'indicateur de localisation (barre ou pastille bleue) ; les mises à jour continuent ensuite en arrière-plan. Le régler à `true` sans la clé `UIBackgroundModes` fait planter l'application. Source : [allowsBackgroundLocationUpdates](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).
- `CLBackgroundActivitySession` (API récente, iOS 17 d'après les annonces Apple de 2023, à confirmer) sert à recevoir les positions en arrière-plan : à créer au premier plan, et à recréer immédiatement au relancement en arrière-plan si l'application a été terminée. Source : [Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).

### 2.2 Autorisations « Pendant l'utilisation » et « Toujours »

- La localisation démarrée au premier plan avec une session d'activité en arrière-plan fonctionne avec l'autorisation « Pendant l'utilisation » (*When In Use*) ; Core Location la positionne implicitement dans ce cas. Pour l'autorisation « Toujours », Apple demande d'informer l'utilisateur que les positions arrivent en arrière-plan. Source : [Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).
- Le système peut terminer une application à tout moment pour libérer de la mémoire ; l'application doit alors relancer ses services de localisation au démarrage, et ne pas les démarrer si l'autorisation n'est pas encore déterminée. Même source.

### 2.3 Pause automatique (point critique au mouillage)

- `pausesLocationUpdatesAutomatically` vaut `true` par défaut : Core Location peut mettre en pause les mises à jour (et éteindre le matériel) quand la position semble ne plus changer. **Avec l'autorisation « Pendant l'utilisation », une pause met fin à l'accès aux positions jusqu'au prochain lancement de l'application.** Apple conseille, pour éviter un arrêt complet, de désactiver la pause et de réduire la précision en arrière-plan. Source : [pausesLocationUpdatesAutomatically](https://developer.apple.com/documentation/corelocation/cllocationmanager/pauseslocationupdatesautomatically).
- Conséquence : un bateau au mouillage ou par calme plat serait vu comme immobile ; il faut désactiver la pause automatique et mesurer l'effet sur la batterie au prototype.

### 2.4 Changements de position significatifs

- `startMonitoringSignificantLocationChanges()` relance l'application en arrière-plan si elle a été terminée et qu'un nouvel événement arrive. Mais un événement n'arrive qu'après un déplacement d'au moins 500 m, et pas plus d'une fois toutes les 5 minutes. Source : [startMonitoringSignificantLocationChanges()](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges()).
- Ce service ne suffit donc pas à une fréquence de 3 minutes ; il peut seulement servir de filet pour relancer l'application après une terminaison par le système.

## 3. Règles de l'App Store

Source : [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

| Règle | Contenu (extrait) | Effet pour NautiLink |
|-------|-------------------|----------------------|
| 2.5.4 | Les services d'arrière-plan ne servent qu'à leur usage prévu : VoIP, lecture audio, localisation, fin de tâche, notifications locales, etc. | La localisation en arrière-plan doit servir au suivi de la navigation, rien d'autre. |
| 2.4.2 | Les applications ne doivent pas vider rapidement la batterie ni chauffer le téléphone. | Mesure de batterie à faire au prototype (§ 5). |
| 5.1.1 | Consentement avant collecte ; textes d'explication (*purpose strings*) clairs et complets ; fonctions payantes non conditionnées à l'accès aux données. | Textes `NSLocationWhenInUseUsageDescription` (et `NSLocationAlwaysAndWhenInUseUsageDescription` si « Toujours ») à rédiger. La fonction gratuite comme l'abonnement ne doivent pas dépendre d'une autorisation non nécessaire. |
| 5.1.5 | Localisation seulement quand elle sert directement la fonction ; prévenir et obtenir le consentement avant de collecter, transmettre ou utiliser la position. **Les API de localisation ne devraient pas servir à fournir des services d'urgence**, sauf exceptions citées (petits drones, jouets, alarmes de voiture…). | **Risque pour le SOS sur iPhone (RG-IOS-03)** : la présentation de NautiLink et de son SOS devant la revue Apple est à étudier (par exemple : alerte envoyée à des proches, pas service d'urgence ; renvoi vers les moyens officiels). À traiter avant la soumission. |

## 4. Reprise après fermeture ou redémarrage (éclaire [D-51](../07-decisions.md#d-51))

- **Terminaison par le système** : relancement possible en arrière-plan par un événement de localisation (changement significatif, § 2.4) ; l'application doit alors recréer sa `CLBackgroundActivitySession` et relancer ses services (§ 2.1 et § 2.2). Les pages consultées ne disent pas si l'autorisation « Pendant l'utilisation » suffit à ce relancement : **à constater au prototype**.
- **Fermeture par l'utilisateur** (balayage dans le sélecteur d'applications) et **redémarrage** de l'iPhone : non décrits par les pages consultées. D'après le fonctionnement connu d'iOS, une application fermée par l'utilisateur n'est pas relancée par les événements de localisation et rien ne redémarre seul après un redémarrage avant le lancement de l'application. **À constater au prototype** ; si c'est confirmé, la seule reprise possible sur iPhone est celle du lancement suivant (RG-NAV-12).

## 5. Protocole du prototype (critères d'acceptation de TODO-10.2)

1. Application minimale : `UIBackgroundModes` `location`, `allowsBackgroundLocationUpdates = true`, pause automatique désactivée, `CLBackgroundActivitySession`, une position toutes les 3 minutes enregistrée localement avec son heure.
2. Deux modèles d'iPhone (un récent, un ancien parmi les modèles compatibles avec la version minimale d'iOS, RG-IOS-09), versions d'iOS notées.
3. Essai de 8 heures, écran verrouillé, téléphone immobile puis en mouvement si possible ; autorisation « Pendant l'utilisation », puis « Toujours ».
4. Relever : positions attendues (160) et reçues, plus long trou, batterie consommée, apparition de l'indicateur bleu.
5. Essais de reprise : fermeture par balayage, redémarrage, terminaison par le système (forcée en remplissant la mémoire).

## 6. Questions pour l'utilisateur (non tranchées)

- Autorisation demandée sur iPhone : « Pendant l'utilisation » seule (suffisante d'après Apple pour une navigation démarrée au premier plan) ou « Toujours » (utile seulement si elle améliore la reprise, à constater).
- Présentation du SOS sur iPhone face à la règle 5.1.5 de l'App Store.
- Version minimale d'iOS : celle par défaut de Flutter 3.47.9 ([D-89](../07-decisions.md#d-89), RG-IOS-09) ; `CLBackgroundActivitySession` demanderait iOS 17, à comparer avec elle.
