import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../depot/depot.dart';
import 'api.dart';
import 'base_locale.dart';
import 'lecture_fichier.dart' as fichiers;

/// État d'un envoi de la file, lu après une passe : reçu par le serveur
/// (sorti de la file), encore en attente (hors connexion, serveur en panne)
/// ou refusé définitivement (4xx, mis de côté) avec l'erreur du serveur.
class EtatEnvoi {
  const EtatEnvoi._(this.recu, this.refus);
  static const reussi = EtatEnvoi._(true, null);
  static const enAttente = EtatEnvoi._(false, null);
  const EtatEnvoi.refuse(ErreurApi this.refus) : recu = false;

  final bool recu;
  final ErreurApi? refus;
  bool get refuse => refus != null;
}

/// Bilan d'une passe d'envoi de la file.
class BilanEnvoi {
  const BilanEnvoi({
    required this.envoyes,
    required this.misDeCote,
    required this.restants,
    required this.joignable,
  });
  final int envoyes;
  final int misDeCote;
  final int restants;

  /// Faux si le serveur n'a pas répondu ou a rendu une erreur (5xx).
  final bool joignable;
}

/// File d'attente du téléphone (RG-COM-05, 08-architecture.md §5) :
///
/// - **enregistrer d'abord** : chaque envoi est écrit dans la [BaseLocale]
///   avant toute tentative ;
/// - **identifiant UUID v4** tiré par le téléphone, **numéro d'ordre** par
///   navigation (`numeroOrdre`) ;
/// - **priorités** : alerte SOS d'abord, sans attendre la file
///   (`PUT /v1/alertes-sos/{id}`), puis les éléments légers par lots de 200
///   au plus (`POST /v1/synchronisation`), enfin les fichiers
///   (`PUT /v1/fichiers/{id}`), chacun après son événement ;
/// - **sortie de la file** à la réponse 200 ou 201 seulement (204 pour les
///   statuts des SMS et les fichiers, dont c'est la réponse : D-134) ; autre
///   4xx : mis de côté, sans nouvel essai ; 5xx ou pas de réponse : gardé ;
/// - **renvoi** à chaque nouvel envoi, sur [relancer] (retour de la connexion,
///   ouverture de l'application) et sinon après un délai croissant
///   ([delais]), sans limite de durée.
class FileAttente implements Envois {
  FileAttente({
    required this.base,
    required this.api,
    required this.appareilId,
    this.tailleLot = 200,
    Future<List<int>> Function(String chemin)? lireFichier,
    this.planifier,
  }) : _lireFichier = lireFichier ?? fichiers.lireFichier;

  final BaseLocale base;
  final ClientApi api;
  final Future<String> Function() appareilId;
  final int tailleLot;
  final Future<List<int>> Function(String) _lireFichier;

  /// Programme le prochain essai (essais) ; par défaut une minuterie.
  final void Function(Duration delai, void Function() action)? planifier;

  /// Délais entre deux essais après un échec : 30 secondes, 1, 2 et 5 minutes,
  /// puis toutes les 15 minutes (08-architecture.md §5).
  static const delais = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  /// Délai avant le prochain essai après [echecs] passes manquées de suite.
  static Duration delaiApres(int echecs) =>
      delais[min(max(echecs, 1), delais.length) - 1];

  final _reussis = StreamController<EnvoiReussi>.broadcast();
  final _uuid = const Uuid();
  Timer? _minuterie;
  int _echecs = 0;
  Future<BilanEnvoi>? _passe;
  bool _redemandee = false;

  /// Délai du prochain essai programmé, s'il y en a un.
  Duration? prochainEssai;

  static const _sansCorps = {'statuts_sms', 'fichier'};

  bool _sortie(String operation, int statut) =>
      statut == 200 ||
      statut == 201 ||
      (statut == 204 && _sansCorps.contains(operation));

  @override
  Stream<EnvoiReussi> get reussis => _reussis.stream;

  @override
  String nouvelId() => _uuid.v4();

  @override
  Future<int> enAttente() => base.compter();

  Future<Map<String, Object?>> _completer(
    String navigationId,
    Map<String, Object?> e,
  ) async => {
    ...e,
    'id': e['id'] ?? nouvelId(),
    'numeroOrdre':
        e['numeroOrdre'] ?? await base.numeroOrdreSuivant(navigationId),
  };

  Future<void> _ajouter(ElementFile e) async {
    await base.ajouterElement(e);
    unawaited(relancer());
  }

  @override
  Future<Map<String, Object?>> demarrage(
    String navigationId,
    Map<String, Object?> contenu,
  ) async {
    final debut = contenu['debut'];
    final c = {
      ...contenu,
      if (debut is Map<String, Object?>)
        'debut': await _completer(navigationId, debut),
    };
    await _ajouter(
      ElementFile(
        operation: 'demarrage',
        id: navigationId,
        navigationId: navigationId,
        contenu: c,
        priorite: Priorite.leger,
      ),
    );
    return c;
  }

