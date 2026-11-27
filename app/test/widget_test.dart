import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/data.dart';
import 'package:nautilink/l10n/app_localizations.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/screens/dashboard.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  // La liste de l'écran du dessus : les écrans précédents restent dans l'arbre.
  final list = find.byType(Scrollable).hitTestable().first;
  await tester.scrollUntilVisible(finder, 200, scrollable: list);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await reveal(tester, find.text(text));
  await tester.tap(find.text(text));
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
  await reveal(tester, find.text('J\'ai lu et j\'accepte cet avertissement'));
  await tester.tap(find.text('J\'ai lu et j\'accepte cet avertissement'));
  await tester.pump();
  await tapText(tester, 'Continuer');
}

/// Ouvre l'écran de démarrage (RG-NAV-23 compris).
Future<void> openStart(WidgetTester tester) async {
  await tester.tap(find.text('Démarrer navigation'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('J\'ai compris'));
  await tester.pumpAndSettle();
}

Future<void> startVoyage(WidgetTester tester) async {
  await openStart(tester);
  await tapText(tester, 'Début de navigation');
  expect(find.text('Depuis le début'), findsOneWidget);
}

void main() {
  setUpAll(() => SeaMap.tilesEnabled = false); // pas de réseau pendant les tests

  test('fréquences de 15 minutes à 10 jours (RG-NAV-05)', () {
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(frequencies.map((f) => frequencyLabel(l, f)).toList(), [
      '15 minutes', '30 minutes', '1 heure', '2 heures', '3 heures',
      '6 heures', '12 heures', '1 jour', '2 jours', '10 jours',
    ]);
    expect(frequencies.contains(AppState().defaultFrequency), isTrue);
  });

  test('textes de data.dart traduits : fréquences, événements, lieux (TODO-9.2)', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(frequencyLabel(en, 60), '1 hour');
    expect(frequencyLabel(en, 14400), '10 days');
    expect(LogEvent(EventKind.start, DateTime.now(), frequency: 30).details(en), 'Frequency: 30 minutes');
    expect(placeName(en, Position(47.47, -3.08, DateTime.now())), contains(' nm from '));
    expect(smsTypeLabel(en, SmsType.note), 'Written notes');
  });

  test('navigation d\'exemple Port du Niel → Toulon, Vieille Darse', () {
    final l = lookupAppLocalizations(const Locale('fr'));
    final v = AppState().voyages.firstWhere((v) => v.name == 'Alizé — Toulon, Vieille Darse');
    expect(placeName(l, v.track.first), 'Port du Niel, Giens');
    expect(placeName(l, v.track.last), 'Toulon, Vieille Darse');
    expect(v.distanceNm, closeTo(11.6, 0.2));
    expect(v.end!.difference(v.start).inMinutes, closeTo(127, 2));
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

  test('nom du lieu le plus proche (RG-JRN-10) et météo au début et à la fin (RG-NAV-28)', () {
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(placeName(l, Position(47.488, -3.100, DateTime.now())), 'Port-Haliguen');
    expect(placeName(l, Position(47.47, -3.08, DateTime.now())), startsWith('à '));
    expect(placeName(l, Position(45.0, -6.0, DateTime.now())), contains('N'));
    final s = AppState();
    s.startVoyage(boat: s.boats.first, frequency: 30, persons: 3);
    final v = s.current!;
    expect(v.weatherStart, contains('nœuds'));
    expect(v.weatherEnd, isNull);
    s.endVoyage();
    expect(v.weatherEnd, contains('hPa'));
    expect(s.lastPersonsOnBoard, 3);
  });

  test('contact décoché : pas d\'alerte SOS pendant la navigation (RG-NAV-25)', () {
    final s = AppState();
    final all = s.alertable.map((c) => c.name).toSet();
    s.startVoyage(boat: s.boats.first, frequency: 30, alerted: all..remove('Marc (voisin de ponton)'));
    expect(s.sosContactsNow.map((c) => c.name), ['Claire (sœur)']);
  });

  testWidgets('deuxième langue : essai en anglais (TODO-9.2)', (tester) async {
    setPhone(tester);
    await tester.pumpWidget(const NautiLinkApp(locale: Locale('en')));
    expect(find.text('Beta version and liability'), findsOneWidget);
    await reveal(tester, find.text('I have read and accept this warning'));
    await tester.tap(find.text('I have read and accept this warning'));
    await tester.pump();
    await tapText(tester, 'Continue');
    expect(find.text('Start voyage'), findsOneWidget);
    expect(find.text('Send an SOS'), findsOneWidget);
  });

  testWidgets('accueil : guidon de la SRT sans texte, lien « Version gratuite » (RG-ECO-10, D-131)', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await reveal(tester, find.byKey(const Key('home-sponsor')));
    expect(find.byKey(const Key('home-sponsor')), findsOneWidget);
    expect(find.text('Sponsorisée par la SRT'), findsNothing);
    // Pied de page de tous les écrans (D-128) : licence, dépôt, version.
    expect(find.text('Tous droits réservés · '), findsOneWidget);
    expect(find.text('https://github.com/gmoulard/NautiLink'), findsOneWidget);
    expect(find.text(' · version locale'), findsOneWidget);
    await reveal(tester, find.text('Version gratuite'));
    await tester.tap(find.text('Version gratuite'));
    await tester.pumpAndSettle();
    expect(find.text('Quota et abonnement'), findsOneWidget);
    expect(find.text('Tous droits réservés · '), findsOneWidget);
    await reveal(tester, find.text('En savoir plus sur l\'abonnement'));
    expect(find.text('En savoir plus sur l\'abonnement'), findsOneWidget);
  });

  testWidgets('accueil : lien « Mémo sécurité en mer » (TODO-3.12)', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await reveal(tester, find.text('Mémo sécurité en mer'));
    expect(find.text('Mémo sécurité en mer'), findsOneWidget);
    expect(securityMemoUrl, 'https://gmoulard.github.io/NautiLink/securite.html');
  });

  testWidgets('pied de page : lien « Site de NautiLink » sous le sponsor (TODO-3.13)', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await reveal(tester, find.text('Site de NautiLink'));
    expect(find.text('Site de NautiLink'), findsOneWidget);
    expect(siteUrl, 'https://nautilink.moulard.org/index.html');
  });

  testWidgets('démarrage : personnes à bord, personnes alertées, ajout d\'un contact (RG-NAV-25 à 27)', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await openStart(tester);
    expect(tester.widget<Text>(find.byKey(const Key('persons'))).data, '1');
    await tester.tap(find.byTooltip('Une personne de plus'));
    await tester.tap(find.byTooltip('Une personne de plus'));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('persons'))).data, '3');

    await reveal(tester, find.text('Personnes alertées'));
    expect(find.text('Claire (sœur)'), findsOneWidget);
    await tapText(tester, 'Ajouter une personne');
    await tester.enterText(find.byKey(const Key('add-name')), 'Yann');
    await tester.enterText(find.byKey(const Key('add-phone')), '06 11 22 33 44');
    await tester.pump();
    await tapText(tester, 'Ajouter');
    await reveal(tester, find.text('Yann'));
    expect(find.text('Yann'), findsOneWidget);
    expect(find.text('06 11 22 33 44'), findsWidgets);

    await tapText(tester, 'Début de navigation');
    // SOS avec problème rencontré (RG-SOS-02, RG-SOS-07).
    await tapText(tester, 'Envoyer un SOS');
    await tester.enterText(find.byKey(const Key('sos-problem')), 'Avarie de safran');
    await tester.tap(find.text('Confirmer le SOS'));
    await tester.pumpAndSettle();
    final sms = tester.widget<Text>(find.byKey(const Key('sos-sms'))).data!;
    expect(sms, contains('3 personnes à bord'));
    expect(sms, contains('Problème : Avarie de safran'));
    expect(find.text('Yann'), findsOneWidget);
  });

  testWidgets('envoi : fenêtre « OK » fermée après 1 minute, chronomètre, note vocale enregistrée', (tester) async {
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
    expect(find.text('00:00:02'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // RG-JRN-04 : enregistrement de la voix, sans transcription.
    await tester.tap(find.text('Vocal'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Enregistrement en cours'), findsOneWidget);
    await tester.tap(find.text('Arrêter et envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Note vocale envoyée'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await reveal(tester, find.textContaining('Enregistrement · 0:0'));
    expect(find.textContaining('Enregistrement · 0:0'), findsOneWidget);
    await reveal(tester, find.text('Envoyer position'));

    await tester.tap(find.text('Envoyer position'));
    await tester.pumpAndSettle();
    expect(find.text('Position envoyée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Position envoyée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Position envoyée'), findsNothing);

    // RG-NAV-24 puis RG-NAV-13 : fin proposée, puis page détaillée.
    await tester.tap(find.byTooltip('Démonstration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Démo : simuler 2 h sans bouger'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation terminée ?'), findsOneWidget);
    await tester.tap(find.text('Terminer la navigation').last);
    await tester.pumpAndSettle();
    expect(find.text('Journal de bord'), findsOneWidget);
    expect(find.text('Météo à l\'arrivée'), findsOneWidget);
  });

  testWidgets('fin de navigation : page détaillée avec météo, lieux et journal (RG-NAV-13, RG-NAV-28, RG-JRN-09)', (tester) async {
    setPhone(tester);
    await openHome(tester);
    await startVoyage(tester);
    await tapText(tester, 'Terminer la navigation');
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Personnes à bord'), findsOneWidget);
    expect(find.text('Météo au départ'), findsOneWidget);
    expect(find.text('Lieu de départ'), findsOneWidget);
    expect(find.text('Port-Haliguen'), findsWidgets);
    await tester.tap(find.byType(BackButton)); // pageBack() cherche l'infobulle anglaise « Back »
    await tester.pumpAndSettle();
    expect(find.text('Démarrer navigation'), findsOneWidget);

    // Photo en grand et écoute dans le journal d'une navigation passée.
    await tapText(tester, 'Navigations enregistrées');
    await tapText(tester, 'Alizé — Belle-Île');
    await tapText(tester, 'Phare de Kerdonis par le travers');
    expect(find.text('Fermer'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Enregistrement · 0:14');
    expect(find.text('Écoute de la note vocale'), findsOneWidget);
  });
}
