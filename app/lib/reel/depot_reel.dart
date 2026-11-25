import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../depot/depot.dart';
import 'api.dart';
import 'base_locale.dart';
import 'conduite.dart';
import 'file_attente.dart';
import 'gps.dart';
import 'stockage_session.dart';

/// Dépôt de la vraie application (D-127) : données relues sur le serveur,
/// gardées dans la base locale pour l'usage hors connexion (RG-COM-06),
/// envois par la file d'attente (RG-COM-05).
class DepotReel extends Depot {
  DepotReel({
    required this.api,
    required this.session,
    required this.base,
    FileAttente? file,
    this.plateforme,
    this.nomAppareil,
    this.versionApplication = '1.0.0',
    SourcePosition? positions,
  }) : positions = positions ?? const PositionsIndisponibles() {
    this.file =
        file ??
        FileAttente(base: base, api: api, appareilId: session.appareilId);
    api.surSessionPerdue = _sessionPerdue;
    conduite = ConduiteNavigation(
      file: this.file,
      base: base,
      positions: this.positions,
      appareilId: session.appareilId,
      origine: plateforme ?? 'android',
    )..addListener(_notifier);
  }

  /// Dépôt du téléphone : préférences, base SQLite (en mémoire sur le Web,
  /// où sqflite n'existe pas) et serveur de [kApiUrl].
  static Future<DepotReel> creer() async {
    final session = await StockageSession.ouvrir();
    BaseLocale base;
    try {
      base = kIsWeb ? BaseMemoire() : await BaseSqlite.ouvrir();
    } catch (_) {
      base = BaseMemoire();
    }
    return DepotReel(
      api: ClientApi(base: kApiUrl, session: session),
      session: session,
      base: base,
      plateforme: plateformeDuTelephone(),
      positions: kIsWeb ? null : GpsTelephone(),
    );
  }

  /// `android` ou `ios` (schéma `Appareil`) ; vide sur le Web, qui n'est pas un téléphone.
  static String? plateformeDuTelephone() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  final ClientApi api;
  final StockageSession session;
  final BaseLocale base;
  late final FileAttente file;

  /// Navigation en cours sur ce téléphone : démarrage, journal, envois (TODO-5.2 à TODO-5.6).
  late final ConduiteNavigation conduite;
  final String? plateforme;
  final String? nomAppareil;
  final String versionApplication;

  @override
  final SourcePosition positions;

  EtatSession _etat = EtatSession.chargement;
  bool _horsConnexion = false;
  DateTime? _actualiseLe;
  ProfilNl? _profil;
  List<ResumeNavigation> _navigations = const [];
  DateTime? _navigationsRecuesLe;
  List<BateauNl> _bateaux = const [];
  List<ContactNl> _contacts = const [];
  ParametresGeneraux? _parametres;
  EtatQuota? _quota;
  List<AlerteSosResume> _alertes = const [];

  /// Vrai quand la session a été fermée par le serveur (expirée, mot de passe changé).
  bool sessionExpiree = false;

  /// Dernière erreur de l'association du téléphone, s'il y en a une.
  Object? erreurAssociation;

  @override
  bool get demonstration => false;
  @override
  EtatSession get etatSession => _etat;
  @override
  bool get horsConnexion => _horsConnexion;
  @override
  DateTime? get actualiseLe => _actualiseLe;
  @override
  ProfilNl? get profil => _profil;
  @override
  List<ResumeNavigation> get navigations => _navigations;

  /// Navigation en cours du téléphone : celle gardée sur le téléphone, même
  /// si son démarrage attend encore dans la file (RG-NAV-12, RG-COM-06) ;
  /// sinon celle que le serveur dit en cours.
  @override
  ResumeNavigation? get navigationEnCours =>
      conduite.enCours?.resume ?? super.navigationEnCours;

