import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/screens/memo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'mémo sécurité en mer intégré : copie à jour de la section #securite de site/index.html (RG-SOS-22, D-192)',
    () async {
      final integre = await rootBundle.loadString(securityMemoAsset);
      final dossier = Directory.systemTemp.createTempSync('memo');
      final attendu = '${dossier.path}/securite.html';
      final r = Process.runSync('sh', ['outils/copier-memo.sh', attendu]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final site = File(attendu).readAsStringSync();
      dossier.deleteSync(recursive: true);
      expect(
        integre == site,
        isTrue,
        reason:
            'Mémo de l\'application périmé : lancer app/outils/copier-memo.sh',
      );
      expect(integre, contains('Mémo sécurité en mer'));
      expect(integre, contains('196'));
      // Mémo, puis avertissement ; lisible hors ligne, sans les ressources du site.
      expect(integre, contains('id="securite"'));
      expect(integre, contains('id="avertissement"'));
      expect(integre, contains('Préparer son message MAYDAY'));
      expect(integre, isNot(contains('href="style.css"')));
      expect(integre, isNot(contains('src="assets/')));
      expect(integre, isNot(contains('class="topnav"')));
    },
  );
}
