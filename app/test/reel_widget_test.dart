import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  // La liste de l'écran du dessus : les écrans précédents restent dans l'arbre.
  final list = find.byType(Scrollable).hitTestable().first;
  await tester.scrollUntilVisible(finder, 200, scrollable: list);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).hitTestable();
  if (f.evaluate().isEmpty) await reveal(tester, find.text(text));
  await tester.tap(find.text(text).hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  late FauxServeurNautiLink serveur;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    serveur = FauxServeurNautiLink();
  });

  Future<void> ouvrir(WidgetTester tester) async {
    setPhone(tester);
    final session = await tester.runAsync(StockageSession.ouvrir);
    await tester.pumpWidget(
      NautiLinkApp(depot: serveur.depot(session!, BaseMemoire())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'vraie application : connexion, Google et Apple désactivés, accueil branché sur le serveur',
    (tester) async {
      await ouvrir(tester);
      expect(find.text('Connexion'), findsWidgets);
      expect(find.text('Version bêta'), findsOneWidget); // RG-CPT-07
      final google = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Continuer avec Google'),
      );
      final apple = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Continuer avec Apple'),
      );
      expect(google.onPressed, isNull);
      expect(apple.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'marin@example.org',
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'faux');
      await tapText(tester, 'Se connecter');
      expect(
        find.text('Adresse e-mail ou mot de passe incorrect.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('login-password')),
        'secret123',
      );
      await tapText(tester, 'Se connecter');
      expect(find.text('Démarrer navigation'), findsOneWidget);
      expect(find.text('Navigation en cours : Alizé — Houat'), findsOneWidget);
      expect(
        find.textContaining('19 h 00 min de navigation gratuite'),
        findsOneWidget,
      );
      expect(find.text('Envoyer un SOS'), findsOneWidget);
      expect(find.text('Mémo sécurité en mer'), findsOneWidget);
      // Une navigation est en cours : « Démarrer navigation » est inactif.
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Démarrer navigation'),
                matching: find.bySubtype<ButtonStyleButton>(),
              ),
            )
            .onPressed,
        isNull,
      );

      await tapText(tester, 'Navigations enregistrées');
      expect(find.text('Alizé — Belle-Île'), findsOneWidget);
    },
  );

  testWidgets(
    'hors connexion à l\'ouverture : session gardée, accueil sur les données locales (RG-COM-06)',
    (tester) async {
      await ouvrir(tester);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'marin@example.org',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'secret123',
      );
      await tapText(tester, 'Se connecter');
      expect(find.text('Navigation en cours : Alizé — Houat'), findsOneWidget);

      serveur.coupe = true;
      // Accueil tiré vers le bas : actualisation sans réseau.
      await tester.drag(find.text('Démarrer navigation'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hors connexion · données du'),
        findsOneWidget,
      );
      expect(find.textContaining('État du'), findsOneWidget);
      expect(find.text('Navigation en cours : Alizé — Houat'), findsOneWidget);

      await tapText(tester, 'Navigations enregistrées');
      expect(
        find.textContaining('Hors connexion : dernière liste reçue le'),
        findsOneWidget,
      );
      await tapText(tester, 'Alizé — Belle-Île');
      expect(
        find.text(
          'La page de la navigation sera disponible au retour de la connexion.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'création du compte : bouton actif seulement une fois l\'avertissement accepté (RG-CPT-06)',
    (tester) async {
      await ouvrir(tester);
      await tapText(tester, 'Créer un compte');
      expect(find.text('Version bêta et responsabilité'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('account-name')), 'Marin');
      await tester.enterText(
        find.byKey(const Key('account-email')),
        'marin@example.org',
      );
      await tester.enterText(
        find.byKey(const Key('account-password')),
        'secret123',
      );
      await reveal(tester, find.text('Créer mon compte'));
      final bouton = find.widgetWithText(FilledButton, 'Créer mon compte');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
      await tapText(tester, 'J\'ai lu et j\'accepte cet avertissement');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNotNull);
      await tapText(tester, 'Créer mon compte');
      expect(find.text('Démarrer navigation'), findsOneWidget);
      // Adresse pas encore confirmée (RG-CPT-09).
      expect(
        find.textContaining(
          'Confirmez votre adresse e-mail (marin@example.org)',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Recevoir un nouveau lien');
      expect(find.text('Lien envoyé.'), findsOneWidget);
    },
  );

  testWidgets(
    '« Mot de passe oublié ? » (RG-CPT-10) et avertissement changé (428)',
    (tester) async {
      await ouvrir(tester);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'marin@example.org',
      );
      await tapText(tester, 'Mot de passe oublié ?');
      await tapText(tester, 'Recevoir le lien');
      expect(find.byKey(const Key('forgot-sent')), findsOneWidget);
      expect(serveur.corps['POST /v1/compte/mot-de-passe/oubli'], {
        'email': 'marin@example.org',
      });
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      serveur
        ..avertissementChange = true
        ..avertissement = '2027-01-01';
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'secret123',
      );
      await tapText(tester, 'Se connecter');
      expect(
        find.text(
          'L\'avertissement a changé : lisez-le et acceptez-le pour continuer.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'J\'ai lu et j\'accepte cet avertissement');
      await tapText(tester, 'Continuer');
      expect(find.text('Démarrer navigation'), findsOneWidget);
      expect(
        (serveur.corps['POST /v1/sessions'] as Map)['avertissementVersion'],
        '2027-01-01',
      );
    },
  );

  testWidgets('déconnexion : retour à l\'écran de connexion', (tester) async {
    await ouvrir(tester);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'marin@example.org',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'secret123',
    );
    await tapText(tester, 'Se connecter');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Contacts'), findsNothing); // TODO-5.7
    await tapText(tester, 'Se déconnecter');
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
