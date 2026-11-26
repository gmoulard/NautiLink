import 'package:uuid/uuid.dart';

import '../depot/depot.dart';
import 'api.dart';
import 'base_locale.dart';

/// Modification du compte faite sur le téléphone, pas encore reçue par le
/// serveur : ajout, modification ou suppression d'un contact, modification
/// des paramètres généraux (RG-COM-06, D-136).
class ModificationCompte {
  const ModificationCompte(this.type, this.id, this.champs);

  /// `contact_ajout`, `contact_modif`, `contact_suppr` ou `parametres`.
  final String type;
  final String? id;
  final Map<String, Object?> champs;

  Map<String, Object?> versJson() => {'type': type, 'id': id, 'champs': champs};

  static ModificationCompte? depuisJson(Object? j) {
    if (j is! Map || j['type'] is! String) return null;
    final c = j['champs'];
    return ModificationCompte(
      j['type'] as String,
      j['id'] as String?,
      c is Map ? c.cast<String, Object?>() : const {},
    );
  }
}

/// Contacts, invitations, accès et paramètres généraux de la vraie
/// application (TODO-5.7, cahier des charges §5.5).
///
/// Les copies locales (`contacts`, `parametres`) gardent l'état reçu du
/// serveur ; les modifications du téléphone sont gardées à part, dans
/// l'ordre, appliquées par-dessus à l'affichage et envoyées dès que possible
/// (RG-CTC-03, RG-PRM-02, RG-COM-04, RG-COM-06). La liste des contacts reste
/// ainsi utilisable hors connexion, pour le SOS compris.
///
/// Invitations et accès demandent Internet : le serveur envoie l'e-mail, ou
/// rend le lien à transmettre (RG-PAR-04).
class GestionCompte {
  GestionCompte({
    required this.api,
    required this.base,
    required this.changement,
  });

  final ClientApi api;
  final BaseLocale base;

  /// Appelé après chaque changement des copies ou des modifications en attente.
  final Future<void> Function() changement;

  static const cleEnAttente = 'compte.enAttente';
  final _uuid = const Uuid();

  List<ModificationCompte> _enAttente = const [];

  /// Message du dernier refus du serveur pour une modification gardée
  /// (`ErreurApi.message`), affiché par l'écran des contacts.
  String? dernierRefus;

  List<ModificationCompte> get enAttente => _enAttente;

  Future<void> charger() async {
    final v = (await base.lireCopie(cleEnAttente))?.valeur;
    _enAttente = v is List
        ? [for (final e in v) ?ModificationCompte.depuisJson(e)]
        : <ModificationCompte>[];
  }

  Future<void> _garder() => base.ecrireCopie(cleEnAttente, [
    for (final m in _enAttente) m.versJson(),
  ], DateTime.now());

  // ------------------------------------------------------------ vue locale

  /// Contacts reçus du serveur, avec les modifications du téléphone par-dessus.
  List<ContactNl> appliquerContacts(List<ContactNl> recus) {
    final l = [...recus];
    for (final m in _enAttente) {
      final i = l.indexWhere((c) => c.id == m.id);
      switch (m.type) {
        case 'contact_ajout':
          if (i < 0) l.add(_contactAjoute(m));
        case 'contact_modif':
          if (i >= 0) l[i] = _contactModifie(l[i], m.champs);
        case 'contact_suppr':
          if (i >= 0) l.removeAt(i);
      }
    }
    l.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return l;
  }

  static ContactNl _contactAjoute(ModificationCompte m) {
    final c = m.champs;
    final tel = c['telephone'] as String?;
    final email = c['email'] as String?;
    final nom = (c['nom'] as String?)?.trim();
    return ContactNl(
      id: m.id!,
      nom: nom == null || nom.isEmpty ? (email ?? tel ?? '') : nom,
      telephone: tel,
      email: email,
      suiveur: c['suiveur'] != false,
      // Sans numéro, « Contact SOS » est décoché (RG-CTC-05).
      contactSos: c['contactSos'] != false && tel != null,
      perimetre: c['perimetre'] as String?,
      navigationId: c['navigationId'] as String?,
      enAttente: true,
    );
  }

  static ContactNl _contactModifie(ContactNl k, Map<String, Object?> c) {
    final tel = c.containsKey('telephone')
        ? c['telephone'] as String?
        : k.telephone;
    final suiveur = c['suiveur'] is bool ? c['suiveur'] as bool : k.suiveur;
    return ContactNl(
      id: k.id,
      nom: c['nom'] is String ? c['nom'] as String : k.nom,
      telephone: tel,
      email: c.containsKey('email') ? c['email'] as String? : k.email,
      suiveur: suiveur,
      contactSos:
          (c['contactSos'] is bool ? c['contactSos'] as bool : k.contactSos) &&
          tel != null,
      perimetre: c.containsKey('perimetre')
          ? c['perimetre'] as String?
          : k.perimetre,
      navigationId: c.containsKey('navigationId')
          ? c['navigationId'] as String?
          : k.navigationId,
      etatInvitation: suiveur ? k.etatInvitation : 'aucune',
      utilisateurId: suiveur ? k.utilisateurId : null,
      enAttente: true,
    );
  }