  @override
  Future<Map<String, Object?>> evenement(
    String navigationId,
    Map<String, Object?> evenement,
  ) async {
    final e = await _completer(navigationId, evenement);
    await _ajouter(
      ElementFile(
        operation: 'evenement',
        id: e['id'] as String,
        navigationId: navigationId,
        contenu: e,
        priorite: Priorite.leger,
      ),
    );
    return e;
  }

  @override
  Future<Map<String, Object?>> fin(
    String navigationId,
    Map<String, Object?> evenement,
  ) async {
    final e = await _completer(navigationId, {...evenement, 'type': 'fin'});
    await _ajouter(
      ElementFile(
        operation: 'fin',
        id: navigationId,
        navigationId: navigationId,
        contenu: e,
        priorite: Priorite.leger,
      ),
    );
    return e;
  }

  /// Rejoindre la navigation en cours d'un bateau du compte depuis ce
  /// téléphone (RG-NAV-39, `operation: rejoindre`), avant ses événements.
  Future<void> rejoindre(String navigationId) async {
    await _ajouter(
      ElementFile(
        operation: 'rejoindre',
        id: navigationId,
        navigationId: navigationId,
        contenu: {'appareilId': await appareilId()},
        priorite: Priorite.leger,
      ),
    );
  }

  @override
  Future<void> alerteSos(String alerteId, Map<String, Object?> alerte) async {
    final e = ElementFile(
      operation: 'alerte_sos',
      id: alerteId,
      navigationId: alerte['navigationId'] as String?,
      contenu: {...alerte, 'id': alerteId},
      priorite: Priorite.sos,
    );
    await base.ajouterElement(e);
    // Sans attendre la file : l'alerte part tout de suite, même pendant une passe.
    try {
      if (await _envoyerSos(e) == _Issue.garde) _programmer();
    } on HorsConnexion {
      _programmer();
    }
  }

  @override
  Future<void> statutsSms(
    String alerteId,
    List<Map<String, Object?>> statuts,
  ) async {
    // Une nouvelle liste remplace celle qui attend encore (le serveur garde le plus récent, RG-SOS-12).
    await base.retirer('statuts_sms:$alerteId');
    await _ajouter(
      ElementFile(
        operation: 'statuts_sms',
        id: alerteId,
        contenu: statuts,
        priorite: Priorite.leger,
      ),
    );
  }

  @override
  Future<void> fichier(String evenementId, String chemin, String typeMedia) =>
      _ajouter(
        ElementFile(
          operation: 'fichier',
          id: evenementId,
          chemin: chemin,
          typeMedia: typeMedia,
          priorite: Priorite.fichier,
        ),
      );

  @override
  Future<void> relancer() async {
    _minuterie?.cancel();
    _minuterie = null;
    prochainEssai = null;
    await envoyer();
  }

  /// Une passe d'envoi ; une demande pendant une passe en relance une autre après elle.
  Future<BilanEnvoi> envoyer() {
    if (_passe != null) {
      _redemandee = true;
      return _passe!;
    }
    return _passe = () async {
      try {
        BilanEnvoi b;
        do {
          _redemandee = false;
          b = await _unePasse();
        } while (_redemandee && b.joignable);
        if (!b.joignable && b.restants > 0) {
          _echecs++;
          _programmer();
        } else {
          _echecs = 0;
        }
        return b;
      } finally {
        _passe = null;
      }
    }();
  }

  void _programmer() {
    if (_minuterie != null || prochainEssai != null) return;
    final d = delaiApres(_echecs);
    prochainEssai = d;
    void action() {
      _minuterie = null;
      prochainEssai = null;
      unawaited(envoyer());
    }

    final p = planifier;
    if (p != null) {
      p(d, action);
    } else {
      _minuterie = Timer(d, action);
    }
  }

  void _reussi(ElementFile e, int statut) =>
      _reussis.add(EnvoiReussi(e.operation, e.id, e.navigationId, statut));

  /// Traite la réponse d'un élément : sorti de la file, mis de côté ou gardé.
  Future<_Issue> _traiter(
    ElementFile e,
    int statut,
    Object? erreur, {
    bool garder4xx = false,
  }) async {
    if (_sortie(e.operation, statut)) {
      await base.retirer(e.cle);
      _reussi(e, statut);
      return _Issue.sorti;
    }
    // Session perdue (401), trop d'essais (429) ou délai (408) : rien ne dit
    // que l'élément est en cause, il reste en file.
    final definitif =
        statut >= 400 &&
        statut < 500 &&
        !const {401, 408, 429}.contains(statut) &&
        !garder4xx;
    await base.noterEchec(
      e.cle,
      statut: statut,
      // Erreur du serveur gardée en JSON, pour en relire le message (EtatEnvoi).
      erreur: erreur is Map ? jsonEncode(erreur) : erreur?.toString(),
      misDeCote: definitif,
    );
    return definitif ? _Issue.misDeCote : _Issue.garde;
  }

  Future<_Issue> _envoyerSos(ElementFile e) async {
    final r = await api.requete(
      'PUT',
      '/v1/alertes-sos/${e.id}',
      json: e.contenu,
    );
    return _traiter(e, r.statut, r.corps);
  }

