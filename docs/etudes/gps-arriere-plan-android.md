# Étude : GPS en arrière-plan sur Android, batterie et reprise

Action : [TODO-2.2](../TODO.md) · Questions : [Q-09](../06-questions-ouvertes.md#q-09), [D-51](../07-decisions.md#d-51), [Q-31](../06-questions-ouvertes.md#q-31) · Règles : RG-GPS-03, RG-NAV-05, RG-NAV-12.

**Statut : recherche documentaire faite (novembre 2026). Le prototype sur vrais téléphones reste à faire** : aucune mesure de batterie ni de positions manquantes n'est donnée ici. Rien de ce document n'est une décision.

## 1. Besoin

Pendant une navigation, le téléphone enregistre une position à la fréquence choisie (3, 4, 5, 10, 15, 30 minutes ou 1 heure, RG-NAV-05), application en arrière-plan ou écran éteint, que le serveur soit joignable ou non (RG-GPS-03). Une navigation peut durer plusieurs heures, voire plusieurs jours.

## 2. Ce que dit la documentation Android

### 2.1 Service de premier plan de type `location`

- Le moyen prévu par Android pour une localisation continue écran éteint est un **service de premier plan** (notification permanente). Android considère alors l'accès comme une localisation « au premier plan », même quand l'utilisateur appuie sur Accueil ou éteint l'écran. Source : [Location permissions](https://developer.android.com/training/location/permissions).
- Depuis Android 10, le service doit déclarer `android:foregroundServiceType="location"` ; depuis Android 14, il faut aussi la permission `FOREGROUND_SERVICE_LOCATION`, la localisation activée et `ACCESS_COARSE_LOCATION` ou `ACCESS_FINE_LOCATION` accordée. Le type `location` est décrit pour « la navigation et le partage de position ». Source : [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types).
- Le type `location` **n'a pas de limite de durée** (contrairement à `dataSync` et `mediaProcessing`, limités à 6 heures par 24 heures depuis Android 15). Source : [Android 15 behavior changes](https://developer.android.com/about/versions/15/behavior-changes-15). Conséquence : l'envoi des positions au serveur doit se faire depuis le service `location` lui-même (ou par WorkManager), pas par un service `dataSync` distinct qui serait coupé au bout de 6 heures.
- Google Play exige de déclarer les types de services de premier plan dans la Play Console (Policy > App content) pour les applications qui visent Android 14 ou plus. Source : [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types).

### 2.2 Autorisations : « Pendant l'utilisation » ou « Toujours »

- Si le service est démarré pendant que l'application est visible (appui sur « Démarrer navigation »), l'autorisation « pendant l'utilisation de l'application » suffit pour continuer écran éteint. Source : [Location permissions](https://developer.android.com/training/location/permissions).
- En revanche, un service `location` **ne peut pas être créé depuis l'arrière-plan** (par exemple après un redémarrage) sans `ACCESS_BACKGROUND_LOCATION` (« Toujours autoriser ») ; depuis Android 14, l'essai lève une `SecurityException`. Source : [Restrictions on starting a foreground service from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).
- Google Play restreint l'accès à la localisation en arrière-plan aux applications qui en ont besoin pour leur fonction principale et qui respectent sa politique (déclaration à remplir). Source : [Location permissions](https://developer.android.com/training/location/permissions), qui renvoie à la [politique Google Play](https://support.google.com/googleplay/android-developer/answer/9799150) (page non consultée : hôte non joignable depuis l'environnement de cette étude).
- Précision : sans `ACCESS_FINE_LOCATION`, la position n'est connue qu'à environ 3 km² près ; si l'utilisateur n'accorde que la position approximative, l'application ne reçoit que celle-ci. Source : [Location permissions](https://developer.android.com/training/location/permissions).

### 2.3 Économie d'énergie : Doze, App Standby, économiseur de batterie

- En Doze (écran éteint, téléphone immobile, non branché), Android coupe le réseau, ignore les *wake locks*, retarde les alarmes et les tâches `JobScheduler`/WorkManager jusqu'à une fenêtre de maintenance. Les alarmes `setExactAndAllowWhileIdle()` ne peuvent pas se déclencher plus d'une fois toutes les 9 minutes par application. Source : [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby).
  - Conséquence : une fréquence de 3 minutes ne peut pas reposer sur des alarmes ; il faut un service de premier plan qui reçoit les positions en continu.
  - Point à mesurer : un bateau au mouillage est « immobile » pour le téléphone ; le comportement du service de premier plan en Doze profond doit être constaté au prototype.
- Une application avec un service de premier plan n'est pas considérée inactive par App Standby. Source : [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby).
- L'utilisateur peut exclure l'application de l'optimisation de la batterie (Paramètres > Batterie > Optimisation de la batterie). La demande directe `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` n'est acceptée par Google Play que si Doze empêche la fonction principale ; les « applications de sécurité qui protègent leurs utilisateurs et leurs familles » figurent parmi les cas acceptables. Source : [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby).
- Avec l'économiseur de batterie actif, `PowerManager.getLocationPowerSaveMode()` (Android 12+) indique si la localisation continue de fonctionner pour un service de premier plan écran éteint. Source : [Location permissions](https://developer.android.com/training/location/permissions).

### 2.4 Restrictions propres aux constructeurs

Les constructeurs ajoutent leurs propres « tueurs d'applications », au-delà d'Android. Le site communautaire [dontkillmyapp.com](https://dontkillmyapp.com/) les classe ; Samsung et Xiaomi y figurent parmi les plus agressifs (consulté par moteur de recherche seulement : site non joignable depuis l'environnement de cette étude ; pages par marque : [Xiaomi](https://dontkillmyapp.com/xiaomi), [Samsung](https://dontkillmyapp.com/samsung)). Réglages cités par des guides tiers, à vérifier sur appareil :

| Marque | Réglages à faire par l'utilisateur (libellés variables selon la version) | Source |
|--------|------------------------------------------------------------------------|--------|
| Xiaomi (MIUI, HyperOS) | « Démarrage automatique » activé ; économiseur de batterie de l'application sur « Aucune restriction » ; verrouiller l'application dans les applications récentes. | [AdGuard, travail en arrière-plan](https://adguard.com/kb/adguard-for-android/solving-problems/background-work/), [Biolovision, par marque](https://help.biolovision.net/Keep_Background_Services_Alive_on_Android_(by_Brand)) |
| Samsung (One UI) | Paramètres > Batterie > Limites d'utilisation en arrière-plan : mettre l'application dans les applications « jamais en veille ». Une application inutilisée depuis quelques jours peut être mise en veille automatiquement. | mêmes sources |
| Autres (Huawei, OnePlus, Oppo, Vivo…) | Réglages équivalents, à relever pendant le prototype. | [dontkillmyapp.com](https://dontkillmyapp.com/) |

Conséquence pour le produit : prévoir un écran d'aide par marque, ouvert au premier démarrage d'une navigation (à décider, voir § 5).

## 3. Reprise après fermeture forcée ou redémarrage (éclaire [D-51](../07-decisions.md#d-51))

- **Redémarrage** : un récepteur `BOOT_COMPLETED` peut démarrer un service de premier plan (exemption prévue). Android 15 interdit ce démarrage pour les types `dataSync`, `camera`, `mediaPlayback`, `phoneCall`, `mediaProjection` et `microphone`, **mais pas pour `location`**. Sources : [Restrictions on starting a foreground service from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [Android 15 behavior changes](https://developer.android.com/about/versions/15/behavior-changes-15).
  - Condition : comme le service `location` est alors créé depuis l'arrière-plan, il faut l'autorisation `ACCESS_BACKGROUND_LOCATION` (« Toujours autoriser ») ; sinon `SecurityException` (Android 14+). Même source.
  - Sans cette autorisation, la reprise automatique au redémarrage est impossible : seule reste la reprise au prochain lancement manuel de l'application (RG-NAV-12).
- **Fermeture par le système** (mémoire, constructeur) : un service redémarré par le système (`START_STICKY`) est démarré par un composant système, ce qui fait partie des exemptions aux restrictions « pendant l'utilisation ». Source : [Restrictions on starting a foreground service from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start). À constater sur Samsung et Xiaomi, dont les gestionnaires peuvent empêcher ce redémarrage.
- **Fermeture forcée par l'utilisateur** (« Forcer l'arrêt » dans les paramètres) : non traitée par les pages consultées ; d'après le fonctionnement connu d'Android, l'application ne reçoit plus aucune diffusion (y compris `BOOT_COMPLETED`) jusqu'au prochain lancement manuel. **À constater au prototype.** Le simple balayage dans les applications récentes n'arrête en principe pas un service de premier plan sur Android pur, mais certains constructeurs le font : à mesurer.
- Dans tous les cas, les positions déjà enregistrées sur le téléphone sont conservées (stockage local) ; seule la période d'arrêt manque.

## 4. Protocole du prototype (critères d'acceptation de TODO-2.2)

1. Application minimale : service de premier plan `location`, une position toutes les 3 minutes (RG-NAV-05), enregistrée en base locale avec l'heure d'acquisition (RG-GPS-02), sans réseau requis.
2. Téléphones : au moins trois marques, dont Samsung et Xiaomi (plus un Google Pixel comme référence Android pur), versions d'Android notées.
3. Essai de 8 heures, écran éteint, téléphone posé (cas du mouillage) puis en mouvement si possible ; deux configurations : réglages d'usine, puis réglages du § 2.4 appliqués.
4. Relever : nombre de positions attendues (160 pour 8 h) et reçues, plus long trou, pourcentage de batterie consommé, version d'Android, réglages constructeur.
5. Essais de reprise : redémarrage du téléphone (avec et sans « Toujours autoriser »), balayage dans les récents, « Forcer l'arrêt ».

## 5. Questions pour l'utilisateur (non tranchées)

- [D-51](../07-decisions.md#d-51) : reprise automatique après redémarrage, qui exige de demander « Toujours autoriser » la localisation (et de justifier cet accès auprès de Google Play), ou reprise seulement au lancement suivant de l'application.
- Écran d'aide par marque (Samsung, Xiaomi…) et demande d'exclusion de l'optimisation de la batterie : à proposer ou non au démarrage d'une navigation.
- [Q-31](../06-questions-ouvertes.md#q-31) : version minimale d'Android (les règles ci-dessus changent à Android 10, 12, 14 et 15).