  /// Paramètres reçus du serveur, avec les modifications du téléphone par-dessus.
  ParametresGeneraux? appliquerParametres(ParametresGeneraux? recus) {
    var p = recus;
    for (final m in _enAttente.where((m) => m.type == 'parametres')) {
      final base = p ?? ParametresGeneraux.depuisJson(const {})!;
      final types = {...base.smsParType};
      final t = m.champs['smsParType'];
      if (t is Map) {
        t.forEach((k, v) {
          if (k is String && v is bool) types[k] = v;
        });
      }
      p = ParametresGeneraux(
        smsActifs: m.champs['smsActifs'] is bool
            ? m.champs['smsActifs'] as bool
            : base.smsActifs,
        smsParType: types,
        photoEnMms: m.champs['photoEnMms'] is bool
            ? m.champs['photoEnMms'] as bool
            : base.photoEnMms,
        frequenceParDefaut: m.champs['frequenceParDefaut'] is int
            ? m.champs['frequenceParDefaut'] as int
            : base.frequenceParDefaut,
      );
    }
    return p;
  }

  // ------------------------------------------------------------ modifications

  Future<void> _ajouter(ModificationCompte m) async {
    _enAttente = [..._enAttente, m];
    await _garder();
    await changement();
    await envoyerSansErreur();
  }

