import 'dart:async';
import 'dart:math';

import '../data.dart';
import 'depot.dart';

/// Dépôt de démonstration : présente les données d'exemple de [AppState]
/// (`lib/data.dart`) ; rien n'est envoyé (D-57, D-127). Les écrans de la
/// démonstration continuent d'agir sur [AppState] ; ce dépôt en donne la vue
/// commune à la vraie application.
class DepotDemo extends Depot {
  DepotDemo(this.state) {
    state.addListener(notifyListeners);
  }

  final AppState state;
  final _ids = Expando<String>();
  late final EnvoisDemo _envois = EnvoisDemo();
  late final PositionsDemo _positions = PositionsDemo(state);

  String _id(Voyage v) => _ids[v] ??= 'demo-${identityHashCode(v)}';

  @override
  bool get demonstration => true;

  @override
  EtatSession get etatSession => EtatSession.connecte;

  @override
  bool get horsConnexion => false;

  @override
  DateTime? get actualiseLe => null;

  @override
  ProfilNl? get profil => null;

  @override
  List<ResumeNavigation> get navigations {
    final l = [
      for (final v in state.voyages)
        ResumeNavigation(
          id: _id(v),
          nom: v.name,
          enCours: v.inProgress,
          debut: v.start,
          fin: v.end,
          bateauId: v.boat.name,
          bateauNom: v.boat.name,
          commeSuiveur: v.asFollower,
          dureeMinutes: v.duration.inMinutes,
          distanceMetres: v.distanceNm * 1852,
        ),
    ];
    l.sort((a, b) {
      if (a.enCours != b.enCours) return a.enCours ? -1 : 1;
      return b.debut.compareTo(a.debut);
    });
    return l;
  }

  @override
  ResumeNavigation? get navigationEnCours {
    final v = state.current;
    if (v == null) return null;
    return navigations.firstWhere((n) => n.id == _id(v));
  }

  @override
  List<BateauNl> get bateaux => [
    for (final b in state.boats)
      BateauNl(id: b.name, nom: b.name, type: b.type == 'Voilier' ? 'voilier' : 'moteur'),
  ];

  @override
  List<ContactNl> get contacts => [
    for (final c in state.contacts)
      ContactNl(
        id: c.name,
        nom: c.name,
        telephone: c.phone,
        email: c.email,
        suiveur: c.follower,
        contactSos: c.sos,
      ),
  ];

  static const _typesSms = {
    SmsType.start: 'debut',
    SmsType.autoPosition: 'positionsAutomatiques',
    SmsType.manualPosition: 'positionsManuelles',
    SmsType.note: 'notes',
    SmsType.photo: 'photos',
    SmsType.voice: 'notesVocales',
    SmsType.end: 'fin',
  };

  @override
  ParametresGeneraux get parametres => ParametresGeneraux(
    smsActifs: state.smsEnabled,
    smsParType: {
      for (final e in state.smsByType.entries) _typesSms[e.key]!: e.value,
    },
    photoEnMms: false,
    frequenceParDefaut: state.defaultFrequency,
  );

  @override
  EtatQuota get quota {
    final used = state.usedMinutes.clamp(0, AppState.quotaMinutes);
    return EtatQuota(
      consommeMinutes: used,
      disponibleMinutes: AppState.quotaMinutes - used,
      epuise: used >= AppState.quotaMinutes,
    );
  }

  @override
  List<AlerteSosResume> get alertes => const [];

  @override
  Envois get envois => _envois;

  @override
  SourcePosition get positions => _positions;

  @override
  Future<void> ouvrir() async {}

  @override
  Future<void> actualiser() async {}

  @override
  Future<void> deconnecter() async {}

  @override
  void dispose() {
    state.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Envois simulés : chaque élément « part » aussitôt, rien ne quitte le téléphone.
class EnvoisDemo implements Envois {
  final _rnd = Random();
  final _reussis = StreamController<EnvoiReussi>.broadcast();
  final _ordres = <String, int>{};

  /// Éléments « envoyés », dans l'ordre.
  final envoyes = <EnvoiReussi>[];

  void _ok(String op, String id, String? nav) {
    final e = EnvoiReussi(op, id, nav, 201);
    envoyes.add(e);
    _reussis.add(e);
  }

  @override
  String nouvelId() {
    String h(int n) => List.generate(n, (_) => _rnd.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-${'89ab'[_rnd.nextInt(4)]}${h(3)}-${h(12)}';
  }

  Map<String, Object?> _completer(String nav, Map<String, Object?> e) => {
    ...e,
    'id': e['id'] ?? nouvelId(),
    'numeroOrdre': e['numeroOrdre'] ?? (_ordres[nav] = (_ordres[nav] ?? 0) + 1),
  };

  @override
  Future<Map<String, Object?>> demarrage(String navigationId, Map<String, Object?> contenu) async {
    final debut = contenu['debut'];
    final c = {
      ...contenu,
      if (debut is Map<String, Object?>) 'debut': _completer(navigationId, debut),
    };
    _ok('demarrage', navigationId, navigationId);
    return c;
  }

  @override
  Future<Map<String, Object?>> evenement(String navigationId, Map<String, Object?> evenement) async {
    final e = _completer(navigationId, evenement);
    _ok('evenement', e['id'] as String, navigationId);
    return e;
  }

  @override
  Future<Map<String, Object?>> fin(String navigationId, Map<String, Object?> evenement) async {
    final e = _completer(navigationId, evenement);
    _ok('fin', navigationId, navigationId);
    return e;
  }

  @override
  Future<void> alerteSos(String alerteId, Map<String, Object?> alerte) async =>
      _ok('alerte_sos', alerteId, alerte['navigationId'] as String?);

  @override
  Future<void> statutsSms(String alerteId, List<Map<String, Object?>> statuts) async =>
      _ok('statuts_sms', alerteId, null);

  @override
  Future<void> fichier(String evenementId, String chemin, String typeMedia) async =>
      _ok('fichier', evenementId, null);

  @override
  Future<void> relancer() async {}

  @override
  Future<int> enAttente() async => 0;

  @override
  Stream<EnvoiReussi> get reussis => _reussis.stream;
}

/// Positions de démonstration : le parcours simulé de [AppState].
class PositionsDemo implements SourcePosition {
  PositionsDemo(this.state);
  final AppState state;
  PositionGps? _derniere;

  @override
  Future<PositionGps?> positionActuelle() async {
    final p = state.nextPosition();
    return _derniere = PositionGps(latitude: p.lat, longitude: p.lon, heureAcquisition: p.time);
  }

  @override
  PositionGps? get derniereConnue => _derniere;
}
