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
/// (TODO-5.2), positions automatiques (TODO-5.3), journal tenu sur le
/// téléphone, envois par la file d'attente (RG-COM-05) et état gardé dans
/// la base locale (RG-NAV-12).
class ConduiteNavigation extends ChangeNotifier {
  ConduiteNavigation({
    required this.file,
    required this.base,
    required this.positions,
    required this.appareilId,
    this.origine = 'android',
    DateTime Function()? maintenant,
    this.attenteEnvoi = const Duration(seconds: 20),
    this.pasVerification = const Duration(minutes: 1),
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

  /// Intervalle de la vérification des positions automatiques dues, en plus
  /// des positions remises par le suivi ; vide : pas de minuterie (essais).
  final Duration? pasVerification;

  /// Avance tolérée sur l'heure d'une position automatique : le suivi du
  /// téléphone remet ses positions à peu près à la fréquence demandée.
  static const tolerance = Duration(minutes: 1);

  /// Âge maximal d'une position remise par le suivi pour servir de position
  /// automatique ; plus ancienne, une nouvelle acquisition est faite.
  static const fraicheur = Duration(minutes: 2);

  static const _cle = 'navigation_locale';

  NavigationLocale? _nav;
  StreamSubscription<EnvoiReussi>? _abonnementReussis;
  StreamSubscription<PositionGps>? _suivi;
  Timer? _minuterie;
  PositionGps? _derniereRecue;
  bool _acquisition = false;
  bool _ferme = false;

  /// Vrai pendant le suivi des positions automatiques.
  bool get suiviActif => _suivi != null;

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
    // Les positions automatiques reprennent à la réouverture (RG-NAV-12).
    if (_nav != null && _nav!.refus == null) _lancerAutomatiques();
  }

  // ------------------------------------------------ positions automatiques

  /// Positions automatiques (RG-GPS-01 à RG-GPS-04, RG-NAV-11) : à la
  /// fréquence de la navigation, une position est acquise et enregistrée sur
  /// le téléphone, puis envoyée par la file d'attente, dans l'ordre
  /// d'acquisition, que le serveur soit joignable ou non.
  void _lancerAutomatiques() {
    final n = _nav;
    if (n == null || _suivi != null) return;
    _suivi = positions.suivre(Duration(minutes: n.frequenceMinutes)).listen((
      p,
    ) {
      _derniereRecue = p;
      unawaited(verifierPositionAutomatique());
    });
    final pas = pasVerification;
    if (pas != null) {
      _minuterie = Timer.periodic(
        pas,
        (_) => unawaited(verifierPositionAutomatique()),
      );
    }
  }

  void _arreterAutomatiques() {
    unawaited(_suivi?.cancel());
    _suivi = null;
    _minuterie?.cancel();
    _minuterie = null;
    _derniereRecue = null;
  }

  /// Heure de la prochaine position automatique.
  DateTime? get prochaineAutomatique {
    final n = _nav;
    if (n == null) return null;
    return (n.derniereAutomatique ?? n.debut).add(
      Duration(minutes: n.frequenceMinutes),
    );
  }

  /// Enregistre une position automatique si elle est due. Position remise
  /// par le suivi si elle est récente, sinon acquisition ; sans réponse du
  /// GPS, la position automatique est enregistrée « GPS non disponible »
  /// (Q-86).
  Future<void> verifierPositionAutomatique() async {
    final n = _nav;
    final due = prochaineAutomatique;
    if (n == null || due == null || n.refus != null || _acquisition) return;
    if (maintenant.isBefore(due.subtract(tolerance))) return;
    _acquisition = true;
    try {
      var p = _derniereRecue;
      if (p == null || maintenant.difference(p.heureAcquisition) > fraicheur) {
        p = await positions.positionActuelle();
      }
      if (_nav?.id != n.id) return; // navigation terminée pendant l'acquisition
      n.derniereAutomatique = maintenant;
      _derniereRecue = null;
      await enregistrer('position_automatique', position: p, gps: true);
    } finally {
      _acquisition = false;
    }
  }

  /// Ajoute un événement au journal de la navigation en cours : enregistré
  /// sur le téléphone et mis en file (RG-COM-05) ; rend sa clé dans la file.
  Future<String?> enregistrer(
    String type, {
    PositionGps? position,
    bool gps = false,
    String? texte,
    Map<String, Object?>? fichier,
    int? dureeSecondes,
    String? id,
  }) async {
    final n = _nav;
    if (n == null) return null;
    final heure = maintenant;
    final e = await file.evenement(n.id, {
      'id': id ?? file.nouvelId(),
      'type': type,
      'heureAcquisition': heureRfc3339(heure),
      if (position != null) 'position': position.versJson(),
      if (gps) 'gpsDisponible': position != null,
      if (texte != null && texte.isNotEmpty) 'texte': texte,
      'fichier': ?fichier,
      'origine': origine,
    });
    n.journal.add(
      EvenementLocal(
        id: e['id'] as String,
        type: type,
        heure: heure,
        position: position,
        texte: texte,
        dureeSecondes: dureeSecondes,
      ),
    );
    await _garder();
    _notifier();
    return 'evenement:${e['id']}';
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
    _lancerAutomatiques(); // RG-NAV-08 : activation des positions automatiques
    return n;
  }

  // ------------------------------------------------ envois du navigateur

  Future<EtatEnvoi> _etat(String? cle) async => cle == null
      ? EtatEnvoi.enAttente
      : file.etatApresPasse(cle, attenteEnvoi);

  /// « Envoyer information position » (RG-NAV-11) : position acquise à
  /// l'écran, l'autorisation refusée est redemandée (RG-AND-03).
  Future<EtatEnvoi> positionManuelle() async {
    final p = await positions.positionActuelle(demander: true);
    return _etat(
      await enregistrer('position_manuelle', position: p, gps: true),
    );
  }

  /// « NOTE » : note écrite (RG-JRN-02).
  Future<EtatEnvoi> note(String texte) async =>
      _etat(await enregistrer('note', texte: texte.trim()));

  /// « Photo » : l'événement part avec les éléments légers, son fichier
  /// JPEG ensuite (RG-COM-05) ; 20 photos au plus par navigation, refus du
  /// serveur au-delà (RG-JRN-08).
  Future<EtatEnvoi> photo(String evenementId, String chemin, int taille) =>
      _media(evenementId, 'photo', chemin, 'image/jpeg', taille);

  /// « Vocal » : note vocale AAC (`audio/mp4`), 1 minute au plus, sans
  /// transcription (RG-JRN-04).
  Future<EtatEnvoi> noteVocale(
    String evenementId,
    String chemin,
    int taille,
    int dureeSecondes,
  ) => _media(
    evenementId,
    'note_vocale',
    chemin,
    'audio/mp4',
    taille,
    dureeSecondes: dureeSecondes.clamp(1, 60),
  );

  Future<EtatEnvoi> _media(
    String id,
    String type,
    String chemin,
    String typeMedia,
    int taille, {
    int? dureeSecondes,
  }) async {
    final cle = await enregistrer(
      type,
      id: id,
      fichier: {
        'typeMedia': typeMedia,
        'tailleOctets': taille,
        'dureeSecondes': ?dureeSecondes,
      },
      dureeSecondes: dureeSecondes,
    );
    if (cle == null) return EtatEnvoi.enAttente;
    await file.fichier(id, chemin, typeMedia);
    return _etat(cle);
  }

  /// Démarrage parti hors connexion puis refusé par le serveur à sa réception
  /// (adresse non confirmée, bateau d'un autre, navigation déjà en cours…) :
  /// le message du serveur est gardé et affiché sur l'écran de navigation ;
  /// la navigation reste sur le téléphone jusqu'à « Terminer la navigation »
  /// (Q-87).
  Future<void> verifierRefus() async {
    final n = _nav;
    if (n == null || n.refus != null) return;
    var refus = (await file.etat('demarrage:${n.id}')).refus;
    if (refus == null) {
      // Clôture automatique : les envois acquis après sont refusés ;
      // les positions automatiques s'arrêtent et le navigateur est prévenu
      // (RG-ECO-12).
      for (final e in await base.elementsMisDeCote()) {
        if (e.navigationId == n.id && e.operation == 'evenement') {
          final r = (await file.etat(e.cle)).refus;
          if (r?.code == 'navigation_cloturee') refus = r;
        }
      }
    }
    if (refus == null) return;
    n.refus = refus.message.isEmpty ? refus.code : refus.message;
    _arreterAutomatiques();
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
    _arreterAutomatiques();
    _abonnementReussis?.cancel();
    super.dispose();
  }
}
