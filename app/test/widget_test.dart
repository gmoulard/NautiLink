import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';

Future<void> reveal(WidgetTester tester, String text) async {
  // La liste de l'écran du dessus : les écrans précédents restent dans l'arbre.
  final list = find.byType(Scrollable).hitTestable().first;
  await tester.scrollUntilVisible(find.text(text), 200, scrollable: list);
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('avertissement, démarrage, SOS et fin de navigation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const NautiLinkApp());

    // RG-CPT-06 : pas d'accès sans accepter l'avertissement.
    expect(find.text('Version bêta et responsabilité'), findsOneWidget);
    await reveal(tester, 'J\'ai lu et j\'accepte cet avertissement');
    await tester.tap(find.text('J\'ai lu et j\'accepte cet avertissement'));
    await tester.pump();
    await reveal(tester, 'Continuer');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Accueil mobile.
    expect(find.text('Démarrer navigation'), findsOneWidget);
    await tester.tap(find.text('Démarrer navigation'));
    await tester.pumpAndSettle();

    // RG-NAV-23 : rappel avant la première navigation.
    expect(find.text('J\'ai compris'), findsOneWidget);
    await tester.tap(find.text('J\'ai compris'));
    await tester.pumpAndSettle();

    await reveal(tester, 'Envoi message – Début de navigation');
    await tester.tap(find.text('Envoi message – Début de navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Depuis le début'), findsOneWidget);

    await tester.tap(find.text('Envoyer information position'));
    await tester.pump();
    expect(find.textContaining('Position envoyée'), findsWidgets);

    // RG-SOS-02 : confirmation avant l'envoi.
    await reveal(tester, 'Envoyer un SOS');
    await tester.tap(find.text('Envoyer un SOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer le SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Alerte SOS'), findsOneWidget);
    await reveal(tester, 'Retour');
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    await reveal(tester, 'Terminer la navigation');
    await tester.tap(find.text('Terminer la navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Démarrer navigation'), findsOneWidget);
  });
}
