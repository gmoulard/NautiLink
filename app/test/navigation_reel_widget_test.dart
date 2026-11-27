import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/screens/dashboard.dart' show SeaMap;
import 'package:nautilink/screens/navigation_reel.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';
import 'reel_widget_test.dart' show reveal, setPhone;

/// Écrans de navigation de la vraie application (TODO-5.2 à TODO-5.6).
void main() {
  late FauxServeurNautiLink serveur;
  late FauxGps gps;
  late FauxMedias medias;
  late FauxSms sms;

  setUp(() {
    sms = FauxSms();
    SharedPreferences.setMockInitialValues({});
    serveur = FauxServeurNautiLink()..navigationEnCours = false;
    gps = FauxGps(positionEssai());
    medias = FauxMedias();
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

  /// « Début de navigation », avec l'explication de
  /// l'autorisation d'envoi de SMS, redemandée tant qu'elle manque (RG-AND-02).
  Future<void> demarrer(WidgetTester tester) async {
    await toucher(tester, 'Début de navigation');
    if (find.text('Envoi de SMS').evaluate().isNotEmpty) {
      await toucher(tester, 'OK');
    }
  }

  Future<void> connecter(
    WidgetTester tester, {
    String plateforme = 'android',
  }) async {
    setPhone(tester);
    final session = await tester.runAsync(StockageSession.ouvrir);
    await tester.pumpWidget(
      NautiLinkApp(
        depot: serveur.depot(
          session!,
          BaseMemoire(),
          positions: gps,
          medias: medias,
          // Pas de SMS sur iPhone (RG-IOS-02).
          sms: plateforme == 'ios' ? null : sms,
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
      // TODO-5.13, TODO-5.14 : « Début de navigation » au-dessus des
      // personnes alertées et de leur titre.
      final bouton = tester.getTopLeft(find.byKey(const Key('start-send'))).dy;
      expect(
        bouton,
        lessThan(tester.getTopLeft(find.text('Personnes alertées')).dy),
      );
      expect(bouton, lessThan(tester.getTopLeft(find.text('Claire')).dy));
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

      await demarrer(tester);
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
    'remarques du 2026-11-26 : E-mail et SMS par personne, chronomètres, météo, « Envoyer position », mémo en pied de page (Q-102)',
    (tester) async {
      await connecter(tester);
      // Mémo sécurité en mer sous le SOS et en pied de page de l'accueil.
      expect(find.byKey(const Key('home-memo')), findsOneWidget);
      await reveal(tester, find.byKey(const Key('footer-memo')));
      expect(find.byKey(const Key('footer-memo')), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await attendre(tester);
      await toucher(tester, 'Démarrer navigation');
      await toucher(tester, 'J\'ai compris');
      // Claire : numéro sans adresse : « SMS » coché, « E-mail » impossible.
      expect(find.text('suiveur · contact SOS'), findsNothing);
      // TODO-5.14 : tableau sans bordure, cases « E-mail » et « SMS ».
      expect(find.byKey(const Key('alerted-table')), findsOneWidget);
      final email = tester.widget<Checkbox>(
        find.byKey(const Key('alert-email-c1')),
      );
      final smsChoix = tester.widget<Checkbox>(
        find.byKey(const Key('alert-sms-c1')),
      );
      expect(email.value, isFalse);
      expect(email.onChanged, isNull);
      expect(smsChoix.value, isTrue);
      // « Début de navigation », puis « Paramètres de cette navigation »,
      // au-dessus de la liste.
      final yDebut = tester.getTopLeft(find.text('Début de navigation')).dy;
      final yParam = tester
          .getTopLeft(find.byKey(const Key('start-settings')))
          .dy;
      final yListe = tester
          .getTopLeft(find.byKey(const Key('alerted-table')))
          .dy;
      expect(yDebut < yParam && yParam < yListe, isTrue);
      // Décochée pour les SMS : pas de SMS de début pour elle.
      await reveal(tester, find.byKey(const Key('alert-sms-c1')));
      await tester.tap(find.byKey(const Key('alert-sms-c1')));
      await attendre(tester);
      await demarrer(tester);
      await toucher(tester, 'OK');
      expect(
        sms.preremplis.where((p) => p.$1.contains('+33612345678')),
        isEmpty,
      );
      // Écran de navigation : chronomètres réunis, météo, « Envoyer position ».
      expect(find.text('Depuis le début'), findsOneWidget);
      expect(find.text('Depuis le dernier envoi position'), findsOneWidget);
      expect(find.byKey(const Key('weather-link')), findsOneWidget);
      expect(find.text('Envoyer position'), findsOneWidget);
      for (final b in ['NOTE', 'Photo', 'Vocal']) {
        expect(
          find.ancestor(
            of: find.text(b),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
          findsOneWidget,
        );
      }
      await reveal(tester, find.byKey(const Key('footer-memo')));
      expect(find.byKey(const Key('footer-memo')), findsOneWidget);
    },
  );

  testWidgets(
    'quota épuisé : démarrage refusé, heure du retour des minutes et abonnement (RG-ECO-04)',
    (tester) async {
      serveur.quotaEpuise = true;
      await connecter(tester);
      await toucher(tester, 'Démarrer navigation');
      await toucher(tester, 'J\'ai compris');
      await demarrer(tester);
      expect(find.text('Démarrage refusé'), findsOneWidget);
      expect(
        find.textContaining('Quota de navigation gratuite épuisé'),
        findsOneWidget,
      );
      await toucher(tester, 'Quota et abonnement');
      expect(find.text('En savoir plus sur l\'abonnement'), findsOneWidget);
      // D-179 : plus de prochaines minutes récupérables sur l'écran.
      expect(find.textContaining('récupérables'), findsNothing);
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
    await demarrer(tester);
    expect(
      find.text('Vérifiez d\'abord votre adresse e-mail.'),
      findsOneWidget,
    );
  });

  Future<void> naviguer(WidgetTester tester) async {
    await connecter(tester);
    await toucher(tester, 'Démarrer navigation');
    await toucher(tester, 'J\'ai compris');
    await demarrer(tester);
    await toucher(tester, 'OK');
    serveur.elements.clear();
  }

  List<Map> evenements() => [
    for (final (op, _, c) in serveur.elements)
      if (op == 'evenement') c as Map,
  ];

  testWidgets(
    'position, NOTE, Photo, Vocal : envoi et résultat de chaque circuit (TODO-5.4, RG-COM-03)',
    (tester) async {
      await naviguer(tester);
      await toucher(tester, 'Envoyer position');
      expect(find.text('Position envoyée'), findsWidgets);
      expect(find.text('Serveur : envoyé'), findsOneWidget);
      // RG-SMS-03 : SMS ordinaire prérempli, aux suiveurs de la navigation.
      expect(
        find.text(
          'SMS : prérempli dans l\'application SMS, appuyez sur « Envoyer »',
        ),
        findsOneWidget,
      );
      expect(sms.preremplis.last.$1, ['+33612345678']);
      expect(sms.preremplis.last.$2, contains('Position 47.38000, -2.95000'));
      await toucher(tester, 'OK');

      await toucher(tester, 'NOTE');
      await tester.enterText(find.byKey(const Key('note-text')), 'Cap au 270');
      await toucher(tester, 'Valider l\'envoi');
      expect(find.text('Note envoyée'), findsOneWidget);
      await toucher(tester, 'OK');
      expect(find.text('Cap au 270'), findsOneWidget); // journal
      expect(sms.preremplis.last.$2, contains('Note : Cap au 270'));

      await toucher(tester, 'Photo');
      expect(find.text('Photo envoyée'), findsOneWidget);
      await toucher(tester, 'OK');

      await toucher(tester, 'Vocal');
      expect(find.text('Enregistrement en cours'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await toucher(tester, 'Arrêter et envoyer');
      expect(find.text('Note vocale envoyée'), findsOneWidget);
      await toucher(tester, 'OK');
      // RG-SMS-06 : « Note vocale » et lien vers la page de la navigation.
      expect(sms.preremplis.last.$2, contains('Note vocale : https://'));

      expect(evenements().map((e) => e['type']), [
        'position_manuelle',
        'note',
        'photo',
        'note_vocale',
      ]);
      expect(serveur.fichiers.length, 2);
    },
  );

  testWidgets(
    '« Incident - avarie » dans la fenêtre de NOTE : texte obligatoire, photo facultative, SMS (TODO-5.11, RG-JRN-11, D-165)',
    (tester) async {
      await naviguer(tester);
      await toucher(tester, 'NOTE');
      await toucher(tester, 'Incident - avarie');
      // RG-JRN-11 : pas d'envoi sans texte, la fenêtre reste ouverte.
      await toucher(tester, 'Valider l\'envoi');
      expect(find.byKey(const Key('note-text')), findsOneWidget);
      expect(evenements(), isEmpty);
      await tester.enterText(
        find.byKey(const Key('note-text')),
        'Voie d\'eau au presse-étoupe',
      );
      await tester.pump();
      await toucher(tester, 'Valider l\'envoi');
      expect(find.text('Incident - avarie envoyé'), findsOneWidget);
      await toucher(tester, 'OK');
      // RG-SMS-02 : SMS du type « Incidents - avaries », avec le lien de l'événement.
      expect(sms.preremplis.last.$2, contains('incident - avarie'));
      expect(
        sms.preremplis.last.$2,
        contains('Note : Voie d\'eau au presse-étoupe'),
      );
      expect(sms.preremplis.last.$2, contains('Détails : https://'));
      expect(find.text('Voie d\'eau au presse-étoupe'), findsOneWidget);

      // une seule pièce jointe : photo
      await toucher(tester, 'NOTE');
      await toucher(tester, 'Incident - avarie');
      await tester.enterText(find.byKey(const Key('note-text')), 'Safran');
      await tester.pump();
      await tester.tap(find.byKey(const Key('incident-piece-photo')));
      await tester.pump();
      await toucher(tester, 'Valider l\'envoi');
      expect(find.text('Incident - avarie envoyé'), findsOneWidget);
      await toucher(tester, 'OK');

      final evts = evenements();
      expect(evts.map((e) => e['type']), ['incident', 'incident']);
      expect(evts[0]['texte'], 'Voie d\'eau au presse-étoupe');
      expect(evts[0]['fichier'], isNull);
      expect((evts[1]['fichier'] as Map)['typeMedia'], 'image/jpeg');
      expect(serveur.fichiers.length, 1);
    },
  );

  testWidgets('Vocal : micro refusé, message', (tester) async {
    await naviguer(tester);
    medias.micro = false;
    await toucher(tester, 'Vocal');
    expect(
      find.text(
        'Accès au micro refusé : la note vocale ne peut pas être enregistrée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'SOS depuis l\'accueil : confirmation, SMS SOS prérempli, alerte au serveur (TODO-5.5, RG-SOS-15, RG-AND-04)',
    (tester) async {
      await connecter(tester);
      await toucher(tester, 'Envoyer un SOS');
      expect(find.text('Envoyer un SOS ?'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('sos-problem')),
        'Avarie moteur',
      );
      await toucher(tester, 'Confirmer le SOS');
      await attendre(tester);
      expect(find.byKey(const Key('sos-distress')), findsOneWidget);
      expect(
        find.textContaining('Position 47.38000, -2.95000'),
        findsOneWidget,
      );
      expect(
        find.text(
          'SMS SOS prérempli ouvert dans l\'application SMS : appuyez sur « Envoyer ».',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Serveur : alerte reçue, e-mails envoyés à vos amis'),
        findsOneWidget,
      );
      final (numeros, texte, _) = sms.preremplis.single;
      expect(numeros, ['+33612345678']);
      expect(texte, contains('SOS Alizé'));
      expect(texte, contains('(suite)')); // second SMS (RG-SOS-08)
      expect(texte, contains('Problème : Avarie moteur.'));
      expect(texte, contains('https://maps.google.com/?q=47.38000,-2.95000'));
      final alerte = serveur.alertesRecues.values.single as Map;
      expect(alerte['bateauId'], 'b1');
      expect(alerte['problemeRencontre'], 'Avarie moteur');
    },
  );

  testWidgets('SOS pendant la navigation, annulé puis confirmé (RG-SOS-02)', (
    tester,
  ) async {
    ouvrirLien = (_) async => true;
    addTearDown(() => ouvrirLien = (_) async => false);
    await naviguer(tester);
    await toucher(tester, 'Envoyer un SOS');
    await toucher(tester, 'Annuler');
    expect(serveur.alertesRecues, isEmpty);
    await toucher(tester, 'Envoyer un SOS');
    await toucher(tester, 'Confirmer le SOS');
    await attendre(tester);
    final alerte = serveur.alertesRecues.values.single as Map;
    expect(alerte['navigationId'], isNotNull);
    expect(alerte['personnesABord'], 1);
  });

  testWidgets(
    '« Terminer la navigation » : confirmation, résultat, page Web de la navigation (TODO-5.6, RG-NAV-13)',
    (tester) async {
      final liens = <Uri>[];
      ouvrirLien = (u) async {
        liens.add(u);
        return true;
      };
      addTearDown(() => ouvrirLien = (_) async => false);
      await naviguer(tester);
      await toucher(tester, 'Terminer la navigation');
      expect(find.text('Terminer la navigation ?'), findsOneWidget);
      await toucher(tester, 'Terminer');
      expect(find.text('Navigation terminée'), findsOneWidget);
      expect(find.text('Serveur : envoyé'), findsOneWidget);
      await toucher(tester, 'OK');
      expect(
        liens.single.path,
        endsWith('/navigations/${serveur.elements.last.$2}'),
      );
      expect(serveur.elements.last.$1, 'fin');
      expect(
        find.text('Démarrer navigation'),
        findsOneWidget,
      ); // retour à l'accueil
    },
  );

  testWidgets(
    '« Reprendre la dernière navigation » depuis l\'accueil (RG-NAV-12)',
    (tester) async {
      serveur.navigationEnCours = true;
      await connecter(tester);
      await toucher(tester, 'Reprendre la dernière navigation');
      // D-184 : navigation inconnue du téléphone : l'application demande.
      expect(
        find.text(
          'Une navigation est en cours sur Alizé. Envoyer les positions '
          'automatiques depuis ce téléphone ?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('join-yes')));
      await attendre(tester);
      expect(find.byKey(const Key('voyage-name')), findsOneWidget);
      expect(find.text('Alizé — Houat'), findsOneWidget);
      expect(find.text('Envoyer position'), findsOneWidget);
      expect(find.text('Terminer la navigation'), findsOneWidget);
      expect(serveur.elements.where((e) => e.$1 == 'rejoindre'), isEmpty);
    },
  );

  testWidgets(
    'rejoindre depuis un autre téléphone du compte : ajouts sans positions automatiques ni fin (D-177, D-184, RG-NAV-39)',
    (tester) async {
      serveur.navigationEnCours = true;
      await connecter(tester);
      await toucher(tester, 'Reprendre la dernière navigation');
      await tester.tap(find.byKey(const Key('join-no')));
      await attendre(tester);
      expect(find.text('Alizé — Houat'), findsOneWidget);
      expect(find.byKey(const Key('joined-info')), findsOneWidget);
      expect(find.text('Terminer la navigation'), findsNothing);
      expect(find.byKey(const Key('next-auto-position')), findsNothing);
      final rejoindre = serveur.elements.firstWhere((e) => e.$1 == 'rejoindre');
      expect(rejoindre.$2, 'n1');
      expect((rejoindre.$3 as Map)['appareilId'], isNotEmpty);
      // Une position manuelle part pour la navigation rejointe.
      await toucher(tester, 'Envoyer position');
      await attendre(tester);
      expect(
        serveur.elements.where(
          (e) =>
              e.$1 == 'evenement' &&
              (e.$3 as Map)['type'] == 'position_manuelle',
        ),
        isNotEmpty,
      );
      expect(
        serveur.elements.where(
          (e) =>
              e.$1 == 'evenement' &&
              (e.$3 as Map)['type'] == 'position_automatique',
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'iPhone : avertissement au démarrage, aucun SMS, SOS sans Internet (RG-IOS-02 à RG-IOS-04)',
    (tester) async {
      await connecter(tester, plateforme: 'ios');
      await toucher(tester, 'Démarrer navigation');
      await toucher(tester, 'J\'ai compris');
      await reveal(tester, find.byKey(const Key('ios-start-warning')));
      expect(find.byKey(const Key('ios-start-warning')), findsOneWidget);
      // Claire est contact SOS sans e-mail : elle ne sera pas prévenue.
      expect(
        find.text('Amis sans e-mail, qui ne seront pas prévenus : Claire'),
        findsOneWidget,
      );
      await demarrer(tester);
      expect(find.text('Envoi de SMS'), findsNothing);
      expect(find.textContaining('SMS'), findsNothing);
      await toucher(tester, 'OK');

      serveur.coupe = true;
      await toucher(tester, 'Envoyer un SOS');
      await toucher(tester, 'Confirmer le SOS');
      await attendre(tester);
      expect(
        find.textContaining('Sans Internet, l\'alerte SOS ne peut pas partir'),
        findsOneWidget,
      );
      expect(sms.preremplis, isEmpty);
      expect(sms.envoyes, isEmpty);
    },
  );

  testWidgets(
    '« Ajouter une personne » : nouveau contact coché, enregistré au démarrage avec le périmètre choisi (RG-NAV-26, RG-PAR-02)',
    (tester) async {
      await connecter(tester);
      await toucher(tester, 'Démarrer navigation');
      await toucher(tester, 'J\'ai compris');
      await reveal(tester, find.byKey(const Key('start-add-person')));
      await tester.tap(find.byKey(const Key('start-add-person')));
      await attendre(tester);
      await tester.enterText(find.byKey(const Key('add-name')), 'Paul');
      await tester.enterText(
        find.byKey(const Key('add-phone')),
        '+33622222222',
      );
      await attendre(tester);
      await toucher(tester, 'Ajouter');
      await tester.tap(find.byKey(const Key('add-scope-voyage')));
      await attendre(tester);
      expect(find.text('Paul'), findsOneWidget);
      expect(
        find.text('Nouveau contact, enregistré au démarrage'),
        findsOneWidget,
      );
      await demarrer(tester);
      await attendre(tester);
      final (_, navId, c) = serveur.elements.firstWhere(
        (e) => e.$1 == 'demarrage',
      );
      final ajout = serveur.contactsAjoutes.single;
      expect(ajout['nom'], 'Paul');
      expect(ajout['perimetre'], 'navigation');
      expect(ajout['navigationId'], navId);
      // D-176 : plus d'anciens champs « suiveur » et « contactSos ».
      expect(ajout.containsKey('suiveur'), isFalse);
      expect(ajout.containsKey('contactSos'), isFalse);
      // Q-102 : sans adresse, « E-mail » est décoché (alertes du serveur) ;
      // « SMS » est coché.
      expect((c as Map)['personnesAlertees'], isNot(contains(ajout['id'])));
      // SMS de début prérempli aussi pour la nouvelle personne.
      expect(sms.preremplis.last.$1, contains('+33622222222'));
    },
  );

  testWidgets('destination choisie sur une carte (RG-NAV-04)', (tester) async {
    SeaMap.tilesEnabled = false;
    await connecter(tester);
    await toucher(tester, 'Démarrer navigation');
    await toucher(tester, 'J\'ai compris');
    await tester.tap(find.byKey(const Key('start-destination-map')));
    await attendre(tester);
    await tester.tap(find.byKey(const Key('destination-map')));
    await attendre(tester);
    await tester.tap(find.byKey(const Key('destination-validate')));
    await attendre(tester);
    expect(find.byKey(const Key('destination-point')), findsOneWidget);
    await demarrer(tester);
    final c = serveur.elements.firstWhere((e) => e.$1 == 'demarrage').$3 as Map;
    final d = c['destination'] as Map;
    expect(d.containsKey('texte'), isFalse);
    expect((d['position'] as Map)['latitude'], isA<double>());
    expect((d['position'] as Map)['heureAcquisition'], isA<String>());
  });

  testWidgets(
    'note du journal modifiée puis supprimée depuis le téléphone (RG-JRN-06)',
    (tester) async {
      await naviguer(tester);
      await toucher(tester, 'NOTE');
      await tester.enterText(find.byKey(const Key('note-text')), 'Cap au 270');
      await toucher(tester, 'Valider l\'envoi');
      await toucher(tester, 'OK');
      await toucher(tester, 'Cap au 270');
      await toucher(tester, 'Modifier');
      await tester.enterText(find.byKey(const Key('note-text')), 'Cap au 280');
      await toucher(tester, 'Valider l\'envoi');
      expect(find.text('Cap au 280'), findsOneWidget);
      final patch = serveur.appels.lastWhere((a) => a.startsWith('PATCH'));
      expect(patch, contains('/evenements/'));
      expect(serveur.corps[patch], {'texte': 'Cap au 280'});
      await toucher(tester, 'Cap au 280');
      await toucher(tester, 'Supprimer');
      await tester.tap(find.text('Supprimer').last);
      await attendre(tester);
      expect(find.text('Cap au 280'), findsNothing);
      expect(serveur.appels.last, startsWith('DELETE'));
    },
  );

  testWidgets(
    'autorisation SMS accordée : SMS de début et de position envoyés automatiquement (D-158)',
    (tester) async {
      sms.autorisee = true;
      await naviguer(tester);
      // SMS de début parti tout seul, sans application SMS.
      expect(sms.preremplis, isEmpty);
      expect(sms.envoyes.single.$3, contains('début de navigation'));
      await toucher(tester, 'Envoyer position');
      expect(
        find.text('SMS : envoyé automatiquement à 1 destinataire'),
        findsOneWidget,
      );
      expect(sms.envoyes.length, 2);
      expect(sms.preremplis, isEmpty);
    },
  );
}
