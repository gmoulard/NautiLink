import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../depot/depot.dart';
import 'api.dart';
import 'achats.dart';
import 'base_locale.dart';
import 'compte.dart';
import 'conduite.dart';
import 'file_attente.dart';
import 'gps.dart';
import 'medias.dart';
import 'notifications.dart';
import 'sms.dart';
import 'sms_navigation.dart';
import 'stockage_session.dart';
import 'telephone.dart';

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
    DateTime Function()? horloge,
    Duration? pasVerification = const Duration(minutes: 1),
    this.medias,
    CanalSms? canalSms,
    this.telephone,
    this.achats,
    this.notifications,
    this.pageNavigation = _pageParDefaut,
    Stream<bool>? reseau,
  }) : positions = positions ?? const PositionsIndisponibles(),
       canalSms = canalSms ?? const SmsIndisponible() {
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
      maintenant: horloge,
      pasVerification: pasVerification,
    )..addListener(_notifier);
    envoisSms = EnvoisSms(canal: this.canalSms, nouvelId: this.file.nouvelId)
      ..addListener(_notifier);
    sms = SmsNavigation(
      canal: this.canalSms,
      envois: envoisSms,
      profil: () => profil,
      contacts: () => contacts,
      bateaux: () => bateaux,
      langue: () => profil?.langue ?? 'fr',
      pageNavigation: pageNavigation,
      statutsSos: this.file.statutsSms,
    );
    // SMS de position automatique (RG-SMS-03) ; navigation en cours retenue
    // pour la notification après un redémarrage (RG-NAV-12).
    conduite.surPositionAutomatique = (n, e) =>
        unawaited(sms.positionAutomatique(n, e, defaut: parametres));
    conduite.surEnCours = (v) => unawaited(session.marquerNavigationEnCours(v));
    achats?.surOuvert = () => unawaited(actualiser());
    // Jeton push renouvelé : remis au serveur.
    _jetons = notifications?.jetonsRenouveles.listen((_) {
      if (_etat == EtatSession.connecte) unawaited(associerTelephone());
    });
    // Retour du réseau : relance de la file et relecture (D-135, RG-COM-07).
    _reseau = reseau?.listen((connecte) {
      if (!connecte || _etat != EtatSession.connecte) return;
      unawaited(this.file.relancer());
      unawaited(actualiser());
    });
    // Photo ou note vocale déposée : sa copie locale n'est plus utile.
    _fichiersDeposes = this.file.reussis
        .where((e) => e.operation == 'fichier')
        .listen((e) => medias?.oublier(e.id));
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
    final api = ClientApi(base: kApiUrl, session: session);
    final p = plateformeDuTelephone();
    final push = p == null ? null : await PushFirebase.creer(ios: p == 'ios');
    return DepotReel(
      api: api,
      session: session,
      base: base,
      plateforme: plateformeDuTelephone(),
      positions: kIsWeb ? null : GpsTelephone(),
      medias: kIsWeb ? null : MediasTelephone(),
      canalSms: plateformeDuTelephone() == 'android' ? SmsAndroid() : null,
      telephone: plateformeDuTelephone() == 'android'
          ? const TelephoneAndroid()
          : null,
      notifications: push,
      achats: plateformeDuTelephone() == null
          ? null
          : AchatsMagasin(
              api: api,
              produit: kProduit,
              ios: plateformeDuTelephone() == 'ios',
            ),
      reseau: kIsWeb
          ? null
          : Connectivity().onConnectivityChanged.map(
              (r) => r.any((x) => x != ConnectivityResult.none),
            ),
    );
  }

  static String _pageParDefaut(String id) {
    final b = kApiUrl.endsWith('/api')
        ? kApiUrl.substring(0, kApiUrl.length - 4)
        : kApiUrl;
    return '$b/navigations/$id';
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

  /// Appareil photo et micro (TODO-5.4) ; vide sur le Web.
  final Medias? medias;

  /// SMS par la carte SIM (Android) ; indisponibles sur iPhone (RG-IOS-02).
  final CanalSms canalSms;
  late final EnvoisSms envoisSms;
  late final SmsNavigation sms;

  /// Notifications push du suiveur (RG-IOS-06, RG-AND-08) ; vides sans
  /// configuration Firebase.
  final NotificationsPush? notifications;
  StreamSubscription<String>? _jetons;

  /// Achat intégré de l'abonnement (TODO-5.8, TODO-10.6) ; vide sur le Web.
  final AchatsAbonnement? achats;

  /// Réglages du téléphone Android (batterie, notifications) ; vide ailleurs.
  final TelephoneAndroid? telephone;

  /// Adresse de la page d'une navigation sur la plateforme Web.
  final String Function(String navigationId) pageNavigation;
  StreamSubscription<EnvoiReussi>? _fichiersDeposes;
  StreamSubscription<bool>? _reseau;

  /// Annonces de l'administrateur, en bandeau de l'accueil (RG-ADM-06).
  List<({String id, String texte})> annonces = const [];

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

  /// Contacts reçus, avec les modifications du téléphone pas encore reçues
  /// par le serveur (RG-COM-06, D-136) : utilisables hors connexion pour le SOS.
  @override
  List<ContactNl> get contacts => compte.appliquerContacts(_contacts);
  @override
  ParametresGeneraux? get parametres => compte.appliquerParametres(_parametres);
  @override
  EtatQuota? get quota => _quota;
  @override
  List<AlerteSosResume> get alertes => _alertes;
  @override
  Envois get envois => file;

  bool _ferme = false;

  /// Contacts, invitations, accès et paramètres généraux (TODO-5.7).
  late final GestionCompte compte = GestionCompte(
    api: api,
    base: base,
    changement: () async {
      await _chargerCopies();
      _notifier();
    },
  );

  @override
  Future<void> modifierContact(String id, Map<String, Object?> champs) =>
      compte.modifierContact(id, champs);

  @override
  Future<void> modifierParametres(Map<String, Object?> champs) =>
      compte.modifierParametres(champs);

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
    final a = (await base.lireCopie('annonces'))?.valeur;
    annonces = [
      for (final x in a is List ? a : const [])
        if (x is Map && x['id'] is String && x['texte'] is String)
          (id: x['id'] as String, texte: x['texte'] as String),
    ];
  }

  @override
  Future<void> ouvrir() async {
    await compte.charger();
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
      // Modifications des contacts et des paramètres gardées sur le téléphone
      // d'abord, puis relecture (RG-CTC-03, RG-PRM-02, D-136).
      await compte.envoyer();
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
      try {
        await base.ecrireCopie(
          'annonces',
          await api.appel('GET', '/v1/annonces'),
          maintenant,
        );
      } on ErreurApi catch (e) {
        debugPrint('Annonces : $e');
      }
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
      if (r.id != n.id) continue;
      if (r.enCours) {
        await conduite.nommer(r.nom);
      } else {
        // Terminée sur un autre support ou clôturée par le serveur (D-140).
        await conduite.oublierTerminee();
      }
    }
  }

  /// Navigation en cours d'un bateau du compte que ce téléphone ne connaît
  /// pas (réinstallation, autre téléphone du compte), à reprendre ou à
  /// rejoindre (RG-NAV-33, RG-NAV-39, D-184) ; vide sinon.
  ResumeNavigation? get navigationInconnue =>
      conduite.enCours == null ? super.navigationEnCours : null;

  /// Lien de ce téléphone avec [navigationInconnue], d'après le serveur
  /// (D-184) : vrai s'il l'a démarrée (même identifiant), faux s'il l'a
  /// déjà rejointe, vide s'il ne le sait pas (identifiant changé par une
  /// réinstallation, autre téléphone) : l'application demande alors.
  Future<bool?> envoieLesPositionsAutomatiques() async {
    final r = navigationInconnue;
    if (r == null) return null;
    try {
      final d = await api.appelObjet('GET', '/v1/navigations/${r.id}');
      final moi = await session.appareilId();
      if (d['appareilId'] == moi) return true;
      final rejoints = d['telephonesRejoints'];
      if (rejoints is List && rejoints.contains(moi)) return false;
    } catch (e) {
      debugPrint('Lien du téléphone : $e');
    }
    return null;
  }

  /// « Reprendre la dernière navigation » (RG-NAV-12) : la navigation gardée
  /// sur le téléphone ; sinon celle que le serveur dit en cours, relue sur le
  /// serveur (fréquence, personnes à bord) ou, hors connexion, d'après la
  /// dernière liste reçue (D-140). Vide s'il n'y en a pas.
  /// [automatiques] faux : le téléphone la rejoint seulement, sans en
  /// envoyer les positions automatiques ni la fin (RG-NAV-39, D-184).
  Future<NavigationLocale?> reprendre({bool automatiques = true}) async {
    final locale = conduite.enCours;
    if (locale != null) return locale;
    final r = super.navigationEnCours;
    if (r == null) return null;
    Map<String, Object?> detail = const {};
    try {
      detail = await api.appelObjet('GET', '/v1/navigations/${r.id}');
    } catch (e) {
      debugPrint('Reprise : $e');
    }
    // Rejoindre, par la file d'attente : avant les événements de ce téléphone.
    if (!automatiques) await file.rejoindre(r.id);
    final dest = detail['destination'];
    await conduite.adopter(
      NavigationLocale(
        id: r.id,
        nom: r.nom,
        bateauId: r.bateauId ?? '',
        bateauNom: r.bateauNom ?? '',
        debut: r.debut,
        frequenceMinutes:
            (detail['frequenceMinutes'] as num?)?.toInt() ??
            _parametres?.frequenceParDefaut ??
            60,
        personnesABord:
            (detail['personnesABord'] as num?)?.toInt() ??
            session.dernierNombrePersonnes,
        destination: dest is Map ? dest['texte'] as String? : null,
        // Personnes alertées : tous les amis (RG-NAV-33, D-176).
        personnesAlertees: [for (final c in _contacts) c.id],
        derniereAutomatique: conduite.maintenant,
        rejointe: !automatiques,
      ),
    );
    return conduite.enCours;
  }

  /// « Terminer la navigation » (RG-NAV-13, RG-NAV-14), puis relecture.
  Future<(String, EtatEnvoi)?> terminer() async {
    final r = await conduite.terminer();
    unawaited(actualiser());
    return r;
  }

  /// Langue choisie dans les paramètres ; vide : langue du téléphone (RG-PRM-03).
  String? get langueChoisie => session.langue;

  /// Change la langue de l'application ; le compte la garde pour les SMS,
  /// les e-mails et le journal envoyés (RG-PRM-04).
  Future<void> choisirLangue(
    String? langue, {
    required String effective,
  }) async {
    await session.choisirLangue(langue);
    _notifier();
    try {
      await api.appel('PATCH', '/v1/compte', json: {'langue': effective});
      await actualiser();
    } catch (e) {
      debugPrint('Langue du compte : $e');
    }
  }

  /// Modifie le texte d'une note, d'une photo ou d'une note vocale de la
  /// navigation en cours, ou le supprime (RG-JRN-06), directement sur le
  /// serveur : l'élément doit y être arrivé. Lève [HorsConnexion] sans
  /// Internet, [ErreurApi] sur un refus.
  Future<void> changerEvenement(
    String evenementId, {
    String? texte,
    bool supprimer = false,
  }) async {
    final n = conduite.enCours;
    if (n == null) return;
    await file.relancer();
    final chemin = '/v1/navigations/${n.id}/evenements/$evenementId';
    if (supprimer) {
      await api.appel('DELETE', chemin);
    } else {
      await api.appel('PATCH', chemin, json: {'texte': texte});
    }
    await conduite.remplacerEvenement(
      evenementId,
      texte: texte,
      supprime: supprimer,
    );
  }

  /// Préférences des notifications push par type, sauf le SOS (RG-IOS-06) :
  /// `debut`, `fin`, `photo`, `positionEnRetard`.
  Future<void> modifierPush(Map<String, bool> champs) async {
    await api.appel('PATCH', '/v1/compte', json: {'push': champs});
    await actualiser();
  }

  /// Autorisation des notifications demandée à l'ouverture des navigations
  /// suivies, puis jeton remis au serveur (RG-AND-02).
  Future<void> preparerNotifications() async {
    final n = notifications;
    if (n == null) return;
    if (await n.demander()) await associerTelephone();
  }

  /// Fermeture d'une annonce par l'utilisateur (RG-ADM-06).
  Future<void> fermerAnnonce(String id) async {
    annonces = [
      for (final a in annonces)
        if (a.id != id) a,
    ];
    _notifier();
    try {
      await api.appel('POST', '/v1/annonces/$id/fermeture');
      await base.ecrireCopie('annonces', [
        for (final a in annonces) {'id': a.id, 'texte': a.texte},
      ], DateTime.now());
    } catch (e) {
      debugPrint('Fermeture de l\'annonce : $e');
    }
  }

  // ------------------------------------------------------------ navigation

  /// Bateaux proposés au démarrage et au SOS depuis l'accueil : ceux du
  /// téléphone (RG-NAV-02, RG-SOS-15) ; si le téléphone n'en a aucun, tous
  /// ceux du compte (D-141).
  Future<List<BateauNl>> bateauxDuTelephone() async {
    final id = await session.appareilId();
    final miens = _bateaux.where((b) => b.appareilAssocieId == id).toList();
    return miens.isNotEmpty ? miens : _bateaux;
  }

  /// « Envoi message – Début de navigation » (RG-NAV-08). Un bateau associé à
  /// un autre téléphone passe d'abord à celui-ci (D-132) ; sans Internet, le
  /// serveur le refusera, et le refus sera affiché (D-140).
  Future<NavigationLocale> demarrer({
    required BateauNl bateau,
    required int frequenceMinutes,
    required int personnesABord,
    required List<String> personnesAlertees,
    List<String>? personnesSms,
    String? destination,
    PositionGps? destinationPosition,
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
      personnesSms: personnesSms,
      destination: destination,
      destinationPosition: destinationPosition,
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

  /// Connexion par Google ou par Apple (RG-CPT-02, RG-CPT-11) : la première
  /// crée le compte, avec l'avertissement accepté (428 sinon, comme
  /// [connexion]).
  Future<void> connexionFournisseur(
    String fournisseur,
    String jetonIdentite, {
    String? avertissementVersion,
  }) async {
    final s = await api.appelObjet(
      'POST',
      '/v1/sessions',
      authentifie: false,
      json: {
        'fournisseur': fournisseur,
        'jetonIdentite': jetonIdentite,
        'avertissementVersion': ?avertissementVersion,
      },
    );
    await _ouvrirSession(
      s,
      _emailDuJeton(jetonIdentite) ?? '$fournisseur:compte',
    );
  }

  /// Adresse e-mail lue dans le jeton d'identité, pour reconnaître un
  /// changement de compte sur le téléphone (D-133) ; le serveur, lui,
  /// vérifie le jeton.
  static String? _emailDuJeton(String jwt) {
    try {
      final p = jwt.split('.')[1];
      final j = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(p))),
      );
      return j is Map && j['email'] is String ? j['email'] as String : null;
    } catch (_) {
      return null;
    }
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
      // Autre compte sur ce téléphone : ses copies locales s'effacent, la file reste (D-133) ;
      // ses modifications de contacts et de paramètres non envoyées aussi (D-136).
      await base.effacerCopies();
      await this.compte.charger();
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
  /// encore de téléphone (D-132).
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
          'jetonPush': ?await notifications?.jeton(),
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
    envoisSms.dispose();
    _fichiersDeposes?.cancel();
    _reseau?.cancel();
    _jetons?.cancel();
    file.fermer();
    super.dispose();
  }
}
