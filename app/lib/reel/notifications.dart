import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';

/// Notifications push de l'ami (RG-IOS-06, RG-AND-08) : jeton du
/// téléphone remis au serveur (`jetonPush` de `PUT /v1/appareils/{id}`) et
/// navigation ouverte quand l'ami touche une notification (RG-AND-09).
abstract class NotificationsPush {
  /// Jeton FCM sur Android, jeton APNs sur iPhone (le serveur passe par
  /// APNs, D-86) ; vide sans autorisation.
  Future<String?> jeton();

  /// Demande l'autorisation d'afficher les notifications (RG-AND-02 : au
  /// moment où elle sert, à l'ouverture de « Mes amis en mer »).
  Future<bool> demander();

  /// Nouveau jeton à remettre au serveur.
  Stream<String> get jetonsRenouveles;

  /// Navigation d'une notification touchée.
  Stream<String> get navigationsTouchees;

  /// Navigation de la notification qui a ouvert l'application.
  Future<String?> navigationInitiale();
}

/// Notifications par Firebase Cloud Messaging, avec l'application Firebase
/// donnée à la construction (`NAUTILINK_FCM_*`, `lib/config.dart`).
class PushFirebase implements NotificationsPush {
  PushFirebase._(this.ios);
  final bool ios;
  FirebaseMessaging get _m => FirebaseMessaging.instance;

  /// Vide sans configuration : pas de notifications.
  static Future<PushFirebase?> creer({required bool ios}) async {
    if (kFcmCle.isEmpty || kFcmApplication.isEmpty || kFcmProjet.isEmpty) {
      return null;
    }
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: kFcmCle,
          appId: kFcmApplication,
          messagingSenderId: kFcmExpediteur,
          projectId: kFcmProjet,
        ),
      );
      return PushFirebase._(ios);
    } catch (e) {
      debugPrint('Notifications : $e');
      return null;
    }
  }

  @override
  Future<bool> demander() async {
    final r = await _m.requestPermission();
    return r.authorizationStatus == AuthorizationStatus.authorized ||
        r.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> jeton() async {
    try {
      // Jeton d'enregistrement FCM, cible `message.token` de l'API HTTP v1
      // utilisée par le serveur (push.go).
      // ignore: deprecated_member_use
      return ios ? await _m.getAPNSToken() : await _m.getToken();
    } catch (e) {
      debugPrint('Jeton push : $e');
      return null;
    }
  }

  @override
  Stream<String> get jetonsRenouveles =>
      // ignore: deprecated_member_use
      ios ? const Stream.empty() : _m.onTokenRefresh;

  static String? _navigation(RemoteMessage m) {
    final id = m.data['navigationId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  Stream<String> get navigationsTouchees => FirebaseMessaging.onMessageOpenedApp
      .map(_navigation)
      .where((id) => id != null)
      .cast<String>();

  @override
  Future<String?> navigationInitiale() async {
    final m = await _m.getInitialMessage();
    return m == null ? null : _navigation(m);
  }
}
