import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../depot/depot.dart';

/// Position non disponible (Web, essais) : aucune position, aucun suivi.
class PositionsIndisponibles implements SourcePosition {
  const PositionsIndisponibles();

  @override
  Future<PositionGps?> positionActuelle({bool demander = false}) async => null;

  @override
  PositionGps? get derniereConnue => null;

  @override
  Stream<PositionGps> suivre(Duration frequence) => const Stream.empty();
}

/// GPS du téléphone (paquet `geolocator`) : fonctionne sans Internet ni réseau
/// mobile (RG-GPS-01) ; chaque position porte son heure d'acquisition
/// (RG-GPS-02).
///
/// - Position actuelle : le GPS n'est allumé que le temps de l'acquisition
///   (RG-GPS-06), avec un délai maximal [delaiAcquisition] ; sans réponse,
///   rien n'est rendu.
/// - Autorisation : localisation précise demandée au moment où elle sert,
///   à l'écran (RG-AND-02) ; refusée, la navigation se déroule sans positions
///   et l'autorisation est redemandée à chaque acquisition faite à l'écran
///   (RG-AND-03). Position approximative seulement : traitée comme un refus
///   (inutilisable en mer, étude des autorisations Android).
/// - Suivi : sur Android, flux de positions à la fréquence de la navigation,
///   porté par le service de premier plan de type `location` de `geolocator`
///   avec sa notification permanente : la minuterie est celle du service de
///   localisation, sans alarme exacte (RG-AND-05).
class GpsTelephone implements SourcePosition {
  GpsTelephone({
    this.delaiAcquisition = const Duration(seconds: 45),
    this.titreNotification = 'NautiLink : navigation en cours',
    this.texteNotification =
        'Positions enregistrées à la fréquence de la navigation.',
  });

  final Duration delaiAcquisition;
  final String titreNotification;
  final String texteNotification;

  PositionGps? _derniere;

  @override
  PositionGps? get derniereConnue => _derniere;

  static PositionGps _depuis(Position p) => PositionGps(
    latitude: p.latitude,
    longitude: p.longitude,
    heureAcquisition: p.timestamp.toLocal(),
    precisionMetres: p.accuracy > 0 ? p.accuracy : null,
  );

  /// Vrai si la localisation précise est déjà accordée (sans demande).
  Future<bool> autorisee() => _autorisee(false);

  /// Vrai si la localisation précise est accordée ; avec [demander], la
  /// demande est faite (boîte du système).
  Future<bool> _autorisee(bool demander) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var a = await Geolocator.checkPermission();
      if (demander && a == LocationPermission.denied) {
        a = await Geolocator.requestPermission();
      }
      if (a != LocationPermission.always &&
          a != LocationPermission.whileInUse) {
        return false;
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final precision = await Geolocator.getLocationAccuracy();
        if (precision == LocationAccuracyStatus.reduced) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Autorisation de localisation : $e');
      return false;
    }
  }

  @override
  Future<PositionGps?> positionActuelle({bool demander = false}) async {
    if (!await _autorisee(demander)) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: delaiAcquisition,
        ),
      );
      return _derniere = _depuis(p);
    } catch (e) {
      debugPrint('Position actuelle : $e');
      return null;
    }
  }

  @override
  Stream<PositionGps> suivre(Duration frequence) {
    late StreamController<PositionGps> c;
    StreamSubscription<Position>? abonnement;
    c = StreamController<PositionGps>(
      onListen: () async {
        if (!await _autorisee(false)) return;
        final LocationSettings reglages;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          reglages = AndroidSettings(
            accuracy: LocationAccuracy.high,
            intervalDuration: frequence,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: titreNotification,
              notificationText: texteNotification,
              notificationChannelName: 'Navigation en cours',
              enableWakeLock: true,
              setOngoing: true,
            ),
          );
        } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          // RG-IOS-08 : autorisation « Pendant l'utilisation », navigation
          // démarrée à l'écran puis poursuivie en arrière-plan (mode
          // `location` de Info.plist), indicateur bleu affiché ; pause
          // automatique désactivée, sinon un bateau au mouillage perdrait
          // ses positions (étude localisation iPhone § 2.3).
          reglages = AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.otherNavigation,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );
        } else {
          reglages = const LocationSettings(accuracy: LocationAccuracy.high);
        }
        if (c.isClosed) return;
        abonnement = Geolocator.getPositionStream(locationSettings: reglages)
            .listen(
              (p) => c.add(_derniere = _depuis(p)),
              onError: (Object e) => debugPrint('Suivi des positions : $e'),
            );
      },
      onCancel: () async {
        await abonnement?.cancel();
        abonnement = null;
      },
    );
    return c.stream;
  }
}
