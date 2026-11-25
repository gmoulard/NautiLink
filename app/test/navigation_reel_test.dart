import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/conduite.dart';
import 'package:nautilink/reel/depot_reel.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';

/// Vraie application, navigation (TODO-5.2 à TODO-5.6), contre le faux serveur.
void main() {
  late FauxServeurNautiLink serveur;
  late BaseLocale base;
  late StockageSession session;
  late FauxGps gps;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = await StockageSession.ouvrir();
    base = BaseMemoire();
    serveur = FauxServeurNautiLink()..navigationEnCours = false;
    gps = FauxGps(positionEssai());
  });

  Future<DepotReel> connecte() async {
    final d = serveur.depot(session, base, positions: gps);
    await d.ouvrir();
    await d.connexion('marin@example.org', 'secret123');
    return d;
  }

  Future<NavigationLocale> demarrer(DepotReel d, {String? destination}) async =>
      d.demarrer(
        bateau: (await d.bateauxDuTelephone()).first,
        frequenceMinutes: 60,
        personnesABord: 3,
        personnesAlertees: ['c1'],
        destination: destination,
        parametres: d.parametres,
      );

  group('démarrage (TODO-5.2)', () {
    test('démarrage envoyé au serveur avec bateau, destination, fréquence, personnes et position (RG-NAV-08)', () async {
      final d = await connecte();
      expect(d.navigationEnCours, isNull);
      // Le téléphone n'est associé qu'à Alizé : pas de choix (RG-NAV-02).
      expect((await d.bateauxDuTelephone()).map((b) => b.id), ['b1']);

      final n = await demarrer(d, destination: ' Houat ');
      final (op, id, c) = serveur.elements.single;
      expect((op, id), ('demarrage', n.id));
      final contenu = c as Map;
      expect(contenu['bateauId'], 'b1');
      expect(contenu['appareilId'], await session.appareilId());
      expect(contenu['destination'], {'texte': 'Houat'});
      expect(contenu['frequenceMinutes'], 60);
      expect(contenu['personnesABord'], 3);
      expect(contenu['personnesAlertees'], ['c1']);
      expect((contenu['parametres'] as Map)['frequenceParDefaut'], 60);
      final debut = contenu['debut'] as Map;
      expect(debut['type'], 'debut');
      expect(debut['numeroOrdre'], 1);
      expect(debut['gpsDisponible'], isTrue);
      expect(debut['origine'], 'android');
      expect((debut['position'] as Map)['latitude'], 47.38);
      expect(gps.demandes, 1); // autorisation demandée à l'écran (RG-AND-02)

      expect(n.dernierEnvoi, isNotNull); // chronomètre remis à zéro (RG-NAV-10)
      expect(d.navigationEnCours?.id, n.id);
      await Future<void>.delayed(Duration.zero);
      await d.actualiser();
      expect(d.navigationEnCours?.nom, 'Alizé — Houat'); // nom du serveur
      expect(session.dernierNombrePersonnes, 3); // RG-NAV-27
    });

    test('quota épuisé d\'après le dernier état reçu : refus sans envoi (RG-ECO-04, RG-NAV-07)', () async {
      serveur.quotaEpuise = true;
      final d = await connecte();
      await expectLater(
        demarrer(d),
        throwsA(
          isA<RefusDemarrage>()
              .having((r) => r.quotaEpuise, 'quota', isTrue)
              .having((r) => r.disponibleLe, 'disponibleLe', isNotNull),
        ),
      );
      expect(serveur.elements, isEmpty);
      expect(d.navigationEnCours, isNull);
    });

    test('refus du serveur (adresse non confirmée) : message du serveur, rien ne démarre', () async {
      final d = await connecte();
      serveur.refusDemarrage = (
        403,
        'email_non_verifie',
        'Vérifiez d\'abord votre adresse e-mail.',
      );
      await expectLater(
        demarrer(d),
        throwsA(
          isA<RefusDemarrage>().having(
            (r) => r.erreur?.message,
            'message',
            'Vérifiez d\'abord votre adresse e-mail.',
          ),
        ),
      );
      expect(d.navigationEnCours, isNull);
      expect(await base.elementsMisDeCote(), isEmpty); // refus lu, retiré
    });

    test('refus du serveur (quota épuisé) : heure du retour des minutes (RG-ECO-04)', () async {
      final d = await connecte();
      serveur.refusDemarrage = (403, 'quota_epuise', 'Quota épuisé.');
      await expectLater(
        demarrer(d),
        throwsA(
          isA<RefusDemarrage>()
              .having((r) => r.quotaEpuise, 'quota', isTrue)
              .having((r) => r.disponibleLe?.toUtc().hour, 'heure', 12),
        ),
      );
    });

    test('hors connexion : la navigation démarre sur le téléphone, le démarrage part au retour (RG-COM-06)', () async {
      final d = await connecte();
      serveur.coupe = true;
      final n = await demarrer(d);
      expect(d.navigationEnCours?.id, n.id);
      expect(n.dernierEnvoi, isNull);
      expect(await d.envois.enAttente(), 1);

      // Fermeture forcée : la navigation reste en cours (RG-NAV-12).
      final d2 = serveur.depot(session, base, positions: gps);
      await d2.ouvrir();
      expect(d2.navigationEnCours?.id, n.id);
      expect(d2.conduite.enCours?.personnesABord, 3);

      serveur.coupe = false;
      await d2.file.relancer();
      expect(serveur.elements.single.$1, 'demarrage');
      expect(await d2.envois.enAttente(), 0);
      expect(d2.conduite.enCours?.dernierEnvoi, isNotNull);
    });

    test('démarrage hors connexion refusé à sa réception : message gardé sur l\'écran de navigation (Q-87)', () async {
      final d = await connecte();
      serveur.coupe = true;
      final n = await demarrer(d);
      serveur
        ..coupe = false
        ..refusDemarrage = (
          403,
          'email_non_verifie',
          'Vérifiez d\'abord votre adresse e-mail.',
        );
      await d.file.relancer();
      await d.actualiser();
      expect(d.conduite.enCours?.id, n.id);
      expect(
        d.conduite.enCours?.refus,
        'Vérifiez d\'abord votre adresse e-mail.',
      );
    });

    test('GPS indisponible : démarrage sans position (RG-AND-03)', () async {
      gps.position = null;
      final d = await connecte();
      await demarrer(d);
      final debut = (serveur.elements.single.$3 as Map)['debut'] as Map;
      expect(debut['gpsDisponible'], isFalse);
      expect(debut.containsKey('position'), isFalse);
    });

    test('bateau associé à un autre téléphone : il passe à celui-ci au démarrage (Q-81)', () async {
      final d = await connecte();
      final b2 = d.bateaux.firstWhere((b) => b.id == 'b2');
      await d.demarrer(
        bateau: b2,
        frequenceMinutes: 30,
        personnesABord: 1,
        personnesAlertees: const [],
      );
      expect(serveur.appels, contains('PUT /v1/bateaux/b2/telephone'));
      expect((serveur.elements.single.$3 as Map)['bateauId'], 'b2');
    });
  });
}
