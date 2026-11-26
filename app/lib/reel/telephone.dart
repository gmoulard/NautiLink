import 'package:flutter/services.dart';

/// Réglages du téléphone Android, par le canal natif `fr.nautilink/telephone`
/// (`MainActivity.kt`) : exclusion de l'optimisation de la batterie et marque
/// du téléphone (RG-GPS-05), autorisation des notifications (Android 13 et
/// plus : notification du service de localisation et de la navigation).
class TelephoneAndroid {
  const TelephoneAndroid();

  static const _canal = MethodChannel('fr.nautilink/telephone');

  Future<bool> batterieExclue() async =>
      await _canal.invokeMethod<bool>('batterieExclue') ?? false;

  /// Ouvre la demande d'exclusion de l'optimisation de la batterie.
  Future<bool> demanderExclusionBatterie() async =>
      await _canal.invokeMethod<bool>('demanderExclusionBatterie') ?? false;

  /// Marque du téléphone, en minuscules (« samsung », « xiaomi »…).
  Future<String> fabricant() async =>
      (await _canal.invokeMethod<String>('fabricant') ?? '').toLowerCase();

  Future<bool> notificationsAutorisees() async =>
      await _canal.invokeMethod<bool>('notificationsAutorisees') ?? true;

  Future<bool> demanderNotifications() async =>
      await _canal.invokeMethod<bool>('demanderNotifications') ?? false;
}

/// Marque dont les réglages propres peuvent couper l'enregistrement des
/// positions écran éteint (RG-GPS-05, étude GPS en arrière-plan § 3) :
/// `samsung`, `xiaomi`, sinon vide (texte général).
String? marqueBatterie(String fabricant) {
  if (fabricant.contains('samsung')) return 'samsung';
  for (final m in const ['xiaomi', 'redmi', 'poco']) {
    if (fabricant.contains(m)) return 'xiaomi';
  }
  return null;
}
