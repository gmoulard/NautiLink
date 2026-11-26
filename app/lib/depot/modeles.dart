/// Données échangées avec le serveur, dans les formats de `docs/api/openapi.yaml`
/// (champs en français, heures RFC 3339, durées en minutes, distances en mètres).
/// Les mêmes classes servent à la démonstration, remplies depuis `lib/data.dart`.
library;

DateTime? _heure(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Heure au format RFC 3339 avec décalage horaire (08-architecture.md §4).
String heureRfc3339(DateTime t) {
  final l = t.toLocal();
  String d2(int n) => n.toString().padLeft(2, '0');
  final o = l.timeZoneOffset;
  final signe = o.isNegative ? '-' : '+';
  final oh = d2(o.inHours.abs());
  final om = d2(o.inMinutes.abs().remainder(60));
  return '${l.year.toString().padLeft(4, '0')}-${d2(l.month)}-${d2(l.day)}'
      'T${d2(l.hour)}:${d2(l.minute)}:${d2(l.second)}$signe$oh:$om';
}

/// Position GPS (schéma `Position`) : degrés décimaux WGS 84.
class PositionGps {
  const PositionGps({
    required this.latitude,
    required this.longitude,
    required this.heureAcquisition,
    this.precisionMetres,
  });
  final double latitude;
  final double longitude;
  final DateTime heureAcquisition;
  final double? precisionMetres;

  Map<String, Object?> versJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (precisionMetres != null) 'precisionMetres': precisionMetres,
    'heureAcquisition': heureRfc3339(heureAcquisition),
  };

  static PositionGps? depuisJson(Object? j) {
    if (j is! Map) return null;
    final la = j['latitude'], lo = j['longitude'];
    final h = _heure(j['heureAcquisition']);
    if (la is! num || lo is! num || h == null) return null;
    return PositionGps(
      latitude: la.toDouble(),
      longitude: lo.toDouble(),
      heureAcquisition: h,
      precisionMetres: (j['precisionMetres'] as num?)?.toDouble(),
    );
  }
}

/// Résumé d'une navigation (schéma `ResumeNavigation`).
class ResumeNavigation {
  const ResumeNavigation({
    required this.id,
    required this.nom,
    required this.enCours,
    required this.debut,
    this.fin,
    this.bateauId,
    this.bateauNom,
    this.commeSuiveur = false,
    this.dureeMinutes,
    this.distanceMetres,
  });
  final String id;
  final String nom;
  final bool enCours;
  final DateTime debut;
  final DateTime? fin;
  final String? bateauId;
  final String? bateauNom;
  final bool commeSuiveur;
  final int? dureeMinutes;
  final double? distanceMetres;

