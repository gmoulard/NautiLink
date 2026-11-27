import 'dart:async';

import 'package:flutter/foundation.dart';

import '../depot/modeles.dart';
import 'api.dart';

/// Événement du journal d'une navigation lu sur le serveur (schéma
/// `Evenement`), pour la page de la navigation dans l'application
/// (RG-IOS-05, RG-AND-09).
class EvenementSuivi {
  const EvenementSuivi({
    required this.id,
    required this.type,
    required this.heure,
    this.position,
    this.lieu,
    this.texte,
    this.typeMedia,
    this.dureeSecondes,
    this.fichierRecu = false,
    this.masque = false,
  });

  final String id;
  final String type;
  final DateTime heure;
  final PositionGps? position;
  final String? lieu;
  final String? texte;
  final String? typeMedia;
  final int? dureeSecondes;
  final bool fichierRecu;

  /// Hors de la plage modifiée par le navigateur (RG-NAV-22) : non affiché.
  final bool masque;

  static EvenementSuivi? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['type'] is! String) return null;
    final h = j['heureAcquisition'] is String
        ? DateTime.tryParse(j['heureAcquisition'] as String)
        : null;
    if (h == null) return null;
    final f = j['fichier'];
    return EvenementSuivi(
      id: j['id'] as String,
      type: j['type'] as String,
      heure: h.toLocal(),
      position: PositionGps.depuisJson(j['position']),
      lieu: j['lieu'] as String?,
      texte: j['texte'] as String?,
      typeMedia: f is Map ? f['typeMedia'] as String? : null,
      dureeSecondes: f is Map ? (f['dureeSecondes'] as num?)?.toInt() : null,
      fichierRecu: f is Map && f['recu'] == true,
      masque: j['masque'] == true,
    );
  }
}

/// Personne (schéma `Personne`) : navigateur, amis.
class PersonneSuivi {
  const PersonneSuivi(this.nom, {this.email, this.telephone});
  final String nom;
  final String? email;
  final String? telephone;

  static PersonneSuivi? depuisJson(Object? j) => j is Map
      ? PersonneSuivi(
          (j['nom'] as String?) ?? '',
          email: j['email'] as String?,
          telephone: j['telephone'] as String?,
        )
      : null;
}

/// Détail d'une navigation (schéma `Navigation`).
class DetailNavigation {
  const DetailNavigation({
    required this.resume,
    required this.brut,
    this.navigateur,
    this.amis = const [],
    this.fiche,
    this.lieuDepart,
    this.lieuArrivee,
    this.destination,
    this.personnesABord,
    this.frequenceMinutes,
  });
  final ResumeNavigation resume;
  final Map<String, Object?> brut;
  final PersonneSuivi? navigateur;

  /// Amis de la navigation, une seule liste (RG-PAR-08, D-186).
  final List<PersonneSuivi> amis;
  final Map<String, Object?>? fiche;
  final String? lieuDepart;
  final String? lieuArrivee;
  final String? destination;
  final int? personnesABord;
  final int? frequenceMinutes;

  static String? _lieu(Object? l) => l is Map
      ? (l['nom'] as String?) ?? (l['texte'] as String?)
      : (l is String ? l : null);

  static DetailNavigation? depuisJson(Map<String, Object?> j) {
    final r = ResumeNavigation.depuisJson(j);
    if (r == null) return null;
    List<PersonneSuivi> personnes(Object? v) => [
      for (final p in v is List ? v : const []) ?PersonneSuivi.depuisJson(p),
    ];
    final d = j['destination'];
    final f = j['fiche'];
    return DetailNavigation(
      resume: r,
      brut: j,
      navigateur: PersonneSuivi.depuisJson(j['navigateur']),
      amis: personnes(j['amis']),
      fiche: f is Map<String, Object?> ? f : null,
      lieuDepart: _lieu(j['lieuDepart']),
      lieuArrivee: _lieu(j['lieuArrivee']),
      destination: d is Map ? d['texte'] as String? : null,
      personnesABord: (j['personnesABord'] as num?)?.toInt(),
      frequenceMinutes: (j['frequenceMinutes'] as num?)?.toInt(),
    );
  }
}

/// Alerte SOS d'une navigation (schéma `AlerteSos`).
class AlerteSuivie {
  const AlerteSuivie({
    required this.id,
    required this.heure,
    this.position,
    this.probleme,
  });
  final String id;
  final DateTime heure;
  final PositionGps? position;
  final String? probleme;

