import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/depot/depot.dart';
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
  late DateTime heure;

  setUp(() async {
    heure = DateTime(2026, 11, 25, 10);
    SharedPreferences.setMockInitialValues({});
    session = await StockageSession.ouvrir();
    base = BaseMemoire();
    serveur = FauxServeurNautiLink()..navigationEnCours = false;
    gps = FauxGps(positionEssai());
  });

  Future<DepotReel> connecte() async {
    final d = serveur.depot(
      session,
      base,
      positions: gps,
      horloge: () => heure,
    );
    await d.ouvrir();
    await d.connexion('marin@example.org', 'secret123');
    return d;
  }

  /// Éléments `evenement` reçus par le serveur, dans l'ordre.
  List<Map> evenements() => [
    for (final (op, _, c) in serveur.elements)
      if (op == 'evenement') c as Map,
  ];

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

    test('démarrage hors connexion refusé à sa réception : message gardé sur l\'écran de navigation (Q-90)', () async {
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

  group('positions automatiques (TODO-5.3)', () {
    test('position enregistrée à la fréquence de la navigation et envoyée au serveur (RG-GPS-02, RG-GPS-03)', () async {
      final d = await connecte();
      await demarrer(d);
      expect(gps.frequenceSuivie, const Duration(minutes: 60)); // suivi lancé
      final c = d.conduite;

      heure = heure.add(const Duration(minutes: 30));
      await c.verifierPositionAutomatique();
      expect(evenements(), isEmpty); // pas encore due

      heure = heure.add(const Duration(minutes: 29)); // tolérance d'une minute
      gps.position = positionEssai(heure);
      await c.verifierPositionAutomatique();
      await d.file.attendrePasse();
      final e = evenements().single;
      expect(e['type'], 'position_automatique');
      expect(e['numeroOrdre'], 2);
      expect(e['gpsDisponible'], isTrue);
      expect(e['origine'], 'android');
      expect((e['position'] as Map)['heureAcquisition'], heureRfc3339(heure));
      expect(c.enCours!.journal.last.type, 'position_automatique');
      expect(c.prochaineAutomatique, heure.add(const Duration(hours: 1)));
    });

    test(
      'position remise par le suivi du téléphone : pas de nouvelle acquisition',
      () async {
        final d = await connecte();
        await demarrer(d);
        final avant = gps.acquisitions;
        heure = heure.add(const Duration(hours: 1));
        gps.suivi.add(positionEssai(heure));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await d.file.attendrePasse();
        expect(evenements().single['type'], 'position_automatique');
        expect(gps.acquisitions, avant);
      },
    );

    test(
      'GPS sans réponse : position automatique « GPS non disponible » (Q-89)',
      () async {
        final d = await connecte();
        await demarrer(d);
        gps.position = null;
        heure = heure.add(const Duration(hours: 1));
        await d.conduite.verifierPositionAutomatique();
        await d.file.attendrePasse();
        final e = evenements().single;
        expect(e['gpsDisponible'], isFalse);
        expect(e.containsKey('position'), isFalse);
      },
    );

    test('hors connexion : positions gardées sur le téléphone, envoyées au retour dans l\'ordre d\'acquisition (RG-GPS-04)', () async {
      final d = await connecte();
      await demarrer(d);
      serveur.coupe = true;
      for (var i = 1; i <= 3; i++) {
        heure = heure.add(const Duration(hours: 1));
        gps.position = positionEssai(heure);
        await d.conduite.verifierPositionAutomatique();
      }
      expect(await d.envois.enAttente(), 3);
      expect(d.conduite.enCours!.journal.length, 4);

      // Fermeture forcée puis réouverture : rien n'est perdu (RG-NAV-12).
      final d2 = serveur.depot(
        session,
        base,
        positions: gps,
        horloge: () => heure,
      );
      gps.frequenceSuivie = null;
      await d2.ouvrir();
      expect(gps.frequenceSuivie, const Duration(minutes: 60)); // suivi repris
      expect(
        d2.conduite.prochaineAutomatique,
        heure.add(const Duration(hours: 1)),
      );

      serveur.coupe = false;
      await d2.file.relancer();
      expect(evenements().map((e) => e['numeroOrdre']), [2, 3, 4]);
      expect(await d2.envois.enAttente(), 0);
    });

    test('clôture automatique : envois refusés, positions automatiques arrêtées, navigateur prévenu (RG-ECO-12)', () async {
      final d = await connecte();
      await demarrer(d);
      serveur.refusEvenements = (
        409,
        'navigation_cloturee',
        'Navigation clôturée : quota épuisé depuis 24 heures.',
      );
      heure = heure.add(const Duration(hours: 1));
      await d.conduite.verifierPositionAutomatique();
      await d.file.attendrePasse();
      await d.actualiser();
      expect(
        d.conduite.enCours?.refus,
        'Navigation clôturée : quota épuisé depuis 24 heures.',
      );
      expect(d.conduite.suiviActif, isFalse);
      heure = heure.add(const Duration(hours: 1));
      await d.conduite.verifierPositionAutomatique();
      expect(d.conduite.enCours!.journal.length, 2);
    });
  });

  group('position manuelle, NOTE, Photo, Vocal (TODO-5.4)', () {
    late FauxMedias medias;

    Future<DepotReel> enNavigation() async {
      medias = FauxMedias();
      final d = serveur.depot(
        session,
        base,
        positions: gps,
        horloge: () => heure,
        medias: medias,
      );
      await d.ouvrir();
      await d.connexion('marin@example.org', 'secret123');
      await demarrer(d);
      serveur.elements.clear();
      return d;
    }

    test('position manuelle : autorisation redemandée, envoyée au serveur (RG-NAV-11, RG-AND-03)', () async {
      final d = await enNavigation();
      final demandes = gps.demandes;
      final etat = await d.conduite.positionManuelle();
      expect(etat.recu, isTrue);
      expect(gps.demandes, demandes + 1);
      final e = evenements().single;
      expect(e['type'], 'position_manuelle');
      expect(e['gpsDisponible'], isTrue);
      expect((e['position'] as Map)['longitude'], -2.95);
    });

    test(
      'NOTE : texte envoyé au journal ; hors connexion, en attente',
      () async {
        final d = await enNavigation();
        expect((await d.conduite.note('  Mouillage à Houat ')).recu, isTrue);
        expect(evenements().single['texte'], 'Mouillage à Houat');
        serveur.coupe = true;
        final etat = await d.conduite.note('Grain');
        expect(etat.recu, isFalse);
        expect(etat.refuse, isFalse);
        expect(d.conduite.enCours!.journal.last.texte, 'Grain');
      },
    );

    test('Photo : événement puis fichier JPEG, copie locale effacée après dépôt (RG-COM-05)', () async {
      final d = await enNavigation();
      final id = d.file.nouvelId();
      final f = await medias.photo(id);
      final etat = await d.conduite.photo(id, f!.chemin, f.tailleOctets);
      expect(etat.recu, isTrue);
      await d.file.attendrePasse();
      final e = evenements().single;
      expect(e['id'], id);
      expect(e['type'], 'photo');
      expect(e['fichier'], {'typeMedia': 'image/jpeg', 'tailleOctets': 950000});
      expect(serveur.fichiers[id], ('image/jpeg', 1000));
      // Le fichier part après son événement.
      final i = serveur.appels.indexOf('PUT /v1/fichiers/$id');
      expect(
        i,
        greaterThan(serveur.appels.lastIndexOf('POST /v1/synchronisation')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(medias.oublies, [id]);
    });

    test(
      'Photo refusée au-delà de 20 (RG-JRN-08) : message du serveur',
      () async {
        final d = await enNavigation();
        serveur.refusEvenements = (
          409,
          'limite_photos',
          'Une navigation compte au plus 20 photos.',
        );
        final id = d.file.nouvelId();
        final etat = await d.conduite.photo(id, '/essai/$id.jpg', 900000);
        expect(etat.refuse, isTrue);
        expect(etat.refus!.message, 'Une navigation compte au plus 20 photos.');
      },
    );

    test(
      'Vocal : note vocale AAC, durée, fichier audio/mp4 (RG-JRN-04)',
      () async {
        final d = await enNavigation();
        final id = d.file.nouvelId();
        final etat = await d.conduite.noteVocale(
          id,
          '/essai/$id.m4a',
          120000,
          75,
        );
        expect(etat.recu, isTrue);
        await d.file.attendrePasse();
        final e = evenements().single;
        expect(e['type'], 'note_vocale');
        expect((e['fichier'] as Map)['typeMedia'], 'audio/mp4');
        expect((e['fichier'] as Map)['dureeSecondes'], 60); // 1 minute au plus
        expect(serveur.fichiers[id]?.$1, 'audio/mp4');
      },
    );
  });

  group('alerte SOS (TODO-5.5)', () {
    test('SOS pendant la navigation : rattaché à elle, position actuelle, personnes à bord, problème (RG-SOS-04, RG-SOS-09)', () async {
      final d = await connecte();
      final n = await demarrer(d);
      final (p, nature) = await d.conduite.positionSos();
      expect(nature, NaturePosition.actuelle);
      final a = await d.conduite.envoyerSos(
        position: p,
        nature: nature,
        probleme: ' Voie d\'eau ',
      );
      expect(a.etat.recu, isTrue);
      final c = serveur.alertes[a.id] as Map;
      expect(c['navigationId'], n.id);
      expect(c['bateauId'], 'b1');
      expect(c['naturePosition'], 'actuelle');
      expect(c['personnesABord'], 3);
      expect(c['problemeRencontre'], 'Voie d\'eau');
      expect((c['position'] as Map)['latitude'], 47.38);
      expect(d.conduite.enCours!.journal.last.type, 'sos');
    });

    test('GPS indisponible : dernière position connue (RG-SOS-10), sinon aucune (RG-SOS-11)', () async {
      final d = await connecte();
      await demarrer(d); // début avec une position
      gps.position = null;
      final (p, nature) = await d.conduite.positionSos();
      expect(nature, NaturePosition.derniereConnue);
      expect(p?.latitude, 47.38);

      final g2 = FauxGps();
      final d3 = serveur.depot(session, BaseMemoire(), positions: g2);
      await d3.ouvrir();
      expect((await d3.conduite.positionSos()).$2, NaturePosition.aucune);
    });

    test('SOS depuis l\'accueil, hors connexion : alerte gardée puis partie avant tout le reste (RG-SOS-15, RG-COM-05)', () async {
      final d = await connecte();
      serveur.coupe = true;
      final a = await d.conduite.envoyerSos(
        position: null,
        nature: NaturePosition.aucune,
        bateauId: 'b1',
        personnesABord: 2,
      );
      expect(a.etat.recu, isFalse);
      expect(await d.envois.enAttente(), 1);
      serveur.coupe = false;
      await d.file.relancer();
      final c = serveur.alertes[a.id] as Map;
      expect(c.containsKey('navigationId'), isFalse);
      expect(c['bateauId'], 'b1');
      expect(c['naturePosition'], 'aucune');
      expect(await d.envois.enAttente(), 0);
    });

    test('quota épuisé : le SOS part quand même (RG-SOS-03)', () async {
      serveur.quotaEpuise = true;
      final d = await connecte();
      final a = await d.conduite.envoyerSos(
        position: positionEssai(),
        nature: NaturePosition.actuelle,
        bateauId: 'b1',
      );
      expect(a.etat.recu, isTrue);
    });
  });

  group('fin et reprise (TODO-5.6)', () {
    test('fin : heure réelle envoyée, navigation close sur le téléphone, positions arrêtées (RG-NAV-13)', () async {
      final d = await connecte();
      final n = await demarrer(d);
      heure = heure.add(const Duration(hours: 3));
      final r = await d.terminer();
      expect(r?.$1, n.id);
      expect(r?.$2.recu, isTrue);
      final (op, id, c) = serveur.elements.last;
      expect((op, id), ('fin', n.id));
      expect((c as Map)['type'], 'fin');
      expect(c['heureAcquisition'], heureRfc3339(heure));
      expect(c['numeroOrdre'], 2);
      expect(d.conduite.enCours, isNull);
      expect(d.conduite.suiviActif, isFalse);
      await d.actualiser();
      expect(d.navigationEnCours, isNull);
    });

    test('fin hors connexion : gardée avec son heure réelle, transmise plus tard (RG-NAV-14)', () async {
      final d = await connecte();
      final n = await demarrer(d);
      serveur.coupe = true;
      heure = heure.add(const Duration(hours: 2));
      final fin = heureRfc3339(heure);
      final r = await d.terminer();
      expect(r?.$2.recu, isFalse);
      expect(d.navigationEnCours, isNull);
      heure = heure.add(const Duration(hours: 5));
      serveur.coupe = false;
      await d.file.relancer();
      final (op, id, c) = serveur.elements.last;
      expect((op, id), ('fin', n.id));
      expect((c as Map)['heureAcquisition'], fin);
    });

    test('reprise d\'une navigation en cours inconnue du téléphone, relue sur le serveur (RG-NAV-12, Q-90)', () async {
      serveur.navigationEnCours = true;
      final d = await connecte();
      expect(d.conduite.enCours, isNull);
      expect(d.navigationEnCours?.id, 'n1');
      final n = await d.reprendre();
      expect(n?.id, 'n1');
      expect(n?.frequenceMinutes, 60);
      expect(n?.personnesABord, 3);
      expect(serveur.appels, contains('GET /v1/navigations/n1'));
      expect(gps.frequenceSuivie, const Duration(minutes: 60));
      // La fin part pour cette navigation.
      await d.terminer();
      expect(serveur.elements.last.$1, 'fin');
      expect(serveur.navigationEnCours, isFalse);
    });

    test('navigation terminée sur un autre support : elle n\'est plus en cours sur le téléphone (Q-90)', () async {
      final d = await connecte();
      final n = await demarrer(d);
      serveur.demarrees[n.id]!['etat'] = 'terminee';
      await d.actualiser();
      expect(d.conduite.enCours, isNull);
      expect(d.conduite.suiviActif, isFalse);
    });
  });
}
