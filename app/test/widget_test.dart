import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/data.dart';
import 'package:nautilink/main.dart';

Future<void> reveal(WidgetTester tester, String text) async {
  // La liste de l'écran du dessus : les écrans précédents restent dans l'arbre.
  final list = find.byType(Scrollable).hitTestable().first;
  await tester.scrollUntilVisible(find.text(text), 200, scrollable: list);
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

/// Accepte l'avertissement (RG-CPT-06) et arrive sur l'accueil.
Future<void> openHome(WidgetTester tester) async {
  await tester.pumpWidget(const NautiLinkApp());
  expect(find.text('Version bêta et responsabilité'), findsOneWidget);
  await reveal(tester, 'J\'ai lu et j\'accepte cet avertissement');
  await tester.tap(find.text('J\'ai lu et j\'accepte cet avertissement'));
  await tester.pump();
  await reveal(tester, 'Continuer');
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
}

/// Démarre une navigation depuis l'accueil (RG-NAV-23 compris).
Future<void> startVoyage(WidgetTester tester) async {
  await tester.tap(find.text('Démarrer navigation'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('J\'ai compris'));
  await tester.pumpAndSettle();
  await reveal(tester, 'Envoi message – Début de navigation');
  await tester.tap(find.text('Envoi message – Début de navigation'));
  await tester.pumpAndSettle();
  expect(find.text('Depuis le début'), findsOneWidget);
}

void main() {
  test('fréquences de 15 minutes à 10 jours (RG-NAV-05)', () {
    expect(frequencies.values.toList(), [
      '15 minutes', '30 minutes', '1 heure', '2 heures', '3 heures',
      '6 heures', '12 heures', '1 jour', '2 jours', '10 jours',
    ]);
    expect(frequencies.containsKey(AppState().defaultFrequency), isTrue);
  });

  test('immobilité : 2 heures dans un rayon de 20 m (RG-NAV-24)', () {
    final s = AppState();
    s.startVoyage(boat: s.boats.first, frequency: 30);
    expect(s.isStationary(), isFalse);
    s.simulateStationary();
    expect(s.isStationary(), isTrue);
    s.addEvent(EventKind.manualPosition); // le bateau repart
    expect(s.isStationary(), isFalse);
  });

  testWidgets('accueil : lien « Version gratuite - abonnement » (RG-ECO-10)', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await tester.tap(find.text('Version gratuite - abonnement'));
    await tester.pumpAndSettle();
    expect(find.text('Quota et abonnement'), findsOneWidget);
    await reveal(tester, 'En savoir plus sur l\'abonnement');
    expect(find.text('En savoir plus sur l\'abonnement'), findsOneWidget);
  });

  testWidgets('envoi : fenêtre « OK », fermée seule après 1 minute, chronomètre remis à zéro', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await startVoyage(tester);

    // Les chronomètres suivent l'heure réelle : laisser passer 2 vraies secondes.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2100)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00:02'), findsNWidgets(2));

    // RG-COM-03 et RG-NAV-10.
    await tester.tap(find.text('NOTE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tout va bien');
    await tester.tap(find.text('Valider l\'envoi'));
    await tester.pumpAndSettle();
    expect(find.text('Note envoyée'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('00:00:02'), findsOneWidget); // depuis le début seulement
    expect(find.text('00:00:00'), findsOneWidget); // dernier envoi remis à zéro
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Note envoyée'), findsNothing);

    await tester.tap(find.text('Envoyer information position'));
    await tester.pumpAndSettle();
    expect(find.text('Position envoyée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Position envoyée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Position envoyée'), findsNothing);

    // RG-NAV-24 : immobile depuis 2 heures, proposition de fin.
    await tester.tap(find.byTooltip('Démonstration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Démo : simuler 2 h sans bouger'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation terminée ?'), findsOneWidget);
    await tester.tap(find.text('Terminer la navigation').last);
    await tester.pumpAndSettle();
    expect(find.text('Démarrer navigation'), findsOneWidget);
  });

  testWidgets('SOS avec confirmation puis fin de navigation', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await startVoyage(tester);

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
