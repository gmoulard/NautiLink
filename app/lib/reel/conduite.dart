import 'dart:async';

import 'package:flutter/foundation.dart';

import '../depot/depot.dart';
import 'api.dart';
import 'base_locale.dart';
import 'file_attente.dart';

/// Événement du journal tenu sur le téléphone pendant la navigation, affiché
/// sur l'écran de navigation (schéma `Evenement`, champs utiles à l'écran).
class EvenementLocal {
  const EvenementLocal({
    required this.id,
    required this.type,
    required this.heure,
    this.position,
    this.texte,
    this.dureeSecondes,
  });

  final String id;

  /// debut, position_automatique, position_manuelle, note, photo,
  /// note_vocale, sos, fin (RG-JRN-02).
  final String type;
  final DateTime heure;
  final PositionGps? position;
  final String? texte;
  final int? dureeSecondes;

  Map<String, Object?> versJson() => {
    'id': id,
    'type': type,
    'heure': heureRfc3339(heure),
    'position': position?.versJson(),
    'texte': texte,
    'dureeSecondes': dureeSecondes,
  };

  static EvenementLocal? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['type'] is! String) return null;
    final h = j['heure'] is String ? DateTime.tryParse(j['heure']) : null;
    if (h == null) return null;
    return EvenementLocal(
      id: j['id'] as String,
      type: j['type'] as String,
      heure: h.toLocal(),
      position: PositionGps.depuisJson(j['position']),
      texte: j['texte'] as String?,
      dureeSecondes: (j['dureeSecondes'] as num?)?.toInt(),
    );
  }
}

/// Navigation en cours sur ce téléphone, gardée dans la base locale : elle
/// survit à une fermeture forcée ou à un redémarrage (RG-NAV-12).
class NavigationLocale {
  NavigationLocale({
    required this.id,
    required this.nom,
    required this.bateauId,
    required this.bateauNom,
    required this.debut,
    required this.frequenceMinutes,
    required this.personnesABord,
    this.destination,
    this.personnesAlertees = const [],
    List<EvenementLocal>? journal,
    this.derniereAutomatique,
    this.dernierEnvoi,
    this.refus,
  }) : journal = journal ?? [];

  final String id;
  String nom;
  final String bateauId;
  final String bateauNom;
  final DateTime debut;
  final int frequenceMinutes;
  final int personnesABord;
  final String? destination;
  final List<String> personnesAlertees;
  final List<EvenementLocal> journal;

  /// Heure de la dernière position automatique enregistrée (RG-GPS-03).
  DateTime? derniereAutomatique;

  /// Dernier envoi reçu par le serveur (chronomètre, RG-NAV-10).
  DateTime? dernierEnvoi;

  /// Message du serveur qui a refusé cette navigation ou ses envois
  /// (démarrage refusé après coup, clôture automatique : Q-87, RG-ECO-12).
  String? refus;

  Map<String, Object?> versJson() => {
    'id': id,
    'nom': nom,
    'bateauId': bateauId,
    'bateauNom': bateauNom,
    'debut': heureRfc3339(debut),
    'frequenceMinutes': frequenceMinutes,
    'personnesABord': personnesABord,
    'destination': destination,
    'personnesAlertees': personnesAlertees,
    'journal': [for (final e in journal) e.versJson()],
    'derniereAutomatique': derniereAutomatique == null
        ? null
        : heureRfc3339(derniereAutomatique!),
    'dernierEnvoi': dernierEnvoi == null ? null : heureRfc3339(dernierEnvoi!),
    'refus': refus,
  };

