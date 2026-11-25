import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/depot_reel.dart';
import 'package:nautilink/reel/file_attente.dart';
import 'package:nautilink/reel/stockage_session.dart';

http.Response reponse(int statut, [Object? corps]) => http.Response.bytes(
  corps == null ? const [] : utf8.encode(jsonEncode(corps)),
  statut,
);

http.Response erreur(int statut, String code, String message) =>
    reponse(statut, {'code': code, 'message': message});

/// Faux serveur NautiLink pour les essais de la vraie application : un compte,
/// deux bateaux (le second déjà associé à un autre téléphone), une navigation
/// en cours et une terminée.
class FauxServeurNautiLink {
  final appels = <String>[];
  final adresses = <Uri>[];
  final corps = <String, Object?>{};
  bool coupe = false;
  bool sessionsFermees = false;
  String motDePasse = 'secret123';
  String avertissement = '2026-11-24';
  bool avertissementChange = false;
  bool emailVerifie = true;
  int jetons = 0;

  MockClient get client => MockClient((r) async {
    if (coupe) throw http.ClientException('pas de réseau');
    final chemin = r.url.path.replaceFirst(RegExp(r'^.*/api'), '');
    appels.add('${r.method} $chemin');
    adresses.add(r.url);
    final c = r.body.isEmpty ? null : jsonDecode(r.body);
    corps['${r.method} $chemin'] = c;
    final auth = r.headers['Authorization'];
    final ouvert =
        auth != null && auth.startsWith('Bearer A') && !sessionsFermees;

    http.Response session() {
      jetons++;
      return reponse(
        r.method == 'POST' && chemin == '/v1/comptes' ? 201 : 200,
        {
          'jetonAcces': 'A$jetons',
          'jetonRenouvellement': 'R$jetons',
          'expireLe': '2027-02-23T10:00:00Z',
        },
      );
    }

    switch ((r.method, chemin)) {
      case ('GET', '/v1/avertissement'):
        return reponse(200, {
          'version': avertissement,
          'adresseTexte': 'https://exemple/avertissement.html',
        });
      case ('POST', '/v1/sessions'):
        final m = c as Map;
        if (m['motDePasse'] != motDePasse) {
          return erreur(
            401,
            'non_authentifie',
            'Adresse e-mail ou mot de passe incorrect.',
          );
        }
        if (avertissementChange && m['avertissementVersion'] != avertissement) {
          return erreur(
            428,
            'avertissement_a_accepter',
            'Lisez et acceptez l\'avertissement bêta pour continuer.',
          );
        }
        return session();
      case ('POST', '/v1/comptes'):
        final m = c as Map;
        if (m['avertissementVersion'] != avertissement) {
          return erreur(
            422,
            'avertissement_a_accepter',
            'Lisez et acceptez l\'avertissement bêta.',
          );
        }
        emailVerifie = false;
        return session();
      case ('POST', '/v1/sessions/renouvellement'):
        return sessionsFermees
            ? erreur(401, 'non_authentifie', 'Session expirée.')
            : session();
      case ('POST', '/v1/compte/mot-de-passe/oubli'):
        return reponse(204);
    }
    if (!ouvert) return erreur(401, 'non_authentifie', 'Connectez-vous.');
    if (chemin.startsWith('/v1/appareils/')) {
      return reponse(200, {...c as Map, 'id': chemin.split('/').last});
    }
    if (chemin.startsWith('/v1/bateaux/') && chemin.endsWith('/telephone')) {
      return reponse(200, {
        'id': chemin.split('/')[3],
        'nom': 'Alizé',
        'type': 'voilier',
        'appareilAssocieId': (c as Map)['appareilId'],
      });
    }
    switch ((r.method, chemin)) {
      case ('GET', '/v1/compte'):
        return reponse(200, {
          'id': 'u1',
          'email': 'marin@example.org',
          'nom': 'Marin',
          'emailVerifie': emailVerifie,
        });
      case ('POST', '/v1/compte/verification/envoi'):
        return reponse(204);
      case ('GET', '/v1/navigations'):
        return reponse(200, {
          'navigations': [
            {
              'id': 'n1',
              'nom': 'Alizé — Houat',
              'role': 'navigateur',
              'etat': 'en_cours',
              'bateau': {'id': 'b1', 'nom': 'Alizé'},
              'debut': '2026-11-25T09:00:00+01:00',
            },
            {
              'id': 'n0',
              'nom': 'Alizé — Belle-Île',
              'role': 'navigateur',
              'etat': 'terminee',
              'bateau': {'id': 'b1', 'nom': 'Alizé'},
              'debut': '2026-11-20T09:00:00+01:00',
              'fin': '2026-11-20T13:00:00+01:00',
            },
          ],
          'curseurSuivant': null,
        });
      case ('GET', '/v1/quota'):
        return reponse(200, {
          'consommeMinutes': 300,
          'disponibleMinutes': 1140,
          'epuise': false,
          'prochainesMinutes': [
            {'minutes': 240, 'disponiblesLe': '2026-11-27T13:00:00+01:00'},
          ],
          'abonnement': {'actif': false},
        });
      case ('GET', '/v1/bateaux'):
        return reponse(200, [
          {
            'id': 'b1',
            'nom': 'Alizé',
            'type': 'voilier',
            'appareilAssocieId': null,
          },
          {
            'id': 'b2',
            'nom': 'Petit Pingouin',
            'type': 'moteur',
            'appareilAssocieId': '00000000-0000-4000-8000-000000000000',
          },
        ]);
      case ('GET', '/v1/contacts'):
        return reponse(200, {
          'contacts': [
            {
              'id': 'c1',
              'nom': 'Claire',
              'telephone': '+33612345678',
              'suiveur': true,
              'contactSos': true,
            },
          ],
          'supprimes': [],
          'curseur': 'k1',
        });
      case ('GET', '/v1/parametres'):
        return reponse(200, {
          'smsActifs': true,
          'smsParType': {'debut': true},
          'photoEnMms': false,
          'frequenceParDefaut': 60,
        });
      case ('GET', '/v1/alertes-sos'):
        return reponse(200, []);
      case ('DELETE', '/v1/sessions/courante'):
        return reponse(204);
      case ('POST', '/v1/synchronisation'):
        final el = (c as Map)['elements'] as List;
        return reponse(200, {
          'resultats': [
            for (final e in el) {'id': e['id'], 'statut': 201},
          ],
        });
    }
    return erreur(404, 'introuvable', 'Introuvable.');
  });

  /// Dépôt branché sur ce faux serveur, sans minuterie (les essais relancent la file eux-mêmes).
  DepotReel depot(StockageSession session, BaseLocale base) {
    final api = ClientApi(
      base: 'https://essai.example/nautilink/api',
      session: session,
      client: client,
    );
    return DepotReel(
      api: api,
      session: session,
      base: base,
      plateforme: 'android',
      nomAppareil: 'Essai',
      file: FileAttente(
        base: base,
        api: api,
        appareilId: session.appareilId,
        planifier: (_, _) {},
      ),
    );
  }
}
