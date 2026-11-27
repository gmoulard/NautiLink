import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Que des amis (D-176, D-187) : aucun texte de l'application, en français
/// ni en anglais, ne parle des anciens rôles.
void main() {
  test('textes : aucun ancien rôle affiché (D-187)', () {
    final interdit = RegExp(
      r'suiveur|contacts? sos|follower|sos contact',
      caseSensitive: false,
    );
    for (final langue in ['fr', 'en']) {
      final texte = File('lib/l10n/app_$langue.arb').readAsStringSync();
      final valeurs = RegExp(
        r'^  "[a-zA-Z0-9_]+": "(.*)",?$',
        multiLine: true,
      ).allMatches(texte).map((m) => m.group(1)!);
      for (final v in valeurs) {
        expect(interdit.hasMatch(v), isFalse, reason: '$langue : $v');
      }
    }
  });
}
