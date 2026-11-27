import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:nautilink/screens/dashboard.dart' show SeaMap;
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';
import 'reel_widget_test.dart' show setPhone;

/// Vue suiveur de la vraie application, sur Android et iPhone (RG-IOS-05,
/// RG-AND-09, D-143).
void main() {
  late FauxServeurNautiLink serveur;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    serveur = FauxServeurNautiLink()..navigationEnCours = false;
    SeaMap.tilesEnabled = false; // aucun accès réseau pendant les essais
  });

  Future<void> attendre(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  for (final plateforme in ['android', 'ios']) {
    testWidgets(
      'navigations suivies : tableau de bord, page avec carte, journal, alerte SOS, mise à jour ($plateforme)',
      (tester) async {
        setPhone(tester);
        final session = await tester.runAsync(StockageSession.ouvrir);
        await tester.pumpWidget(
          NautiLinkApp(
            depot: serveur.depot(
              session!,
              BaseMemoire(),
              plateforme: plateforme,
            ),
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

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Navigations suivies'));
        await attendre(tester);
        // Navigations en cours d'abord, puis l'historique (D-23).
        expect(find.text('En cours'), findsOneWidget);
        expect(find.text('Mistral — Glénan'), findsOneWidget);
        expect(find.text('Historique'), findsOneWidget);
        // Filtre « Comme navigateur » : la navigation suivie disparaît.
        await tester.tap(find.text('Comme navigateur'));
        await attendre(tester);
        expect(find.text('Mistral — Glénan'), findsNothing);
        await tester.tap(find.text('Toutes'));
        await attendre(tester);

        await tester.tap(find.text('Mistral — Glénan'));
        await attendre(tester);
        expect(find.byKey(const Key('follow-live')), findsOneWidget);
        expect(find.text('Navigateur : Yann'), findsOneWidget);
        expect(find.text('Lieu de départ : Concarneau'), findsOneWidget);
        expect(find.byKey(const Key('follow-map')), findsOneWidget);
        expect(find.text('Alertes SOS de la navigation'), findsOneWidget);
        expect(find.textContaining('Voie d\'eau'), findsOneWidget);
        expect(find.text('Fiche du bateau'), findsOneWidget);
        // D-176 : une seule liste « Amis », plus de « Suiveurs » ni de
        // « Contacts SOS » ; RG-NAV-29 : mention des fonds de carte.
        expect(find.textContaining('Amis ('), findsOneWidget);
        expect(find.textContaining('Contacts SOS'), findsNothing);
        expect(find.textContaining('Suiveurs'), findsNothing);
        expect(find.byKey(const Key('map-attribution')), findsOneWidget);
        expect(find.textContaining('Photo'), findsWidgets);

        // Nouvelle position reçue par le serveur : relue sans recharger.
        serveur.journalSuivi.add({
          '_rang': 3,
          'id': 'e3',
          'type': 'position_automatique',
          'heureAcquisition': '2026-11-26T10:00:00+01:00',
          'position': {
            'latitude': 47.75,
            'longitude': -3.98,
            'heureAcquisition': '2026-11-26T10:00:00+01:00',
          },
        });
        await tester.pump(const Duration(seconds: 31));
        await attendre(tester);
        expect(find.textContaining('47.75000, -3.98000'), findsOneWidget);
        expect(
          serveur.adresses.any(
            (u) =>
                u.path.endsWith('/s1/evenements') &&
                u.queryParameters['depuis'] == '2',
          ),
          isTrue,
        );
        // Lecture seule : aucun envoi vers le serveur.
        expect(
          serveur.appels.where(
            (a) => a.contains('/s1') && !a.startsWith('GET'),
          ),
          isEmpty,
        );
      },
    );
  }
}