  static AlerteSuivie? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    final h = j['heureDeclenchement'] is String
        ? DateTime.tryParse(j['heureDeclenchement'] as String)
        : null;
    if (h == null) return null;
    return AlerteSuivie(
      id: j['id'] as String,
      heure: h.toLocal(),
      position: PositionGps.depuisJson(j['position']),
      probleme: j['problemeRencontre'] as String?,
    );
  }
}

/// Page d'une navigation dans l'application (RG-IOS-05, RG-AND-09) :
/// détail, journal et alertes SOS lus sur le serveur ; pendant une
/// navigation en cours, le journal est relu toutes les [pas] avec le curseur
/// `depuis`, pour suivre les positions à mesure qu'elles arrivent (cahier des
/// charges §6.2). Lecture seule.
class SuiviNavigation extends ChangeNotifier {
  SuiviNavigation({
    required this.api,
    required this.navigationId,
    this.pas = const Duration(seconds: 30),
  });

  final ClientApi api;
  final String navigationId;

  /// Intervalle de relecture d'une navigation en cours ; vide : pas de minuterie (essais).
  final Duration? pas;

  DetailNavigation? detail;
  final Map<String, EvenementSuivi> _evenements = {};
  List<AlerteSuivie> alertes = const [];
  String? _curseur;
  Object? erreur;
  bool chargement = true;
  Timer? _minuterie;
  bool _ferme = false;

  /// Journal dans l'ordre de l'heure d'acquisition (RG-JRN-01), sans les
  /// événements masqués (RG-NAV-22).
  List<EvenementSuivi> get journal =>
      _evenements.values.where((e) => !e.masque).toList()
        ..sort((a, b) => a.heure.compareTo(b.heure));

  /// Tracé : positions successives du journal (cahier des charges §6.2).
  List<PositionGps> get trace => [
    for (final e in journal)
      if (e.position != null) e.position!,
  ];

  void _notifier() {
    if (!_ferme) notifyListeners();
  }

  Future<void> charger() async {
    try {
      final d = DetailNavigation.depuisJson(
        await api.appelObjet('GET', '/v1/navigations/$navigationId'),
      );
      detail = d;
      await _lireJournal();
      final a = await api.appel(
        'GET',
        '/v1/alertes-sos',
        parametres: {'navigationId': navigationId},
      );
      alertes = [
        for (final x in a is List ? a : const []) ?AlerteSuivie.depuisJson(x),
      ];
      erreur = null;
      final p = pas;
      if (d != null && d.resume.enCours && p != null && _minuterie == null) {
        _minuterie = Timer.periodic(p, (_) => unawaited(actualiser()));
      }
    } catch (e) {
      erreur = e;
      debugPrint('Navigation $navigationId : $e');
    }
    chargement = false;
    _notifier();
  }

  Future<void> _lireJournal() async {
    final r = await api.appelObjet(
      'GET',
      '/v1/navigations/$navigationId/evenements',
      parametres: {'depuis': ?_curseur},
    );
    for (final e in (r['evenements'] as List?) ?? const []) {
      final x = EvenementSuivi.depuisJson(e);
      if (x != null) _evenements[x.id] = x;
    }
    for (final id in (r['supprimes'] as List?) ?? const []) {
      _evenements.remove(id);
    }
    if (r['curseur'] is String) _curseur = r['curseur'] as String;
  }

  /// Relecture : nouveaux événements, puis fin de la navigation.
  Future<void> actualiser() async {
    try {
      await _lireJournal();
      if (journal.any((e) => e.type == 'fin')) {
        _minuterie?.cancel();
        _minuterie = null;
        final d = DetailNavigation.depuisJson(
          await api.appelObjet('GET', '/v1/navigations/$navigationId'),
        );
        if (d != null) detail = d;
      }
      erreur = null;
    } catch (e) {
      erreur = e;
    }
    _notifier();
  }

  /// Fichier d'une photo ou d'une note vocale (`GET /v1/fichiers/{id}`).
  Future<Uint8List?> fichier(String evenementId) async {
    try {
      final r = await api.requete('GET', '/v1/fichiers/$evenementId');
      return r.reussie ? Uint8List.fromList(r.octets) : null;
    } catch (e) {
      debugPrint('Fichier $evenementId : $e');
      return null;
    }
  }

  @override
  void dispose() {
    _ferme = true;
    _minuterie?.cancel();
    super.dispose();
  }
}