  /// Heure de la dernière liste de navigations reçue (« hors connexion », RG-COM-06).
  DateTime? get navigationsRecuesLe => _navigationsRecuesLe;
  @override
  List<BateauNl> get bateaux => _bateaux;
  @override
  List<ContactNl> get contacts => _contacts;
  @override
  ParametresGeneraux? get parametres => _parametres;
  @override
  EtatQuota? get quota => _quota;
  @override
  List<AlerteSosResume> get alertes => _alertes;
  @override
  Envois get envois => file;

  bool _ferme = false;

  void _notifier() {
    if (!_ferme) notifyListeners();
  }

  void _sessionPerdue() {
    _etat = EtatSession.deconnecte;
    sessionExpiree = true;
    _notifier();
  }

  // ------------------------------------------------------------ données locales

  static List<T> _liste<T>(Object? v, T? Function(Object?) lire) =>
      v is List ? [for (final e in v) ?lire(e)] : <T>[];

  Future<void> _chargerCopies() async {
    final p = await base.lireCopie('profil');
    _profil = ProfilNl.depuisJson(p?.valeur);
    final n = await base.lireCopie('navigations');
    _navigations = _liste(n?.valeur, ResumeNavigation.depuisJson);
    _navigationsRecuesLe = n?.recueLe;
    _bateaux = _liste(
      (await base.lireCopie('bateaux'))?.valeur,
      BateauNl.depuisJson,
    );
    _contacts = _liste(
      (await base.lireCopie('contacts'))?.valeur,
      ContactNl.depuisJson,
    );
    _parametres = ParametresGeneraux.depuisJson(
      (await base.lireCopie('parametres'))?.valeur,
    );
    final q = await base.lireCopie('quota');
    _quota = EtatQuota.depuisJson(q?.valeur, recuLe: q?.recueLe);
    _alertes = _liste(
      (await base.lireCopie('alertes'))?.valeur,
      AlerteSosResume.depuisJson,
    );
    _actualiseLe = (await base.lireCopie('actualise'))?.recueLe;
  }

  @override
  Future<void> ouvrir() async {
    await _chargerCopies();
    await conduite.charger();
    _etat = session.ouverte ? EtatSession.connecte : EtatSession.deconnecte;
    _notifier();
    if (_etat == EtatSession.connecte) {
      // À l'ouverture : relecture du serveur et relance de la file (08-architecture.md §4 et §5).
      unawaited(actualiser());
      unawaited(file.relancer());
    }
  }

  // ------------------------------------------------------------ serveur → téléphone

  @override
  Future<void> actualiser() async {
    if (_etat != EtatSession.connecte) return;
    final maintenant = DateTime.now();
    try {
      final profil = await api.appelObjet('GET', '/v1/compte');
      await base.ecrireCopie('profil', profil, maintenant);

      final nav = await api.appelObjet(
        'GET',
        '/v1/navigations',
        parametres: {'role': 'navigateur'},
      );
      await base.ecrireCopie(
        'navigations',
        nav['navigations'] ?? const [],
        maintenant,
      );

      await base.ecrireCopie(
        'quota',
        await api.appel('GET', '/v1/quota'),
        maintenant,
      );

      final bateaux = await api.appel('GET', '/v1/bateaux');
      await base.ecrireCopie('bateaux', bateaux, maintenant);

      await _actualiserContacts(maintenant);
      await base.ecrireCopie(
        'parametres',
        await api.appel('GET', '/v1/parametres'),
        maintenant,
      );

      // Historique des alertes SOS de chaque bateau (RG-SOS-13).
      final alertes = <Object?>[];
      for (final b in _liste(bateaux, BateauNl.depuisJson)) {
        final l = await api.appel(
          'GET',
          '/v1/alertes-sos',
          parametres: {'bateauId': b.id},
        );
        if (l is List) alertes.addAll(l);
      }
      await base.ecrireCopie('alertes', alertes, maintenant);
      await base.ecrireCopie('actualise', null, maintenant);
      _horsConnexion = false;
    } on HorsConnexion {
      _horsConnexion = true;
    } on ErreurApi catch (e) {
      // 401 : la session perdue est déjà signalée ; autre refus : données locales gardées.
      debugPrint('Actualisation : $e');
    }
    if (_ferme) return;
    await _chargerCopies();
    await _rapprocherNavigation();
    _notifier();
  }

