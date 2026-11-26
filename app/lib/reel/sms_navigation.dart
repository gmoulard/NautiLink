import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import 'conduite.dart';
import 'sms.dart';

/// Résultat du circuit SMS d'un envoi, affiché dans la fenêtre « OK »
/// (RG-COM-03).
enum IssueSms {
  /// Pas de circuit SMS : iPhone (RG-IOS-02), Web.
  aucun,

  /// Réglages de la navigation : ce type de SMS ne part pas (RG-SMS-02).
  desactive,

  /// Aucun suiveur de la navigation avec un numéro (RG-SMS-01).
  sansDestinataire,

  /// Envoyé automatiquement, avec la permission d'envoi de SMS (RG-SMS-03, D-146).
  automatique,

  /// Envoyé automatiquement avec le lien, et MMS prérempli avec la photo
  /// ouvert en plus (RG-SMS-05).
  automatiqueEtMms,

  /// Ouvert prérempli dans l'application SMS (RG-SMS-03).
  prerempli,

  /// MMS ouvert prérempli avec la photo (RG-SMS-05).
  mms,

  /// MMS impossible : SMS avec le lien prérempli à la place (D-49).
  mmsRemplace,

  /// Sans permission d'envoi : positions automatiques au serveur seulement (D-91).
  sansPermission,

  /// L'application SMS n'a pas pu s'ouvrir.
  echec,
}

/// Ligne de résultat du circuit SMS (RG-COM-03).
String? ligneSms(AppLocalizations l, IssueSms i, {int nombre = 0}) =>
    switch (i) {
      IssueSms.aucun => null,
      IssueSms.desactive => l.smsResultOff,
      IssueSms.sansDestinataire => l.smsResultNoRecipient,
      IssueSms.automatique => l.smsResultAuto(nombre),
      IssueSms.automatiqueEtMms =>
        '${l.smsResultAuto(nombre)} · ${l.smsResultMms}',
      IssueSms.prerempli => l.smsResultPrefilled,
      IssueSms.mms => l.smsResultMms,
      IssueSms.mmsRemplace => l.smsResultMmsFailed,
      IssueSms.sansPermission => l.smsResultNoPermission,
      IssueSms.echec => l.smsResultFailed,
    };

