import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nautilink/depot/depot.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/depot_reel.dart';
import 'package:nautilink/reel/file_attente.dart';
import 'package:nautilink/reel/medias.dart';
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

  /// Navigation « Alizé — Houat » en cours sur le serveur.
  bool navigationEnCours = true;
  bool quotaEpuise = false;

  /// Refus du prochain démarrage reçu : (statut, code, message).
  (int, String, String)? refusDemarrage;

  /// Refus des événements reçus : (statut, code, message).
  (int, String, String)? refusEvenements;

  /// Éléments reçus par `POST /v1/synchronisation` (opération, id, contenu),
  /// alertes SOS et fichiers reçus.
  final elements = <(String, String, Object?)>[];
  final alertes = <String, Object?>{};
  final fichiers = <String, (String?, int)>{};

  /// Navigations démarrées depuis le téléphone (identifiant → résumé).
  final demarrees = <String, Map<String, Object?>>{};

  /// Téléphone associé à chaque bateau (RG-BAT-02).
  final associations = <String, String>{};

  Map<String, Object?> _resultat(Map e) {
    final op = e['operation'] as String;
    final id = e['id'] as String;
    elements.add((op, id, e['contenu']));
    Map<String, Object?> refus((int, String, String) r) => {
      'id': id,
      'statut': r.$1,
      'erreur': {
        'code': r.$2,
        'message': r.$3,
        if (r.$2 == 'quota_epuise') 'disponibleLe': '2026-11-27T13:00:00+01:00',
      },
    };
    switch (op) {
      case 'demarrage':
        final r = refusDemarrage;
        if (r != null) return refus(r);
        final c = e['contenu'] as Map;
        final d = (c['destination'] as Map?)?['texte'];
        demarrees[id] = {
          'id': id,
          'nom': d == null ? 'Alizé — 2026-11-25 10:00' : 'Alizé — $d',
          'role': 'navigateur',
          'etat': 'en_cours',
          'bateau': {'id': c['bateauId'], 'nom': 'Alizé'},
          'debut': (c['debut'] as Map)['heureAcquisition'],
          'frequenceMinutes': c['frequenceMinutes'],
          'personnesABord': c['personnesABord'],
        };
      case 'evenement':
        final r = refusEvenements;
        if (r != null) return refus(r);
      case 'fin':
        final n = demarrees[id];
        if (n != null) {
          n['etat'] = 'terminee';
          n['fin'] = (e['contenu'] as Map)['heureAcquisition'];
        }
        if (id == 'n1') navigationEnCours = false;
    }
    return {'id': id, 'statut': op == 'statuts_sms' ? 204 : 201};
  }

  MockClient get client => MockClient((r) async {
    if (coupe) throw http.ClientException('pas de réseau');
    final chemin = r.url.path.replaceFirst(RegExp(r'^.*/api'), '');
    appels.add('${r.method} $chemin');
    adresses.add(r.url);
    final json = r.headers['Content-Type']?.startsWith('application/json');
    final c = r.bodyBytes.isEmpty || json != true ? null : jsonDecode(r.body);
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
    if (r.method == 'PUT' && chemin.startsWith('/v1/alertes-sos/')) {
      final id = chemin.split('/')[3];
      final deja = alertes.containsKey(id);
      alertes[id] = c;
      return reponse(deja ? 200 : 201, {...c as Map, 'emailsEnvoyesA': []});
    }
    if (r.method == 'PUT' && chemin.startsWith('/v1/fichiers/')) {
      fichiers[chemin.split('/').last] = (
        r.headers['Content-Type'],
        r.bodyBytes.length,
      );
      return reponse(204);
    }
    if (r.method == 'GET' && chemin.startsWith('/v1/navigations/')) {
      final id = chemin.split('/').last;
      final n = demarrees[id];
      if (n != null) return reponse(200, n);
      if (id == 'n1') {
        return reponse(200, {
          'id': 'n1',
          'nom': 'Alizé — Houat',
          'role': 'navigateur',
          'etat': navigationEnCours ? 'en_cours' : 'terminee',
          'bateau': {'id': 'b1', 'nom': 'Alizé'},
          'debut': '2026-11-25T09:00:00+01:00',
          'frequenceMinutes': 60,
          'personnesABord': 3,
        });
      }
    }
    if (chemin.startsWith('/v1/bateaux/') && chemin.endsWith('/telephone')) {
      associations[chemin.split('/')[3]] = (c as Map)['appareilId'] as String;
      return reponse(200, {
        'id': chemin.split('/')[3],
        'nom': 'Alizé',
        'type': 'voilier',
        'appareilAssocieId': c['appareilId'],
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
            ...demarrees.values.where((n) => n['etat'] == 'en_cours'),
            {
              'id': 'n1',
              'nom': 'Alizé — Houat',
              'role': 'navigateur',
              'etat': navigationEnCours ? 'en_cours' : 'terminee',
              'bateau': {'id': 'b1', 'nom': 'Alizé'},
              'debut': '2026-11-25T09:00:00+01:00',
            },
            ...demarrees.values.where((n) => n['etat'] != 'en_cours'),
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
          'consommeMinutes': quotaEpuise ? 1440 : 300,
          'disponibleMinutes': quotaEpuise ? 0 : 1140,
          'epuise': quotaEpuise,
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
            'appareilAssocieId': associations['b1'],
          },
          {
            'id': 'b2',
            'nom': 'Petit Pingouin',
            'type': 'moteur',
            'appareilAssocieId':
                associations['b2'] ?? '00000000-0000-4000-8000-000000000000',
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
          'resultats': [for (final e in el) _resultat(e as Map)],
        });
    }
    return erreur(404, 'introuvable', 'Introuvable.');
  });

  /// Dépôt branché sur ce faux serveur, sans minuterie (les essais relancent la file eux-mêmes).
  DepotReel depot(
    StockageSession session,
    BaseLocale base, {
    SourcePosition? positions,
    DateTime Function()? horloge,
    Medias? medias,
  }) {
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
      positions: positions,
      horloge: horloge,
      pasVerification: null,
      medias: medias,
      file: FileAttente(
        base: base,
        api: api,
        appareilId: session.appareilId,
        planifier: (_, _) {},
        // Fichiers d'essai : 1 000 octets, quel que soit le chemin.
        lireFichier: (_) async => List.filled(1000, 7),
      ),
    );
  }
}