  /// Navigation du téléphone d'après la liste reçue : nom donné par le serveur
  /// (RG-NAV-17).
  Future<void> _rapprocherNavigation() async {
    final n = conduite.enCours;
    if (n == null) return;
    await conduite.verifierRefus();
    if (_horsConnexion) return;
    for (final r in _navigations) {
      if (r.id == n.id && r.enCours) await conduite.nommer(r.nom);
    }
  }

  // ------------------------------------------------------------ navigation

  /// Bateaux proposés au démarrage et au SOS depuis l'accueil : ceux du
  /// téléphone (RG-NAV-02, RG-SOS-15) ; si le téléphone n'en a aucun, tous
  /// ceux du compte (Q-88).
  Future<List<BateauNl>> bateauxDuTelephone() async {
    final id = await session.appareilId();
    final miens = _bateaux.where((b) => b.appareilAssocieId == id).toList();
    return miens.isNotEmpty ? miens : _bateaux;
  }

  /// « Envoi message – Début de navigation » (RG-NAV-08). Un bateau associé à
  /// un autre téléphone passe d'abord à celui-ci (Q-81) ; sans Internet, le
  /// serveur le refusera, et le refus sera affiché (Q-87).
  Future<NavigationLocale> demarrer({
    required BateauNl bateau,
    required int frequenceMinutes,
    required int personnesABord,
    required List<String> personnesAlertees,
    String? destination,
    ParametresGeneraux? parametres,
  }) async {
    final appareil = await session.appareilId();
    final q = quota;
    final refuse = q != null && q.epuise && !q.abonnementActif;
    if (bateau.appareilAssocieId != appareil && !refuse && plateforme != null) {
      try {
        await api.appel(
          'PUT',
          '/v1/bateaux/${bateau.id}/telephone',
          json: {'appareilId': appareil},
        );
      } on HorsConnexion {
        // Démarrage en file : le serveur dira si le téléphone n'est pas associé.
      }
    }
    final n = await conduite.demarrer(
      bateau: bateau,
      frequenceMinutes: frequenceMinutes,
      personnesABord: personnesABord,
      personnesAlertees: personnesAlertees,
      destination: destination,
      parametres: parametres,
      quota: quota,
    );
    await session.retenirNombrePersonnes(personnesABord);
    unawaited(actualiser());
    return n;
  }

  /// Contacts relus avec le curseur `depuis`, qui ne rend que les changements (RG-CTC-03).
  Future<void> _actualiserContacts(DateTime maintenant) async {
    final curseur =
        (await base.lireCopie('contacts.curseur'))?.valeur as String?;
    final r = await api.appelObjet(
      'GET',
      '/v1/contacts',
      parametres: {'depuis': ?curseur},
    );
    final parId = <String, Object?>{
      if (curseur != null)
        for (final c
            in ((await base.lireCopie('contacts'))?.valeur as List?) ??
                const [])
          if (c is Map && c['id'] is String) c['id'] as String: c,
    };
    for (final c in (r['contacts'] as List?) ?? const []) {
      if (c is Map && c['id'] is String) parId[c['id'] as String] = c;
    }
    for (final id in (r['supprimes'] as List?) ?? const []) {
      parId.remove(id);
    }
    await base.ecrireCopie('contacts', parId.values.toList(), maintenant);
    if (r['curseur'] is String) {
      await base.ecrireCopie('contacts.curseur', r['curseur'], maintenant);
    }
  }

  // ------------------------------------------------------------ comptes et sessions

  /// Version en vigueur de l'avertissement bêta (`GET /v1/avertissement`, RG-CPT-06).
  Future<String> versionAvertissement() async {
    final a = await api.appelObjet(
      'GET',
      '/v1/avertissement',
      authentifie: false,
    );
    return (a['version'] as String?) ?? '';
  }