  /// Ajout d'un contact (RG-CTC-01, RG-CTC-02), identifiant tiré par le
  /// téléphone pour un ajout hors connexion sans doublon. « Suiveur » coché
  /// demande le périmètre et envoie l'invitation au retour (RG-CTC-04).
  Future<String> ajouterContact({
    required String nom,
    String? telephone,
    String? email,
    bool suiveur = true,
    bool contactSos = true,
    String? perimetre,
    String? navigationId,
    String? id,
  }) async {
    id ??= _uuid.v4();
    String? texte(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    await _ajouter(
      ModificationCompte('contact_ajout', id, {
        'id': id,
        'nom': nom.trim(),
        'telephone': texte(telephone),
        'email': texte(email),
        'suiveur': suiveur,
        'contactSos': contactSos && texte(telephone) != null,
        if (suiveur) 'perimetre': perimetre,
        if (suiveur && perimetre == 'navigation') 'navigationId': navigationId,
      }),
    );
    return id;
  }

  Future<void> modifierContact(String id, Map<String, Object?> champs) =>
      _ajouter(ModificationCompte('contact_modif', id, champs));

  /// Suppression d'un contact, qui retire aussi ses accès (RG-CTC-02, RG-PAR-06).
  Future<void> supprimerContact(String id) =>
      _ajouter(ModificationCompte('contact_suppr', id, const {}));

  Future<void> modifierParametres(Map<String, Object?> champs) =>
      _ajouter(ModificationCompte('parametres', null, champs));

  // ------------------------------------------------------------ envoi

  bool _envoiEnCours = false;

  /// Envoie les modifications gardées, dans l'ordre. Lève [HorsConnexion] si
  /// le serveur ne répond pas ; une erreur 5xx arrête la passe (gardée pour la
  /// suivante) ; un autre refus retire la modification et garde son message
  /// dans [dernierRefus] (D-136).
  Future<void> envoyer() async {
    if (_envoiEnCours) return;
    _envoiEnCours = true;
    try {
      while (_enAttente.isNotEmpty) {
        final m = _enAttente.first;
        try {
          await _envoyerUne(m);
        } on ErreurApi catch (e) {
          if (e.statut >= 500 || e.statut == 401) return;
          dernierRefus = e.message.isEmpty ? e.code : e.message;
        }
        _enAttente = _enAttente.skip(1).toList();
        await _garder();
        await changement();
      }
    } finally {
      _envoiEnCours = false;
    }
  }

  /// Comme [envoyer], sans lever d'erreur hors connexion.
  Future<void> envoyerSansErreur() async {
    try {
      await envoyer();
    } on HorsConnexion {
      // Gardé pour le retour de la connexion (RG-COM-06).
    }
  }

  Future<void> _envoyerUne(ModificationCompte m) async {
    switch (m.type) {
      case 'contact_ajout':
        Object? r;
        try {
          r = await api.appel('POST', '/v1/contacts', json: m.champs);
        } on ErreurApi catch (e) {
          // Adresse du navigateur non confirmée : l'invitation est refusée,
          // le contact est gardé sans « Suiveur » (RG-CPT-09, D-136).
          if (e.code != 'email_non_verifie' || m.champs['suiveur'] != true) {
            rethrow;
          }
          dernierRefus = e.message;
          r = await api.appel(
            'POST',
            '/v1/contacts',
            json: {...m.champs, 'suiveur': false}
              ..remove('perimetre')
              ..remove('navigationId'),
          );
        }
        await _ecrireContact(r);
      case 'contact_modif':
        try {
          await _ecrireContact(
            await api.appel('PATCH', '/v1/contacts/${m.id}', json: m.champs),
          );
        } on ErreurApi catch (e) {
          if (e.statut != 404) rethrow; // supprimé entre-temps sur le Web
        }
      case 'contact_suppr':
        try {
          await api.appel('DELETE', '/v1/contacts/${m.id}');
        } on ErreurApi catch (e) {
          if (e.statut != 404) rethrow;
        }
        await _retirerContact(m.id!);
      case 'parametres':
        final r = await api.appel('PATCH', '/v1/parametres', json: m.champs);
        if (r is Map) {
          await base.ecrireCopie('parametres', r, DateTime.now());
        }
    }
  }

  Future<List<Object?>> _copieContacts() async => [
    ...((await base.lireCopie('contacts'))?.valeur as List?) ?? const [],
  ];

  /// Réponse du serveur pour un contact : remplace sa copie locale.
  Future<void> _ecrireContact(Object? r) async {
    if (r is! Map || r['id'] is! String) return;
    final l = await _copieContacts();
    final i = l.indexWhere((c) => c is Map && c['id'] == r['id']);
    if (i >= 0) {
      l[i] = r;
    } else {
      l.add(r);
    }
    await base.ecrireCopie('contacts', l, DateTime.now());
  }

  Future<void> _retirerContact(String id) async {
    final l = await _copieContacts()
      ..removeWhere((c) => c is Map && c['id'] == id);
    await base.ecrireCopie('contacts', l, DateTime.now());
  }

  // ------------------------------------------------------------ en ligne seulement

  /// Invitations envoyées par le navigateur, la plus récente d'abord (RG-PAR-05).
  Future<List<InvitationNl>> invitations() async {
    final r = await api.appel('GET', '/v1/invitations');
    return r is List
        ? [for (final i in r) ?InvitationNl.depuisJson(i)]
        : const [];
  }

  /// Invite un contact par e-mail ou par téléphone avec un périmètre
  /// (RG-PAR-02 à RG-PAR-04) ; une nouvelle invitation annule celle en
  /// attente. Par téléphone, le serveur rend le lien à transmettre.
  Future<InvitationNl> inviter({
    required String contactId,
    required String canal,
    required String perimetre,
    String? navigationId,
  }) async {
    await envoyer(); // le contact doit être connu du serveur
    final r = await api.appel(
      'POST',
      '/v1/invitations',
      json: {
        'contactId': contactId,
        'canal': canal,
        'perimetre': perimetre,
        if (perimetre == 'navigation') 'navigationId': navigationId,
      },
    );
    await _relireContacts();
    return InvitationNl.depuisJson(r)!;
  }

  /// Annule une invitation pas encore acceptée (RG-PAR-05).
  Future<void> annulerInvitation(String id) async {
    await api.appel('DELETE', '/v1/invitations/$id');
    await _relireContacts();
  }

  /// Accès donnés par le navigateur à ses suiveurs (RG-PAR-02).
  Future<List<AccesNl>> accesDonnes() async {
    final r = await api.appel(
      'GET',
      '/v1/acces',
      parametres: {'role': 'navigateur'},
    );
    return r is List ? [for (final a in r) ?AccesNl.depuisJson(a)] : const [];
  }

  /// Change le périmètre d'un accès, à tout moment (RG-PAR-02, D-04).
  Future<void> changerPerimetre(
    String accesId,
    String perimetre, {
    String? navigationId,
  }) async {
    await api.appel(
      'PATCH',
      '/v1/acces/$accesId',
      json: {
        'perimetre': perimetre,
        if (perimetre == 'navigation') 'navigationId': navigationId,
      },
    );
    await _relireContacts();
  }

  /// Retire le suiveur de toutes les navigations présentes et futures, avec
  /// effet immédiat ; son contact n'est plus « Suiveur » (RG-PAR-06, RG-CTC-04).
  Future<void> retirerAcces(String accesId) async {
    await api.appel('DELETE', '/v1/acces/$accesId');
    await _relireContacts();
  }

  /// Relit toute la liste des contacts après une invitation ou un accès changé.
  Future<void> _relireContacts() async {
    final r = await api.appelObjet('GET', '/v1/contacts');
    final maintenant = DateTime.now();
    await base.ecrireCopie('contacts', r['contacts'] ?? const [], maintenant);
    if (r['curseur'] is String) {
      await base.ecrireCopie('contacts.curseur', r['curseur'], maintenant);
    }
    await changement();
  }

  /// Alertes SOS de ce téléphone encore dans la file d'attente, montrées dans
  /// l'historique hors connexion (RG-COM-06).
  Future<List<AlerteSosResume>> alertesEnAttente() async => [
    for (final e in await base.elementsAEnvoyer())
      if (e.operation == 'alerte_sos')
        ?AlerteSosResume.depuisJson(e.contenu, enAttente: true),
  ];
}
