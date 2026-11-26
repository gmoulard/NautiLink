import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';
import 'reel_widget_test.dart' show setPhone;

/// Langue de l'application : celle du téléphone par défaut, changeable dans
/// les paramètres, gardée par le compte pour les messages envoyés (RG-PRM-03,
/// RG-PRM-04).
void main() {
  testWidgets(
    'téléphone en anglais, puis français choisi dans « Paramètres » (RG-PRM-03)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final serveur = FauxServeurNautiLink()..navigationEnCours = false;
      setPhone(tester);
      final session = await tester.runAsync(StockageSession.ouvrir);
      await tester.pumpWidget(
        NautiLinkApp(
          depot: serveur.depot(session!, BaseMemoire()),
          langueDuTelephone: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'marin@example.org',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'secret123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Français (French)').last);
      await tester.pumpAndSettle();
      expect(find.text('Paramètres'), findsOneWidget);
      expect(session.langue, 'fr');
      expect(serveur.corps['PATCH /v1/compte'], {'langue': 'fr'});
    },
  );
}