  static ResumeNavigation? depuisJson(Object? j) {
    if (j is! Map) return null;
    final debut = _heure(j['debut']);
    if (j['id'] is! String || debut == null) return null;
    final bateau = j['bateau'];
    return ResumeNavigation(
      id: j['id'] as String,
      nom: (j['nom'] as String?) ?? '',
      enCours: j['etat'] == 'en_cours',
      debut: debut,
      fin: _heure(j['fin']),
      bateauId: bateau is Map ? bateau['id'] as String? : null,
      bateauNom: bateau is Map ? bateau['nom'] as String? : null,
      commeSuiveur: j['role'] == 'suiveur',
      dureeMinutes: (j['dureeMinutes'] as num?)?.toInt(),
      distanceMetres: (j['distanceMetres'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'nom': nom,
    'etat': enCours ? 'en_cours' : 'terminee',
    'debut': heureRfc3339(debut),
    'fin': fin == null ? null : heureRfc3339(fin!),
    'bateau': {'id': bateauId, 'nom': bateauNom},
    'role': commeSuiveur ? 'suiveur' : 'navigateur',
    'dureeMinutes': dureeMinutes,
    'distanceMetres': distanceMetres,
  };
}

/// Bateau du compte (schéma `Bateau`, champs utiles au téléphone).
class BateauNl {
  const BateauNl({
    required this.id,
    required this.nom,
    required this.type,
    this.appareilAssocieId,
    this.longueurMetres,
    this.immatriculation,
  });
  final String id;
  final String nom;
  final String type; // voilier ou moteur
  final String? appareilAssocieId; // RG-BAT-02

  /// Repris dans le premier SMS SOS (RG-SOS-07).
  final double? longueurMetres;
  final String? immatriculation;

  static BateauNl? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    return BateauNl(
      id: j['id'] as String,
      nom: (j['nom'] as String?) ?? '',
      type: (j['type'] as String?) ?? 'voilier',
      appareilAssocieId: j['appareilAssocieId'] as String?,
      longueurMetres: (j['longueurMetres'] as num?)?.toDouble(),
      immatriculation: j['immatriculation'] as String?,
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'nom': nom,
    'type': type,
    'appareilAssocieId': appareilAssocieId,
    'longueurMetres': ?longueurMetres,
    'immatriculation': ?immatriculation,
  };
}

/// Contact du navigateur (schéma `Contact`, RG-CTC-01).
class ContactNl {
  const ContactNl({
    required this.id,
    required this.nom,
    this.telephone,
    this.email,
    this.suiveur = true,
    this.contactSos = true,
    this.perimetre,
    this.navigationId,
    this.etatInvitation = 'aucune',
    this.utilisateurId,
    this.enAttente = false,
  });
  final String id;
  final String nom;
  final String? telephone;
  final String? email;
  final bool suiveur;
  final bool contactSos;

  /// Périmètre de l'accès : `navigation` ou `navigateur` (RG-PAR-02).
  final String? perimetre;
  final String? navigationId;

  /// État de la dernière invitation : aucune, envoyee, acceptee, annulee.
  final String etatInvitation;

  /// Compte du suiveur, une fois l'invitation acceptée.
  final String? utilisateurId;

  /// Modification faite sur le téléphone, pas encore reçue par le serveur
  /// (RG-COM-06, D-136).
  final bool enAttente;

  static ContactNl? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    return ContactNl(
      id: j['id'] as String,
      nom: (j['nom'] as String?) ?? '',
      telephone: j['telephone'] as String?,
      email: j['email'] as String?,
      suiveur: j['suiveur'] != false,
      contactSos: j['contactSos'] != false,
      perimetre: j['perimetre'] as String?,
      navigationId: j['navigationId'] as String?,
      etatInvitation: (j['etatInvitation'] as String?) ?? 'aucune',
      utilisateurId: j['utilisateurId'] as String?,
      enAttente: j['enAttente'] == true,
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'nom': nom,
    'telephone': telephone,
    'email': email,
    'suiveur': suiveur,
    'contactSos': contactSos,
    'perimetre': perimetre,
    'navigationId': navigationId,
    'etatInvitation': etatInvitation,
    'utilisateurId': utilisateurId,
    if (enAttente) 'enAttente': true,
  };
}

/// Invitation envoyée par le navigateur (schéma `Invitation`, RG-PAR-03 à RG-PAR-05).
class InvitationNl {
  const InvitationNl({
    required this.id,
    required this.canal,
    required this.perimetre,
    required this.lien,
    required this.etat,
    this.contactId,
    this.email,
    this.telephone,
    this.navigationId,
    this.creeeLe,
  });
  final String id;
  final String canal; // email ou telephone
  final String perimetre;
  final String lien;
  final String etat; // envoyee, acceptee, annulee
  final String? contactId;
  final String? email;
  final String? telephone;
  final String? navigationId;
  final DateTime? creeeLe;

  static InvitationNl? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    return InvitationNl(
      id: j['id'] as String,
      canal: (j['canal'] as String?) ?? 'email',
      perimetre: (j['perimetre'] as String?) ?? 'navigateur',
      lien: (j['lien'] as String?) ?? '',
      etat: (j['etat'] as String?) ?? 'envoyee',
      contactId: j['contactId'] as String?,
      email: j['email'] as String?,
      telephone: j['telephone'] as String?,
      navigationId: j['navigationId'] as String?,
      creeeLe: _heure(j['creeeLe']),
    );
  }
}

/// Accès donné à un suiveur (schéma `Acces`, RG-PAR-02).
class AccesNl {
  const AccesNl({
    required this.id,
    required this.suiveurId,
    required this.suiveurNom,
    required this.perimetre,
    this.suiveurEmail,
    this.navigationId,
    this.accordeLe,
  });
  final String id;
  final String suiveurId;
  final String suiveurNom;
  final String? suiveurEmail;
  final String perimetre;
  final String? navigationId;
  final DateTime? accordeLe;

  static AccesNl? depuisJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    final s = j['suiveur'];
    return AccesNl(
      id: j['id'] as String,
      suiveurId: s is Map ? (s['id'] as String?) ?? '' : '',
      suiveurNom: s is Map ? (s['nom'] as String?) ?? '' : '',
      suiveurEmail: s is Map ? s['email'] as String? : null,
      perimetre: (j['perimetre'] as String?) ?? 'navigateur',
      navigationId: j['navigationId'] as String?,
      accordeLe: _heure(j['accordeLe']),
    );
  }
}

/// Paramètres généraux (schéma `Parametres`, RG-PRM-01, RG-SMS-02).
class ParametresGeneraux {
  const ParametresGeneraux({
    required this.smsActifs,
    required this.smsParType,
    required this.photoEnMms,
    required this.frequenceParDefaut,
  });
  final bool smsActifs;

