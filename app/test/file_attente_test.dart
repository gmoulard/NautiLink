import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nautilink/depot/depot.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/file_attente.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const base = 'https://essai.example/api';
final uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

http.Response json(int statut, Object? corps) => http.Response.bytes(
  corps == null ? const [] : utf8.encode(jsonEncode(corps)),
  statut,
);

/// Faux serveur : note chaque appel et répond selon [repondre].
class FauxServeur {
  FauxServeur(this.repondre);
  http.Response Function(http.Request r, Object? corps) repondre;
  final appels = <String>[];
  final corps = <Object?>[];
  bool coupe = false;
  Future<void> Function()? avant;

  MockClient get client => MockClient((r) async {
    if (coupe) throw http.ClientException('pas de réseau');
    await avant?.call();
    appels.add('${r.method} ${r.url.path.replaceFirst('/api', '')}');
    final c = r.headers['Content-Type']?.startsWith('application/json') == true
        ? jsonDecode(r.body)
        : r.bodyBytes;
    corps.add(c);
    return repondre(r, c);
  });
}

/// Réponse de `POST /v1/synchronisation` : un statut par élément.
http.Response lot(Object? c, int Function(Map e) statut) {
  final el = (c as Map)['elements'] as List;
  return json(200, {
    'resultats': [
      for (final e in el)
        {
          'id': e['id'],
          'statut': statut(e as Map),
          if (statut(e) >= 400)
            'erreur': {'code': 'invalide', 'message': 'Refusé.'},
        },
    ],
  });
}

FileAttente garder(List<FileAttente> l, FileAttente f) => f..let(l.add);

extension<T> on T {
  void let(void Function(T) f) => f(this);
}