  static DateTime? _h(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static NavigationLocale? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    final debut = _h(j['debut']);
    if (debut == null) return null;
    return NavigationLocale(
      id: j['id'] as String,
      nom: (j['nom'] as String?) ?? '',
      bateauId: (j['bateauId'] as String?) ?? '',
      bateauNom: (j['bateauNom'] as String?) ?? '',
      debut: debut,
      frequenceMinutes: (j['frequenceMinutes'] as num?)?.toInt() ?? 60,
      personnesABord: (j['personnesABord'] as num?)?.toInt() ?? 1,
      destination: j['destination'] as String?,
      personnesAlertees: [
        for (final p in (j['personnesAlertees'] as List?) ?? const [])
          if (p is String) p,
      ],
      journal: [
        for (final e in (j['journal'] as List?) ?? const [])
          ?EvenementLocal.depuisJson(e),
      ],
      derniereAutomatique: _h(j['derniereAutomatique']),
      dernierEnvoi: _h(j['dernierEnvoi']),
      refus: j['refus'] as String?,
    );
  }

  ResumeNavigation get resume => ResumeNavigation(
    id: id,
    nom: nom,
    enCours: true,
    debut: debut,
    bateauId: bateauId,
    bateauNom: bateauNom,
  );
}

/// Démarrage refusé, avant l'envoi (quota épuisé d'après le dernier état reçu,
/// RG-ECO-04) ou par le serveur (message du serveur : quota épuisé, adresse
/// non confirmée, pas propriétaire, navigation déjà en cours…).
class RefusDemarrage implements Exception {
  const RefusDemarrage({
    this.erreur,
    this.quotaEpuise = false,
    this.disponibleLe,
  });

  final ErreurApi? erreur;
  final bool quotaEpuise;

  /// Heure à laquelle des minutes redeviennent disponibles (RG-ECO-04).
  final DateTime? disponibleLe;

  @override
  String toString() => 'RefusDemarrage(${erreur ?? 'quota'})';
}

/// Conduite de la navigation sur le téléphone, en mode réel : démarrage
/// (TODO-5.2), journal tenu sur le téléphone, envois par la file d'attente
/// (RG-COM-05) et état gardé dans la base locale (RG-NAV-12).
class ConduiteNavigation extends ChangeNotifier {
  ConduiteNavigation({
    required this.file,
    required this.base,
    required this.positions,
    required this.appareilId,
    this.origine = 'android',
    DateTime Function()? maintenant,
    this.attenteEnvoi = const Duration(seconds: 20),
  }) : _maintenant = maintenant ?? DateTime.now {
    _abonnementReussis = file.reussis.listen(_envoiReussi);
  }

  final FileAttente file;
  final BaseLocale base;
  final SourcePosition positions;
  final Future<String> Function() appareilId;

  /// `android` ou `ios` (schéma `Evenement`).
  final String origine;
  final DateTime Function() _maintenant;

  /// Attente maximale du serveur avant d'afficher le résultat d'un envoi ;
  /// passé ce délai, l'envoi reste en file et part plus tard.
  final Duration attenteEnvoi;

  static const _cle = 'navigation_locale';

  NavigationLocale? _nav;
  StreamSubscription<EnvoiReussi>? _abonnementReussis;
  bool _ferme = false;

  /// Navigation en cours sur ce téléphone, s'il y en a une.
  NavigationLocale? get enCours => _nav;

  DateTime get maintenant => _maintenant();

  void _notifier() {
    if (!_ferme) notifyListeners();
  }

  Future<void> _garder() async {
    final n = _nav;
    await base.ecrireCopie(_cle, n?.versJson(), maintenant);
  }

  /// Relit la navigation en cours gardée sur le téléphone (ouverture de
  /// l'application, RG-NAV-12).
  Future<void> charger() async {
    _nav = NavigationLocale.depuisJson((await base.lireCopie(_cle))?.valeur);
    _notifier();
  }

  /// Chronomètre du dernier envoi : remis à zéro par tout envoi de cette
  /// navigation reçu par le serveur (RG-NAV-10).
  void _envoiReussi(EnvoiReussi e) {
    final n = _nav;
    if (n == null || e.navigationId != n.id) return;
    n.dernierEnvoi = maintenant;
    unawaited(_garder());
    _notifier();
  }

