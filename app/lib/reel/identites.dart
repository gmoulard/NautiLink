import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';

/// Connexion par Google et par Apple (RG-CPT-02, RG-CPT-11) : le téléphone
/// obtient un jeton d'identité, que le serveur vérifie (`POST /v1/sessions`
/// avec `fournisseur` et `jetonIdentite`). Actives seulement avec leurs
/// identifiants clients, donnés à la construction (`lib/config.dart`).
class Identites {
  const Identites();

  bool get google => kGoogleServeur.isNotEmpty && !kIsWeb;

  /// Apple sur iPhone seulement.
  bool get apple =>
      kAppleConnexion && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool _googlePret = false;

  /// Jeton d'identité Google ; vide si le navigateur abandonne.
  Future<String?> jetonGoogle() async {
    final g = GoogleSignIn.instance;
    if (!_googlePret) {
      await g.initialize(
        clientId: kGoogleClientIos.isEmpty ? null : kGoogleClientIos,
        serverClientId: kGoogleServeur,
      );
      _googlePret = true;
    }
    try {
      final compte = await g.authenticate();
      return compte.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Jeton d'identité Apple ; vide si le navigateur abandonne.
  Future<String?> jetonApple() async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      return c.identityToken;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}
