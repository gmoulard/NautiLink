import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/reel/achats.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';
import 'reel_widget_test.dart' show reveal, setPhone;

/// « Souscrire l'abonnement » par le magasin du téléphone (RG-ECO-11,
/// RG-IOS-07, TODO-5.8, TODO-10.6).
void main() {
  Future<void> ouvrirQuota(WidgetTester tester, FauxAchats achats) async {
    SharedPreferences.setMockInitialValues({});
    final serveur = FauxServeurNautiLink()..navigationEnCours = false;
    setPhone(tester);
    final session = await tester.runAsync(StockageSession.ouvrir);
    await tester.pumpWidget(
      NautiLinkApp(
        depot: serveur.depot(session!, BaseMemoire(), achats: achats),
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
    await tester.tap(find.text('Quota et abonnement'));
    await tester.pumpAndSettle();
  }

  for (final (r, message) in [
    (ResultatAchat.ouvert, 'Abonnement ouvert pour 10 ans : merci !'),
    (
      ResultatAchat.refuse,
      'Paiement non confirmé : l\'abonnement n\'est pas ouvert.',
    ),
    (ResultatAchat.annule, 'Achat abandonné.'),
    (
      ResultatAchat.indisponible,
      'L\'achat de l\'abonnement par Google Play ou par l\'App Store n\'est pas encore ouvert dans l\'application.',
    ),
  ]) {
    testWidgets('achat : ${r.name}', (tester) async {
      final achats = FauxAchats(r, prixAffiche: '15,00 €');
      await ouvrirQuota(tester, achats);
      await reveal(tester, find.byKey(const Key('subscribe')));
      expect(find.text('Souscrire l\'abonnement — 15,00 €'), findsOneWidget);
      await tester.tap(find.byKey(const Key('subscribe')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(message), findsOneWidget);
      expect(achats.achats, 1);
    });
  }
}