  /// Démarre une navigation (RG-NAV-08) : heure de début, acquisition d'une
  /// position, envoi au serveur par la file d'attente. Lève [RefusDemarrage]
  /// si le dernier état reçu du quota dit « épuisé sans abonnement »
  /// (RG-ECO-04, RG-COM-06) ou si le serveur refuse ; sans réponse du
  /// serveur, la navigation démarre sur le téléphone et le démarrage part
  /// au retour de la connexion (RG-COM-06).
  Future<NavigationLocale> demarrer({
    required BateauNl bateau,
    required int frequenceMinutes,
    required int personnesABord,
    required List<String> personnesAlertees,
    String? destination,
    ParametresGeneraux? parametres,
    EtatQuota? quota,
  }) async {
    if (quota != null && quota.epuise && !quota.abonnementActif) {
      throw RefusDemarrage(
        quotaEpuise: true,
        disponibleLe: quota.prochainesMinutesLe,
      );
    }
    final id = file.nouvelId();
    final debut = maintenant;
    final position = await positions.positionActuelle(demander: true);
    final dest = destination?.trim();
    final contenu = <String, Object?>{
      'bateauId': bateau.id,
      'appareilId': await appareilId(),
      if (dest != null && dest.isNotEmpty) 'destination': {'texte': dest},
      'frequenceMinutes': frequenceMinutes,
      'parametres': ?parametres?.versJson(),
      'personnesABord': personnesABord,
      'personnesAlertees': personnesAlertees,
      'debut': {
        'type': 'debut',
        'heureAcquisition': heureRfc3339(debut),
        'position': ?position?.versJson(),
        'gpsDisponible': position != null,
        'origine': origine,
      },
    };
    final c = await file.demarrage(id, contenu);
    final etat = await file.etatApresPasse('demarrage:$id', attenteEnvoi);
    if (etat.refuse) {
      // Refus définitif : rien ne démarre sur le téléphone.
      await file.oublier('demarrage:$id');
      final e = etat.refus!;
      throw RefusDemarrage(
        erreur: e,
        quotaEpuise: e.code == 'quota_epuise',
        disponibleLe: e.disponibleLe,
      );
    }
    final debutEnvoye = c['debut'] as Map<String, Object?>;
    final n = NavigationLocale(
      id: id,
      // Nom généré comme le serveur (RG-NAV-17) ; remplacé par le sien à la relecture.
      nom: dest != null && dest.isNotEmpty
          ? '${bateau.nom} — $dest'
          : '${bateau.nom} — ${heureRfc3339(debut).substring(0, 16).replaceFirst('T', ' ')}',
      bateauId: bateau.id,
      bateauNom: bateau.nom,
      debut: debut,
      frequenceMinutes: frequenceMinutes,
      personnesABord: personnesABord,
      destination: dest,
      personnesAlertees: personnesAlertees,
      journal: [
        EvenementLocal(
          id: debutEnvoye['id'] as String,
          type: 'debut',
          heure: debut,
          position: position,
        ),
      ],
      dernierEnvoi: etat.recu ? maintenant : null,
    );
    _nav = n;
    await _garder();
    _notifier();
    return n;
  }

  /// Démarrage parti hors connexion puis refusé par le serveur à sa réception
  /// (adresse non confirmée, bateau d'un autre, navigation déjà en cours…) :
  /// le message du serveur est gardé et affiché sur l'écran de navigation ;
  /// la navigation reste sur le téléphone jusqu'à « Terminer la navigation »
  /// (Q-87).
  Future<void> verifierRefus() async {
    final n = _nav;
    if (n == null || n.refus != null) return;
    final etat = await file.etat('demarrage:${n.id}');
    if (!etat.refuse) return;
    final m = etat.refus!.message;
    n.refus = m.isEmpty ? etat.refus!.code : m;
    await _garder();
    _notifier();
  }

  /// Nom donné par le serveur à la navigation en cours (RG-NAV-17).
  Future<void> nommer(String nom) async {
    final n = _nav;
    if (n == null || n.nom == nom) return;
    n.nom = nom;
    await _garder();
    _notifier();
  }

  @override
  void dispose() {
    _ferme = true;
    _abonnementReussis?.cancel();
    super.dispose();
  }
}