void main() {
  late BaseLocale baseLocale;
  late StockageSession session;
  final planifies = <Duration>[];
  final actions = <void Function()>[];
  final files = <FileAttente>[];

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = await StockageSession.ouvrir();
    await session.enregistrer({'jetonAcces': 'A', 'jetonRenouvellement': 'R'});
    baseLocale = await BaseSqlite.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: inMemoryDatabasePath,
    );
    planifies.clear();
    actions.clear();
    files.clear();
  });

  tearDown(() async {
    for (final f in files) {
      await f.attendrePasse();
    }
    await baseLocale.fermer();
  });

  FileAttente creer(
    FauxServeur s, {
    int tailleLot = 200,
    Map<String, List<int>>? fichiers,
  }) => garder(
    files,
    FileAttente(
      base: baseLocale,
      api: ClientApi(base: base, session: session, client: s.client),
      appareilId: session.appareilId,
      tailleLot: tailleLot,
      lireFichier: (c) async => fichiers?[c] ?? (throw StateError('absent')),
      planifier: (d, a) {
        planifies.add(d);
        actions.add(a);
      },
    ),
  );

  test('enregistrer d\'abord : l\'élément est dans la base avant l\'appel, et y reste sans réseau', () async {
    int? dansLaBase;
    final s = FauxServeur((r, c) => json(500, null));
    s.coupe = true;
    final f = creer(s);
    final e = await f.evenement('nav-1', {
      'type': 'note',
      'texte': 'Tout va bien',
      'heureAcquisition': '2026-11-25T10:00:00+01:00',
    });
    expect(e['id'], matches(uuidV4));
    expect(e['numeroOrdre'], 1);
    await f.envoyer();
    expect(await f.enAttente(), 1);
    expect(planifies, [const Duration(seconds: 30)]);

    // Retour de la connexion : l'élément part, la base le contenait avant l'appel.
    s.coupe = false;
    s.avant = () async => dansLaBase = await baseLocale.compter();
    s.repondre = (r, c) => lot(c, (_) => 201);
    final recus = <EnvoiReussi>[];
    f.reussis.listen(recus.add);
    await f.relancer();
    expect(dansLaBase, 1);
    expect(await f.enAttente(), 0);
    await Future<void>.delayed(Duration.zero);
    expect(recus.single.id, e['id']);
  });

  test('UUID v4 tirés par le téléphone, numéros d\'ordre croissants par navigation', () async {
    final s = FauxServeur((r, c) => json(503, null));
    final f = creer(s);
    final d = await f.demarrage('nav-1', {
      'bateauId': 'b',
      'debut': {
        'type': 'debut',
        'heureAcquisition': '2026-11-25T10:00:00+01:00',
      },
    });
    final a = await f.evenement('nav-1', {'type': 'position_automatique'});
    final b = await f.evenement('nav-2', {'type': 'note'});
    final c = await f.evenement('nav-1', {'type': 'note'});
    final fin = await f.fin('nav-1', {
      'heureAcquisition': '2026-11-25T12:00:00+01:00',
    });
    expect((d['debut'] as Map)['numeroOrdre'], 1);
    expect([a['numeroOrdre'], c['numeroOrdre'], fin['numeroOrdre']], [2, 3, 4]);
    expect(b['numeroOrdre'], 1);
    expect(
      {(d['debut'] as Map)['id'], a['id'], b['id'], c['id'], fin['id']}.length,
      5,
    );
    expect(fin['type'], 'fin');
    for (final id in [a['id'], b['id'], fin['id']]) {
      expect(id, matches(uuidV4));
    }
  });

  test('SOS avant tout le reste, puis éléments légers en lot, enfin fichiers après leur événement', () async {
    final s = FauxServeur((r, c) => json(500, null));
    s.coupe = true;
    final f = creer(
      s,
      fichiers: {
        '/photo.jpg': [1, 2, 3],
      },
    );
    await f.demarrage('nav-1', {
      'bateauId': 'b',
      'debut': {'type': 'debut'},
    });
    final photo = await f.evenement('nav-1', {'type': 'photo'});
    await f.fichier(photo['id'] as String, '/photo.jpg', 'image/jpeg');
    await f.alerteSos('al-1', {
      'bateauId': 'b',
      'navigationId': 'nav-1',
      'heureDeclenchement': '2026-11-25T11:00:00+01:00',
    });
    expect(await f.enAttente(), 4);

    s.coupe = false;
    s.repondre = (r, c) {
      if (r.url.path.endsWith('/synchronisation')) return lot(c, (_) => 201);
      if (r.url.path.contains('/alertes-sos/')) return json(201, c);
      return json(204, null);
    };
    final b = await f.envoyer();
    expect(s.appels, [
      'PUT /v1/alertes-sos/al-1',
      'POST /v1/synchronisation',
      'PUT /v1/fichiers/${photo['id']}',
    ]);
    final elements = (s.corps[1] as Map)['elements'] as List;
    expect(elements.map((e) => e['operation']), ['demarrage', 'evenement']);
    expect((s.corps[1] as Map)['appareilId'], await session.appareilId());
    expect(s.corps[2], [1, 2, 3]);
    expect(b.envoyes, 4);
    expect(await f.enAttente(), 0);
  });

  test(
    'fichier gardé tant que son événement n\'est pas reçu par le serveur',
    () async {
      final s = FauxServeur((r, c) => lot(c, (_) => 503));
      final f = creer(
        s,
        fichiers: {
          '/voix.m4a': [9],
        },
      );
      final ev = await f.evenement('nav-1', {'type': 'note_vocale'});
      await f.fichier(ev['id'] as String, '/voix.m4a', 'audio/mp4');
      await f.envoyer();
      expect(s.appels.where((a) => a.contains('/fichiers/')), isEmpty);
      expect(await f.enAttente(), 2);
    },
  );

  test(
    'sortie de la file sur 200 ou 201 seulement ; 4xx mis de côté ; 5xx gardé',
    () async {
      final s = FauxServeur((r, c) => json(500, null));
      s.coupe = true;
      final f = creer(s);
      final ok200 = await f.evenement('nav-a', {
        'type': 'note',
        'texte': '200',
      });
      final ok201 = await f.evenement('nav-b', {
        'type': 'note',
        'texte': '201',
      });
      final refus = await f.evenement('nav-c', {
        'type': 'note',
        'texte': '409',
      });
      final panne = await f.evenement('nav-d', {
        'type': 'note',
        'texte': '500',
      });
      final apres = await f.evenement('nav-d', {
        'type': 'note',
        'texte': '404 après une panne',
      });
      s.coupe = false;
      s.repondre = (r, c) => lot(
        c,
        (e) => switch ((e['contenu'] as Map)['texte']) {
          '200' => 200,
          '201' => 201,
          '409' => 409,
          '500' => 500,
          _ => 404,
        },
      );
      final b = await f.envoyer();
      expect(b.envoyes, 2);
      expect(b.misDeCote, 1);
      expect(b.joignable, isFalse);
      final restants = (await baseLocale.elementsAEnvoyer())
          .map((e) => e.id)
          .toList();
      expect(restants, [
        panne['id'],
        apres['id'],
      ]); // le 404 suit une panne de sa navigation : gardé
      final deCote = await baseLocale.elementsMisDeCote();
      expect(deCote.single.id, refus['id']);
      expect(deCote.single.dernierStatut, 409);
      expect(restants, isNot(contains(ok200['id'])));
      expect(restants, isNot(contains(ok201['id'])));

      // Un élément mis de côté n'est plus jamais renvoyé.
      s.appels.clear();
      s.repondre = (r, c) => lot(c, (_) => 201);
      await f.relancer();
      final renvoyes = (s.corps.last as Map)['elements'] as List;
      expect(renvoyes.map((e) => e['id']), [panne['id'], apres['id']]);
      expect(await f.enAttente(), 0);
    },
  );

  test('SOS jamais mis de côté pour une session perdue (401)', () async {
    final s = FauxServeur(
      (r, c) => json(401, {
        'code': 'non_authentifie',
        'message': 'Reconnectez-vous.',
      }),
    );
    final f = creer(s);
    await f.alerteSos('al-2', {
      'bateauId': 'b',
      'heureDeclenchement': '2026-11-25T11:00:00+01:00',
    });
    expect(await f.enAttente(), 1);
    expect(await baseLocale.elementsMisDeCote(), isEmpty);
  });

  test('lots de 200 éléments au plus (POST /v1/synchronisation)', () async {
    final s = FauxServeur((r, c) => json(500, null));
    s.coupe = true;
    final f = creer(s);
    for (var i = 0; i < 450; i++) {
      await f.evenement('nav-1', {'type': 'position_automatique'});
    }
    s.coupe = false;
    s.repondre = (r, c) => lot(c, (_) => 201);
    await f.envoyer();
    expect(s.appels, List.filled(3, 'POST /v1/synchronisation'));
    expect(s.corps.map((c) => ((c as Map)['elements'] as List).length), [
      200,
      200,
      50,
    ]);
    final ordres = [
      for (final c in s.corps)
        for (final e in (c as Map)['elements'] as List)
          (e['contenu'] as Map)['numeroOrdre'],
    ];
    expect(ordres, List.generate(450, (i) => i + 1));
  });

  test('renvoi avec délais croissants : 30 s, 1, 2, 5 puis 15 minutes ; remis à zéro après un succès', () async {
    final s = FauxServeur((r, c) => json(500, null));
    s.coupe = true;
    final f = creer(s);
    await f.evenement('nav-1', {'type': 'note'});
    await f.attendrePasse();
    for (var i = 0; i < 5; i++) {
      actions.removeLast()();
      await f.attendrePasse();
    }
    expect(planifies, const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(minutes: 15),
    ]);
    s.coupe = false;
    s.repondre = (r, c) => lot(c, (_) => 201);
    await f.relancer();
    expect(f.prochainEssai, isNull);
    expect(FileAttente.delaiApres(1), const Duration(seconds: 30));
    expect(FileAttente.delaiApres(99), const Duration(minutes: 15));
  });

  test('la base SQLite garde la file et les copies après fermeture (base de fichier)', () async {
    final chemin =
        '${await databaseFactoryFfi.getDatabasesPath()}/essai-file-${DateTime.now().microsecondsSinceEpoch}.db';
    var b = await BaseSqlite.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: chemin,
    );
    await b.ajouterElement(
      const ElementFile(
        operation: 'evenement',
        id: 'e1',
        navigationId: 'n',
        contenu: {'a': 1},
        priorite: Priorite.leger,
      ),
    );
    await b.ajouterElement(
      const ElementFile(
        operation: 'evenement',
        id: 'e1',
        navigationId: 'n',
        contenu: {'a': 2},
        priorite: Priorite.leger,
      ),
    );
    await b.ecrireCopie('quota', {
      'consommeMinutes': 5,
    }, DateTime.utc(2026, 11, 25, 9));
    expect(await b.numeroOrdreSuivant('n'), 1);
    await b.fermer();
    b = await BaseSqlite.ouvrir(fabrique: databaseFactoryFfi, chemin: chemin);
    final l = await b.elementsAEnvoyer();
    expect(l.single.contenu, {'a': 1}); // même clé : pas de doublon
    expect((await b.lireCopie('quota'))!.valeur, {'consommeMinutes': 5});
    expect(await b.numeroOrdreSuivant('n'), 2);
    await b.fermer();
    await databaseFactoryFfi.deleteDatabase(chemin);
  });
}
