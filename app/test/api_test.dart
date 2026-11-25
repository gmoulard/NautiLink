import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const base = 'https://essai.example/nautilink/api';

http.Response json(int statut, Object? corps) => http.Response.bytes(
  corps == null ? const [] : utf8.encode(jsonEncode(corps)),
  statut,
  headers: {'content-type': 'application/json'},
);

Future<StockageSession> sessionOuverte() async {
  SharedPreferences.setMockInitialValues({});
  final s = await StockageSession.ouvrir();
  await s.enregistrer({'jetonAcces': 'A1', 'jetonRenouvellement': 'R1'});
  return s;
}

void main() {
  test(
    'jeton d\'accès présenté en Authorization: Bearer (RG-CPT-12)',
    () async {
      final s = await sessionOuverte();
      late http.Request vue;
      final api = ClientApi(
        base: '$base/',
        session: s,
        client: MockClient((r) async {
          vue = r;
          return json(200, {'consommeMinutes': 10});
        }),
      );
      final q = await api.appelObjet('GET', '/v1/quota');
      expect(q['consommeMinutes'], 10);
      expect(vue.url.toString(), '$base/v1/quota');
      expect(vue.headers['Authorization'], 'Bearer A1');
    },
  );

  test(
    'sur 401 : renouvellement une fois, nouveaux jetons gardés, appel refait',
    () async {
      final s = await sessionOuverte();
      final appels = <String>[];
      final api = ClientApi(
        base: base,
        session: s,
        client: MockClient((r) async {
          appels.add(
            '${r.method} ${r.url.path} ${r.headers['Authorization'] ?? '-'}',
          );
          if (r.url.path.endsWith('/sessions/renouvellement')) {
            expect(jsonDecode(r.body), {'jetonRenouvellement': 'R1'});
            return json(200, {
              'jetonAcces': 'A2',
              'jetonRenouvellement': 'R2',
              'expireLe': '2027-02-23T10:00:00Z',
            });
          }
          return r.headers['Authorization'] == 'Bearer A2'
              ? json(200, [])
              : json(401, {
                  'code': 'non_authentifie',
                  'message': 'Session expirée.',
                });
        }),
      );
      expect(await api.appel('GET', '/v1/bateaux'), isEmpty);
      expect(appels, [
        'GET /nautilink/api/v1/bateaux Bearer A1',
        'POST /nautilink/api/v1/sessions/renouvellement -',
        'GET /nautilink/api/v1/bateaux Bearer A2',
      ]);
      expect(s.jetonAcces, 'A2');
      expect(s.jetonRenouvellement, 'R2');
    },
  );

  test('renouvellement refusé : jetons oubliés, session perdue, identifiant du téléphone gardé', () async {
    final s = await sessionOuverte();
    final id = await s.appareilId();
    var perdue = 0;
    var renouvellements = 0;
    final api = ClientApi(
      base: base,
      session: s,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/renouvellement')) renouvellements++;
        return json(401, {
          'code': 'non_authentifie',
          'message': 'Reconnectez-vous.',
        });
      }),
    )..surSessionPerdue = () => perdue++;
    await expectLater(
      api.appel('GET', '/v1/compte'),
      throwsA(
        isA<ErreurApi>().having((e) => e.code, 'code', 'non_authentifie'),
      ),
    );
    expect(renouvellements, 1);
    expect(perdue, 1);
    expect(s.ouverte, isFalse);
    expect(await s.appareilId(), id);
  });

  test(
    'appels sans session (connexion) : pas de renouvellement sur 401',
    () async {
      final s = await sessionOuverte();
      var n = 0;
      final api = ClientApi(
        base: base,
        session: s,
        client: MockClient((r) async {
          n++;
          return json(401, {
            'code': 'non_authentifie',
            'message': 'Adresse e-mail ou mot de passe incorrect.',
          });
        }),
      );
      final r = await api.requete(
        'POST',
        '/v1/sessions',
        json: {'email': 'a@b.fr', 'motDePasse': 'x'},
        authentifie: false,
      );
      expect(r.statut, 401);
      expect(n, 1);
      expect(s.ouverte, isTrue);
    },
  );

  test('erreurs JSON du serveur : code, message et disponibleLe', () async {
    final s = await sessionOuverte();
    final api = ClientApi(
      base: base,
      session: s,
      client: MockClient(
        (r) async => json(409, {
          'code': 'quota_epuise',
          'message': 'Quota épuisé.',
          'disponibleLe': '2026-11-26T08:00:00+01:00',
        }),
      ),
    );
    final e = await api
        .appel('PUT', '/v1/navigations/x', json: {})
        .then<Object>((_) => 'rien', onError: (Object e) => e);
    expect(e, isA<ErreurApi>());
    final err = e as ErreurApi;
    expect(
      [err.statut, err.code, err.message],
      [409, 'quota_epuise', 'Quota épuisé.'],
    );
    expect(err.disponibleLe, DateTime.parse('2026-11-26T07:00:00Z'));
  });

  test('sans réponse : HorsConnexion', () async {
    final s = await sessionOuverte();
    final api = ClientApi(
      base: base,
      session: s,
      client: MockClient(
        (r) async => throw http.ClientException('réseau coupé'),
      ),
    );
    expect(api.requete('GET', '/v1/quota'), throwsA(isA<HorsConnexion>()));
  });

  test('identifiant du téléphone tiré une fois et gardé (UUID v4)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await StockageSession.ouvrir();
    final id = await s.appareilId();
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(await (await StockageSession.ouvrir()).appareilId(), id);
  });
}
