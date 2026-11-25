import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';
import 'reel_widget_test.dart' show reveal, setPhone;

/// Écrans de navigation de la vraie application (TODO-5.2 à TODO-5.6).
void main() {
  late FauxServeurNautiLink serveur;
  late FauxGps gps;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    serveur = FauxServeurNautiLink()..navigationEnCours = false;
    gps = FauxGps(positionEssai());
  });

  /// Quelques images, sans attendre la fin : l'écran de navigation a des chronomètres.
  Future<void> attendre(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> toucher(WidgetTester tester, String texte) async {
    final f = find.text(texte).hitTestable();
    if (f.evaluate().isEmpty) await reveal(tester, find.text(texte));
    await tester.tap(find.text(texte).hitTestable().first);
    await attendre(tester);
  }

  Future<void> connecter(WidgetTester tester) async {
    setPhone(tester);
    final session = await tester.runAsync(StockageSession.ouvrir);
    await tester.pumpWidget(
      NautiLinkApp(
        depot: serveur.depot(session!, BaseMemoire(), positions: gps),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'marin@example.org',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'secret123',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    '« Démarrer navigation » : rappel, écran de démarrage, envoi, écran de navigation (TODO-5.2)',
    (tester) async {
      await connecter(tester);
      await toucher(tester, 'Démarrer navigation');
      // RG-NAV-23 : rappel avant la première navigation sur ce téléphone.
      expect(find.text('Avant votre première navigation'), findsOneWidget);
      await toucher(tester, 'J\'ai compris');

      expect(
        find.text('Bateau : Alizé'),
        findsOneWidget,
      ); // un seul bateau : pas de choix
      expect(find.text('Claire'), findsOneWidget); // personne alertée, cochée
      expect(
        find.text('1 heure'),
        findsOneWidget,
      ); // fréquence des paramètres généraux
      await tester.enterText(
        find.byKey(const Key('start-destination')),
        'Houat',
      );
      await tester.tap(find.byTooltip('Une personne de plus'));
      await attendre(tester);
      expect(find.text('2'), findsOneWidget);

      await toucher(tester, 'Envoi message – Début de navigation');
      // RG-COM-03 : résultat de chaque circuit.
      expect(find.text('Navigation démarrée'), findsOneWidget);
      expect(find.text('Serveur : envoyé'), findsOneWidget);
      await toucher(tester, 'OK');
      expect(find.text('Alizé — Houat'), findsOneWidget);
      expect(find.text('Depuis le début'), findsOneWidget);
      expect(find.textContaining('Début de navigation'), findsWidgets);
      final c = serveur.elements.single.$3 as Map;
      expect(c['personnesABord'], 2);
      expect(c['destination'], {'texte': 'Houat'});
    },
  );

  testWidgets(
    'quota épuisé : démarrage refusé, heure du retour des minutes et abonnement (RG-ECO-04)',
    (tester) async {
      serveur.quotaEpuise = true;
      await connecter(tester);
      await toucher(tester, 'Démarrer navigation');
      await toucher(tester, 'J\'ai compris');
      await toucher(tester, 'Envoi message – Début de navigation');
      expect(find.text('Démarrage refusé'), findsOneWidget);
      expect(
        find.textContaining('Quota de navigation gratuite épuisé'),
        findsOneWidget,
      );
      await toucher(tester, 'Quota et abonnement');
      expect(find.text('En savoir plus sur l\'abonnement'), findsOneWidget);
      expect(serveur.elements, isEmpty);
    },
  );

  testWidgets('adresse non confirmée : message du serveur', (tester) async {
    serveur.refusDemarrage = (
      403,
      'email_non_verifie',
      'Vérifiez d\'abord votre adresse e-mail.',
    );
    await connecter(tester);
    await toucher(tester, 'Démarrer navigation');
    await toucher(tester, 'J\'ai compris');
    await toucher(tester, 'Envoi message – Début de navigation');
    expect(
      find.text('Vérifiez d\'abord votre adresse e-mail.'),
      findsOneWidget,
    );
  });
}