  /// Clés de `smsParType` : debut, positionsAutomatiques, positionsManuelles,
  /// notes, photos, notesVocales, fin.
  final Map<String, bool> smsParType;
  final bool photoEnMms;
  final int frequenceParDefaut;

  static ParametresGeneraux? depuisJson(Object? j) {
    if (j is! Map) return null;
    final types = <String, bool>{};
    final t = j['smsParType'];
    if (t is Map) {
      t.forEach((k, v) {
        if (k is String && v is bool) types[k] = v;
      });
    }
    return ParametresGeneraux(
      smsActifs: j['smsActifs'] != false,
      smsParType: types,
      photoEnMms: j['photoEnMms'] == true,
      frequenceParDefaut: (j['frequenceParDefaut'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, Object?> versJson() => {
    'smsActifs': smsActifs,
    'smsParType': smsParType,
    'photoEnMms': photoEnMms,
    'frequenceParDefaut': frequenceParDefaut,
  };
}

/// État du quota calculé par le serveur (schéma `Quota`, RG-ECO-01 à RG-ECO-09).
class EtatQuota {
  const EtatQuota({
    required this.consommeMinutes,
    required this.disponibleMinutes,
    required this.epuise,
    this.abonnementActif = false,
    this.prochainesMinutes,
    this.prochainesMinutesLe,
    this.recuLe,
  });
  final int consommeMinutes;
  final int disponibleMinutes;
  final bool epuise;
  final bool abonnementActif;
  final int? prochainesMinutes;
  final DateTime? prochainesMinutesLe;

  /// Heure du dernier état reçu, affichée hors connexion (RG-COM-06) ;
  /// vide en démonstration.
  final DateTime? recuLe;

  static EtatQuota? depuisJson(Object? j, {DateTime? recuLe}) {
    if (j is! Map) return null;
    final p = j['prochainesMinutes'];
    final premiere = p is List && p.isNotEmpty && p.first is Map
        ? p.first as Map
        : null;
    final ab = j['abonnement'];
    return EtatQuota(
      consommeMinutes: (j['consommeMinutes'] as num?)?.toInt() ?? 0,
      disponibleMinutes: (j['disponibleMinutes'] as num?)?.toInt() ?? 0,
      epuise: j['epuise'] == true,
      abonnementActif: ab is Map && ab['actif'] == true,
      prochainesMinutes: (premiere?['minutes'] as num?)?.toInt(),
      prochainesMinutesLe: _heure(premiere?['disponiblesLe']),
      recuLe: recuLe,
    );
  }
}

/// Statut d'un SMS SOS (schéma `StatutSms`, RG-SOS-12).
class StatutSmsNl {
  const StatutSmsNl({
    required this.telephone,
    required this.statut,
    this.contactId,
    this.rang,
  });
  final String telephone;

  /// en_attente, accepte_pour_envoi, livraison_confirmee ou echec.
  final String statut;
  final String? contactId;
  final int? rang;

  static StatutSmsNl? depuisJson(Object? j) {
    if (j is! Map) return null;
    return StatutSmsNl(
      telephone: (j['telephone'] as String?) ?? '',
      statut: (j['statut'] as String?) ?? 'en_attente',
      contactId: j['contactId'] as String?,
      rang: (j['rang'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> versJson() => {
    'telephone': telephone,
    'statut': statut,
    'contactId': contactId,
    'rang': rang,
  };
}

/// Alerte SOS de l'historique (schéma `AlerteSos`, RG-SOS-13).
class AlerteSosResume {
  const AlerteSosResume({
    required this.id,
    required this.bateauId,
    required this.heureDeclenchement,
    this.navigationId,
    this.problemeRencontre,
    this.position,
    this.naturePosition,
    this.sms = const [],
    this.emailsEnvoyesA = const [],
    this.enAttente = false,
  });
  final String id;
  final String bateauId;
  final DateTime heureDeclenchement;
  final String? navigationId;
  final String? problemeRencontre;
  final PositionGps? position;

  /// actuelle, derniere_connue ou aucune (RG-SOS-09 à RG-SOS-11).
  final String? naturePosition;
  final List<StatutSmsNl> sms;
  final List<String> emailsEnvoyesA;

  /// Alerte de ce téléphone encore dans la file d'attente (RG-COM-06).
  final bool enAttente;

  static AlerteSosResume? depuisJson(Object? j, {bool enAttente = false}) {
    if (j is! Map) return null;
    final h = _heure(j['heureDeclenchement']);
    if (j['id'] is! String || h == null) return null;
    final sms = j['sms'];
    final emails = j['emailsEnvoyesA'];
    return AlerteSosResume(
      id: j['id'] as String,
      bateauId: (j['bateauId'] as String?) ?? '',
      heureDeclenchement: h,
      navigationId: j['navigationId'] as String?,
      problemeRencontre: j['problemeRencontre'] as String?,
      position: PositionGps.depuisJson(j['position']),
      naturePosition: j['naturePosition'] as String?,
      sms: sms is List
          ? [for (final s in sms) ?StatutSmsNl.depuisJson(s)]
          : const [],
      emailsEnvoyesA: emails is List
          ? emails.whereType<String>().toList()
          : const [],
      enAttente: enAttente,
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'bateauId': bateauId,
    'heureDeclenchement': heureRfc3339(heureDeclenchement),
    'navigationId': navigationId,
    'problemeRencontre': problemeRencontre,
    if (position != null) 'position': position!.versJson(),
    'naturePosition': naturePosition,
    'sms': [for (final s in sms) s.versJson()],
    'emailsEnvoyesA': emailsEnvoyesA,
  };
}

/// Profil de l'utilisateur connecté (schéma `Profil`, champs utiles au téléphone).
class ProfilNl {
  const ProfilNl({
    required this.email,
    required this.nom,
    required this.emailVerifie,
    this.telephone,
  });
  final String email;
  final String nom;
  final bool emailVerifie; // RG-CPT-09

  /// Numéro du navigateur, pour la copie des SMS (RG-SMS-08).
  final String? telephone;

  static ProfilNl? depuisJson(Object? j) {
    if (j is! Map) return null;
    return ProfilNl(
      email: (j['email'] as String?) ?? '',
      nom: (j['nom'] as String?) ?? '',
      emailVerifie: j['emailVerifie'] == true,
      telephone: j['telephone'] as String?,
    );
  }
}