/// GPS d'essai : rend [position] (vide : GPS indisponible) ; [suivi] donne
/// les positions du flux des positions automatiques.
class FauxGps implements SourcePosition {
  FauxGps([this.position]);
  PositionGps? position;
  int demandes = 0;
  int acquisitions = 0;
  final suivi = StreamController<PositionGps>.broadcast();
  Duration? frequenceSuivie;

  @override
  Future<PositionGps?> positionActuelle({bool demander = false}) async {
    acquisitions++;
    if (demander) demandes++;
    return position;
  }

  @override
  PositionGps? get derniereConnue => position;

  @override
  Stream<PositionGps> suivre(Duration frequence) {
    frequenceSuivie = frequence;
    return suivi.stream;
  }
}

PositionGps positionEssai([DateTime? t]) => PositionGps(
  latitude: 47.38,
  longitude: -2.95,
  heureAcquisition: t ?? DateTime(2026, 11, 25, 10),
  precisionMetres: 8,
);

/// Appareil photo et micro d'essai.
class FauxMedias implements Medias {
  bool micro = true;
  bool annulee = false;
  final oublies = <String>[];

  @override
  Future<FichierMedia?> photo(String evenementId) async =>
      annulee ? null : FichierMedia('/essai/$evenementId.jpg', 950000);

  @override
  Future<bool> commencerVocal(String evenementId) async => micro;

  @override
  Future<FichierMedia?> arreterVocal() async =>
      const FichierMedia('/essai/vocal.m4a', 120000);

  @override
  Future<void> annulerVocal() async {}

  @override
  Future<void> oublier(String evenementId) async => oublies.add(evenementId);
}
