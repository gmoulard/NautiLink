import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/screens/memo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mémo sécurité en mer intégré : copie à jour de site/securite.html (RG-SOS-22)', () async {
    final integre = await rootBundle.loadString(securityMemoAsset);
    final site = File('../site/securite.html').readAsStringSync();
    expect(
      integre == site,
      isTrue,
      reason:
          'Mémo de l\'application périmé : lancer app/outils/copier-memo.sh',
    );
    expect(integre, contains('Mémo sécurité en mer'));
    expect(integre, contains('196'));
  });
}