/// Coordonnées d'une position pour un SMS.
String coordonnees(PositionGps p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

String lienCarte(PositionGps p) =>
    'https://maps.google.com/?q=${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

String _hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// SMS d'une navigation, sur Android (RG-SMS-01 à RG-SMS-09, RG-SOS-05 à
/// RG-SOS-08, RG-SOS-12, RG-SOS-16).
///
/// Textes des SMS ordinaires : Q-93 (`docs/06-questions-ouvertes.md`)
/// (proposition appliquée en attendant).
class SmsNavigation {
  SmsNavigation({
    required this.canal,
    required this.envois,
    required this.profil,
    required this.contacts,
    required this.bateaux,
    required this.langue,
    required this.pageNavigation,
    required this.statutsSos,
  });

  final CanalSms canal;
  final EnvoisSms envois;
  final ProfilNl? Function() profil;
  final List<ContactNl> Function() contacts;
  final List<BateauNl> Function() bateaux;
  final String Function() langue;

  /// Adresse de la page de la navigation sur la plateforme Web (RG-SMS-09 :
  /// le lien mène à la connexion, puis à l'élément du journal).
  final String Function(String navigationId) pageNavigation;

  /// Envoi des statuts des SMS SOS au serveur (RG-SOS-12).
  final Future<void> Function(String alerteId, List<Map<String, Object?>>)
  statutsSos;

  /// Copie de la photo pour le MMS, faite à la prise de vue : elle reste
  /// lisible par l'application SMS après le dépôt de la photo sur le serveur,
  /// qui efface l'original ; remplacée dans les essais.
  Future<String?> Function(String chemin) copierPhoto = _copierPhoto;

  static Future<String?> _copierPhoto(String chemin) async {
    try {
      final d = await getTemporaryDirectory();
      final cible =
          '${d.path}/mms-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(chemin).copy(cible);
      return cible;
    } catch (e) {
      debugPrint('Copie de la photo du MMS : $e');
      return null;
    }
  }

  AppLocalizations get _l => lookupAppLocalizations(
    Locale(
      AppLocalizations.supportedLocales.any((x) => x.languageCode == langue())
          ? langue()
          : 'fr',
    ),
  );

  bool get disponible => canal.disponible;

  /// Copie au navigateur, au numéro de son profil (RG-SMS-08).
  DestinataireSms? get _copie {
    final t = profil()?.telephone;
    return t == null || t.trim().isEmpty ? null : DestinataireSms(t.trim());
  }

  /// Suiveurs de la navigation avec un numéro, qui reçoivent les SMS
  /// (RG-SMS-01), sans ceux décochés au démarrage (RG-NAV-25).
  List<DestinataireSms> suiveurs(NavigationLocale n) => [
    for (final c in contacts())
      if (c.suiveur &&
          c.recevoirSms &&
          (c.telephone?.trim().isNotEmpty ?? false) &&
          n.personnesAlertees.contains(c.id))
        DestinataireSms(c.telephone!.trim(), contactId: c.id),
  ];

  /// Contacts SOS prévenus par SMS : ceux cochés au démarrage (RG-NAV-25),
  /// tous hors navigation ; seulement avec un numéro (RG-SOS-05).
  List<DestinataireSms> contactsSos(NavigationLocale? n) => [
    for (final c in contacts())
      if (c.contactSos &&
          (c.telephone?.trim().isNotEmpty ?? false) &&
          (n == null || n.personnesAlertees.contains(c.id)))
        DestinataireSms(c.telephone!.trim(), contactId: c.id),
  ];

  /// Clé des préférences par type (schéma `Parametres`, RG-SMS-02).
  static String? cleType(String type) => switch (type) {
    'debut' => 'debut',
    'position_automatique' => 'positionsAutomatiques',
    'position_manuelle' => 'positionsManuelles',
    'note' => 'notes',
    'photo' => 'photos',
    'note_vocale' => 'notesVocales',
    'fin' => 'fin',
    _ => null,
  };

  /// Vrai quand les paramètres de la navigation prévoient ce type de SMS.
  static bool prevu(
    NavigationLocale n,
    String type,
    ParametresGeneraux? defaut,
  ) {
    final p = n.parametres ?? defaut;
    if (p == null) return true;
    if (!p.smsActifs) return false;
    final k = cleType(type);
    return k == null || p.smsParType[k] != false;
  }

  /// Texte d'un SMS ordinaire (Q-93) : en-tête, puis position ou
  /// « GPS NON DISPONIBLE » (RG-SMS-04), note, lien de la photo ou de la
  /// note vocale (RG-SMS-05, RG-SMS-06, RG-SMS-09).
  String texte(
    NavigationLocale n,
    String type, {
    PositionGps? position,
    String? note,
    String? evenementId,
    DateTime? heure,
  }) {
    final l = _l;
    final kind = switch (type) {
      'debut' => l.smsKindStart,
      'note' => l.smsKindNote,
      'photo' => l.smsKindPhoto,
      'note_vocale' => l.smsKindVoice,
      'fin' => l.smsKindEnd,
      _ => l.smsKindPosition,
    };
    final page = pageNavigation(n.id);
    final lienEvenement = evenementId == null
        ? page
        : '$page#evenement-$evenementId';
    final avecPosition = const {
      'debut',
      'position_automatique',
      'position_manuelle',
      'fin',
    }.contains(type);
    return [
      l.smsHeader(n.bateauNom, kind, _hhmm(heure ?? DateTime.now())),
      if (type == 'debut' && (n.destination?.isNotEmpty ?? false))
        l.smsDestination(n.destination!),
      if (avecPosition)
        position == null
            ? l.smsGpsUnavailable
            : l.smsPositionLine(coordonnees(position), lienCarte(position)),
      if (note != null && note.isNotEmpty) l.smsNoteLine(note),
      if (type == 'photo') l.smsPhotoLine(lienEvenement),
      if (type == 'note_vocale') l.smsVoiceLine(lienEvenement),
      if (type == 'debut') l.smsFollowLine(page),
    ].join('\n');
  }

  /// SMS ordinaire envoyé automatiquement avec la permission d'envoi de SMS
  /// (D-146), sinon ouvert prérempli (RG-SMS-03) : début, position manuelle,
  /// note, photo (MMS si prévu, RG-SMS-05), note vocale, fin ; adressé aux
  /// suiveurs de la navigation et au navigateur (copie, RG-SMS-08).
  Future<(IssueSms, int)> ordinaire(
    NavigationLocale n,
    String type, {
    ParametresGeneraux? defaut,
    PositionGps? position,
    String? note,
    String? evenementId,
    String? photo,
  }) async {
    if (!disponible) return (IssueSms.aucun, 0);
    if (!prevu(n, type, defaut)) return (IssueSms.desactive, 0);
    final d = suiveurs(n);
    if (d.isEmpty) return (IssueSms.sansDestinataire, 0);
    final numeros = [
      for (final x in [...d, ?_copie]) x.numero,
    ];
    final t = texte(
      n,
      type,
      position: position,
      note: note,
      evenementId: evenementId,
    );
    final mms =
        type == 'photo' &&
        photo != null &&
        (n.parametres ?? defaut)?.photoEnMms == true;
    // D-146 : avec la permission, le SMS part automatiquement (3 essais puis
    // « Réessayer », RG-SMS-07) ; la photo, avec son lien (RG-SMS-05).
    if (await canal.autorise()) {
      await envois.envoyer(
        'sms:$type:${evenementId ?? n.id}',
        [...d, ?_copie],
        [t],
      );
      if (mms) {
        try {
          if (await canal.ouvrirPrerempli(numeros, t, image: photo)) {
            return (IssueSms.automatiqueEtMms, numeros.length);
          }
        } catch (e) {
          debugPrint('MMS : $e');
        }
      }
      return (IssueSms.automatique, numeros.length);
    }
    try {
      if (mms) {
        if (await canal.ouvrirPrerempli(numeros, t, image: photo)) {
          return (IssueSms.mms, numeros.length);
        }
        // MMS impossible : SMS avec le lien vers la photo hébergée (D-49).
        return await canal.ouvrirPrerempli(numeros, t)
            ? (IssueSms.mmsRemplace, numeros.length)
            : (IssueSms.echec, 0);
      }
      return await canal.ouvrirPrerempli(numeros, t)
          ? (IssueSms.prerempli, numeros.length)
          : (IssueSms.echec, 0);
    } catch (e) {
      debugPrint('SMS prérempli : $e');
      return (IssueSms.echec, 0);
    }
  }

  /// Invitation par SMS (RG-PAR-11) : envoyée automatiquement à l'invité et
  /// en copie au navigateur avec la permission d'envoi de SMS (D-146) ; sinon
  /// préremplie. Rend l'issue et le nombre de destinataires.
  Future<(IssueSms, int)> invitation(
    String invitationId,
    String numero,
    String texte, {
    String? contactId,
  }) async {
    if (!disponible) return (IssueSms.aucun, 0);
    final dests = [DestinataireSms(numero, contactId: contactId), ?_copie];
    if (await canal.autorise()) {
      await envois.envoyer('invitation:$invitationId', dests, [texte]);
      return (IssueSms.automatique, dests.length);
    }
    try {
      return await canal.ouvrirPrerempli([
            for (final x in dests) x.numero,
          ], texte)
          ? (IssueSms.prerempli, dests.length)
          : (IssueSms.echec, 0);
    } catch (e) {
      debugPrint('Invitation par SMS : $e');
      return (IssueSms.echec, 0);
    }
  }

  /// SMS de position automatique envoyé automatiquement (RG-SMS-03), avec
  /// ses nouvelles tentatives (RG-SMS-07) ; sans permission, rien (D-91).
  Future<IssueSms> positionAutomatique(
    NavigationLocale n,
    EvenementLocal e, {
    ParametresGeneraux? defaut,
  }) async {
    if (!disponible) return IssueSms.aucun;
    if (!prevu(n, 'position_automatique', defaut)) return IssueSms.desactive;
    final d = suiveurs(n);
    if (d.isEmpty) return IssueSms.sansDestinataire;
    if (!await canal.autorise()) return IssueSms.sansPermission;
    await envois.envoyer(
      'position:${e.id}',
      [...d, ?_copie],
      [texte(n, 'position_automatique', position: e.position, heure: e.heure)],
    );
    return IssueSms.automatique;
  }

  /// Second SMS SOS (RG-SOS-08) : autres informations de la fiche bateau.
  String secondSos(BateauNl? b, String nom) {
    String v(String? s) => s == null || s.trim().isEmpty ? '—' : s.trim();
    String n(double? x, String u) => x == null
        ? '—'
        : '${x.toStringAsFixed(x == x.roundToDouble() ? 0 : 1)} $u';
    return _l.sosSmsSecond(
      nom,
      v(b?.portAttache),
      v(b?.moteur),
      v(b?.autonomie),
      n(b?.capaciteCarburantLitres, 'L'),
      n(b?.vitesseNoeuds, 'nd'),
      n(b?.tirantEauMetres, 'm'),
    );
  }

  /// SMS SOS (RG-SOS-05 à RG-SOS-08, RG-SOS-16) : avec la permission, les deux
  /// SMS partent automatiquement aux contacts SOS et au navigateur (copie),
  /// retentés chaque minute, statuts envoyés au serveur (RG-SOS-12) ; sans
  /// elle, le premier et le second SMS s'ouvrent préremplis (RG-AND-04,
  /// RG-SOS-23). Rend l'issue et le nombre de destinataires.
  Future<(IssueSms, int)> sos({
    required String alerteId,
    required NavigationLocale? navigation,
    required String premier,
    required String second,
  }) async {
    if (!disponible) return (IssueSms.aucun, 0);
    final d = contactsSos(navigation);
    if (d.isEmpty) return (IssueSms.sansDestinataire, 0);
    final tous = [...d, ?_copie];
    if (await canal.autorise()) {
      await envois.envoyer(
        'sos:$alerteId',
        tous,
        [premier, second],
        sos: true,
        rappel: (liste) => unawaited(
          statutsSos(alerteId, [for (final s in liste) s.versJson()]),
        ),
      );
      return (IssueSms.automatique, tous.length);
    }
    try {
      return await canal.ouvrirPrerempli([
            for (final x in tous) x.numero,
          ], '$premier\n$second')
          ? (IssueSms.prerempli, tous.length)
          : (IssueSms.echec, 0);
    } catch (e) {
      debugPrint('SMS SOS prérempli : $e');
      return (IssueSms.echec, 0);
    }
  }
}