  Future<BilanEnvoi> _unePasse() async {
    var envoyes = 0, deCote = 0;
    var joignable = true;
    final elements = await base.elementsAEnvoyer();
    try {
      // 1. Alertes SOS, une par une, avant tout le reste.
      for (final e in elements.where((e) => e.priorite == Priorite.sos)) {
        switch (await _envoyerSos(e)) {
          case _Issue.sorti:
            envoyes++;
          case _Issue.misDeCote:
            deCote++;
          case _Issue.garde:
            joignable = false;
        }
      }

      // 2. Éléments légers, par lots, dans l'ordre d'enregistrement.
      final legers = elements
          .where((e) => e.priorite == Priorite.leger)
          .toList();
      final bloquees = <String>{}; // navigations dont un élément reste en file
      for (var i = 0; i < legers.length && joignable; i += tailleLot) {
        final lot = legers.sublist(i, min(i + tailleLot, legers.length));
        final r = await api.requete(
          'POST',
          '/v1/synchronisation',
          json: {
            'appareilId': await appareilId(),
            'elements': [
              for (final e in lot)
                {
                  'operation': e.operation,
                  'id': e.id,
                  if (e.navigationId != null) 'navigationId': e.navigationId,
                  'contenu': e.contenu,
                },
            ],
          },
        );
        final resultats = r.corps is Map ? (r.corps as Map)['resultats'] : null;
        if (r.statut != 200 ||
            resultats is! List ||
            resultats.length != lot.length) {
          // Lot refusé en entier (session perdue, erreur du serveur) : tout reste en file.
          joignable = false;
          break;
        }
        for (var k = 0; k < lot.length; k++) {
          final e = lot[k];
          final res = resultats[k] is Map ? resultats[k] as Map : const {};
          final statut = (res['statut'] as num?)?.toInt() ?? 500;
          // Un élément qui suit, dans la même navigation, un élément resté en
          // file n'est pas mis de côté : son refus vient sans doute de là.
          final nav = e.navigationId;
          final garder = nav != null && bloquees.contains(nav);
          switch (await _traiter(e, statut, res['erreur'], garder4xx: garder)) {
            case _Issue.sorti:
              envoyes++;
            case _Issue.misDeCote:
              deCote++;
            case _Issue.garde:
              if (nav != null) bloquees.add(nav);
              if (statut >= 500) joignable = false;
          }
        }
      }

      // 3. Fichiers, chacun après son événement.
      if (joignable) {
        final restantes = {
          for (final e in await base.elementsAEnvoyer())
            if (e.operation == 'evenement') e.id,
        };
        for (final e in elements.where((e) => e.priorite == Priorite.fichier)) {
          if (restantes.contains(e.id)) continue;
          List<int> octets;
          try {
            octets = await _lireFichier(e.chemin ?? '');
          } catch (err) {
            await base.noterEchec(
              e.cle,
              erreur: 'fichier_illisible: $err',
              misDeCote: true,
            );
            deCote++;
            continue;
          }
          final r = await api.requete(
            'PUT',
            '/v1/fichiers/${e.id}',
            octets: octets,
            typeContenu: e.typeMedia,
          );
          final issue = await _traiter(e, r.statut, r.corps);
          if (issue == _Issue.sorti) {
            envoyes++;
          } else if (issue == _Issue.misDeCote) {
            deCote++;
          } else {
            joignable = false;
            break;
          }
        }
      }
    } on HorsConnexion {
      joignable = false;
    }
    return BilanEnvoi(
      envoyes: envoyes,
      misDeCote: deCote,
      restants: await base.compter(),
      joignable: joignable,
    );
  }

  /// État de l'élément de clé [cle] (`operation:id`) : sorti de la file,
  /// en attente ou mis de côté avec l'erreur du serveur.
  Future<EtatEnvoi> etat(String cle) async {
    for (final e in await base.elementsMisDeCote()) {
      if (e.cle != cle) continue;
      Object? c;
      try {
        c = e.derniereErreur == null ? null : jsonDecode(e.derniereErreur!);
      } on FormatException {
        c = null;
      }
      return EtatEnvoi.refuse(
        ErreurApi.depuis(ReponseApi(e.dernierStatut ?? 400, c)),
      );
    }
    for (final e in await base.elementsAEnvoyer()) {
      if (e.cle == cle) return EtatEnvoi.enAttente;
    }
    return EtatEnvoi.reussi;
  }

  /// Attend la passe en cours, au plus [delai] ; puis rend l'état de [cle].
  Future<EtatEnvoi> etatApresPasse(String cle, Duration delai) async {
    try {
      await attendrePasse().timeout(delai);
    } on TimeoutException {
      // Serveur lent : l'élément reste en file et partira plus tard.
    }
    return etat(cle);
  }

  /// Retire un élément mis de côté (refus lu et traité par l'application).
  Future<void> oublier(String cle) => base.retirer(cle);

  /// Attend la fin de la passe en cours, s'il y en a une.
  Future<void> attendrePasse() async {
    while (_passe != null) {
      await _passe;
    }
  }

  void fermer() {
    _minuterie?.cancel();
    _reussis.close();
  }
}

enum _Issue { sorti, misDeCote, garde }