  /// Connexion par e-mail et mot de passe (RG-CPT-02, RG-CPT-12). Lève
  /// [ErreurApi] (`avertissement_a_accepter`, 428, quand le texte a changé :
  /// rappeler avec [avertissementVersion]) ou [HorsConnexion].
  Future<void> connexion(
    String email,
    String motDePasse, {
    String? avertissementVersion,
  }) async {
    final s = await api.appelObjet(
      'POST',
      '/v1/sessions',
      authentifie: false,
      json: {
        'email': email.trim(),
        'motDePasse': motDePasse,
        'avertissementVersion': ?avertissementVersion,
      },
    );
    await _ouvrirSession(s, email);
  }

  /// Création du compte, avec l'acceptation de l'avertissement bêta (RG-CPT-06) ;
  /// le serveur envoie le lien de confirmation de l'adresse (RG-CPT-09).
  Future<void> creerCompte({
    required String nom,
    required String email,
    required String motDePasse,
    required String avertissementVersion,
    required String langue,
  }) async {
    final s = await api.appelObjet(
      'POST',
      '/v1/comptes',
      authentifie: false,
      json: {
        'nom': nom.trim(),
        'email': email.trim(),
        'motDePasse': motDePasse,
        'langue': langue,
        'avertissementVersion': avertissementVersion,
      },
    );
    await _ouvrirSession(s, email);
  }

  /// « Mot de passe oublié ? » (RG-CPT-10) : même réponse que l'adresse ait un compte ou non.
  Future<void> motDePasseOublie(String email) => api.appel(
    'POST',
    '/v1/compte/mot-de-passe/oubli',
    authentifie: false,
    json: {'email': email.trim()},
  );

  /// « Recevoir un nouveau lien » de confirmation de l'adresse (RG-CPT-09).
  Future<void> renvoyerLienVerification() =>
      api.appel('POST', '/v1/compte/verification/envoi');

  Future<void> _ouvrirSession(Map<String, Object?> s, String email) async {
    final compte = email.trim().toLowerCase();
    if (session.compteEmail != null && session.compteEmail != compte) {
      // Autre compte sur ce téléphone : ses copies locales s'effacent, la file reste (Q-82).
      await base.effacerCopies();
      await _chargerCopies();
    }
    await session.enregistrer(s);
    await session.retenirCompte(compte);
    sessionExpiree = false;
    _etat = EtatSession.connecte;
    _notifier();
    await associerTelephone();
    await actualiser();
    unawaited(file.relancer());
  }

  /// Association du téléphone (cahier des charges §5.1, RG-BAT-02) :
  /// enregistrement du téléphone (`PUT /v1/appareils/{id}`, identifiant tiré
  /// une fois et gardé), puis association aux bateaux du compte qui n'ont pas
  /// encore de téléphone (Q-81).
  Future<void> associerTelephone() async {
    final p = plateforme;
    if (p == null) return;
    erreurAssociation = null;
    try {
      final id = await session.appareilId();
      await api.appel(
        'PUT',
        '/v1/appareils/$id',
        json: {
          'plateforme': p,
          'nom': ?nomAppareil,
          'versionApplication': versionApplication,
        },
      );
      final bateaux = _liste(
        await api.appel('GET', '/v1/bateaux'),
        BateauNl.depuisJson,
      );
      for (final b in bateaux.where((b) => b.appareilAssocieId == null)) {
        await api.appel(
          'PUT',
          '/v1/bateaux/${b.id}/telephone',
          json: {'appareilId': id},
        );
      }
    } catch (e) {
      erreurAssociation = e;
      debugPrint('Association du téléphone : $e');
    }
  }

  @override
  Future<void> deconnecter() async {
    try {
      await api.requete('DELETE', '/v1/sessions/courante');
    } catch (_) {
      // Hors connexion : la session est oubliée sur le téléphone quand même.
    }
    await session.effacer(); // la file d'attente reste (RG-CPT-08)
    sessionExpiree = false;
    _etat = EtatSession.deconnecte;
    _notifier();
  }

  @override
  void dispose() {
    _ferme = true;
    conduite.dispose();
    file.fermer();
    super.dispose();
  }
}
