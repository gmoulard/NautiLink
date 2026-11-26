import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../depot/modeles.dart';

/// Circuit SMS du téléphone Android (RG-COM-01) : SMS envoyés
/// automatiquement par la carte SIM (SMS SOS et SMS de positions
/// automatiques, RG-SOS-16, RG-SMS-03) et SMS préremplis ouverts dans
/// l'application SMS du téléphone (autres SMS ordinaires et invitations,
/// RG-SMS-03). Aucun SMS sur iPhone (RG-IOS-02).

/// État d'un SMS envoyé automatiquement (schéma `StatutSms`, RG-SOS-12).
enum EtatSms { enAttente, acceptePourEnvoi, livraisonConfirmee, echec }

String etatSmsJson(EtatSms e) => switch (e) {
  EtatSms.enAttente => 'en_attente',
  EtatSms.acceptePourEnvoi => 'accepte_pour_envoi',
  EtatSms.livraisonConfirmee => 'livraison_confirmee',
  EtatSms.echec => 'echec',
};

/// Changement d'état d'un SMS envoyé par [CanalSms.envoyer].
class StatutRecu {
  const StatutRecu(this.id, this.etat);
  final String id;
  final EtatSms etat;
}

/// Envoi des SMS par la carte SIM du téléphone.
abstract class CanalSms {
  /// Vrai sur un téléphone qui envoie des SMS (Android).
  bool get disponible;

  /// Vrai quand la permission d'envoi de SMS est accordée (`SEND_SMS`).
  Future<bool> autorise();

  /// Demande la permission d'envoi de SMS (RG-AND-02) ; rend la réponse.
  Future<bool> demander();

  /// Envoie un SMS automatiquement, sans passer par l'application SMS ;
  /// les états arrivent par [statuts] avec le même [id]. Lève une erreur si
  /// l'envoi n'a pas pu être confié au téléphone.
  Future<void> envoyer(String id, String numero, String texte);

  /// États des SMS envoyés : accepté pour envoi, livraison confirmée (accusé
  /// de réception, s'il existe), échec.
  Stream<StatutRecu> get statuts;

  /// Ouvre l'application SMS préremplie (texte et destinataires). Avec
  /// [image], une photo jointe (MMS, RG-SMS-05) quand l'application SMS du
  /// téléphone l'accepte. Rend faux si rien ne s'est ouvert.
  Future<bool> ouvrirPrerempli(
    List<String> numeros,
    String texte, {
    String? image,
  });
}

/// Pas de SMS : iPhone (RG-IOS-02), Web, démonstration.
class SmsIndisponible implements CanalSms {
  const SmsIndisponible();
  @override
  bool get disponible => false;
  @override
  Future<bool> autorise() async => false;
  @override
  Future<bool> demander() async => false;
  @override
  Future<void> envoyer(String id, String numero, String texte) async =>
      throw UnsupportedError('SMS indisponibles');
  @override
  Stream<StatutRecu> get statuts => const Stream.empty();
  @override
  Future<bool> ouvrirPrerempli(
    List<String> numeros,
    String texte, {
    String? image,
  }) async => false;
}

/// SMS du téléphone Android, par le canal natif `fr.nautilink/sms`
/// (`MainActivity.kt` : `SmsManager`, accusés d'envoi et de réception).
class SmsAndroid implements CanalSms {
  SmsAndroid() {
    _canal.setMethodCallHandler((appel) async {
      if (appel.method != 'statut') return;
      final a = appel.arguments;
      if (a is! Map) return;
      final etat = switch (a['statut']) {
        'accepte_pour_envoi' => EtatSms.acceptePourEnvoi,
        'livraison_confirmee' => EtatSms.livraisonConfirmee,
        'echec' => EtatSms.echec,
        _ => null,
      };
      final id = a['id'];
      if (etat != null && id is String) _flux.add(StatutRecu(id, etat));
    });
  }

  static const _canal = MethodChannel('fr.nautilink/sms');
  final _flux = StreamController<StatutRecu>.broadcast();

  @override
  bool get disponible => true;

  @override
  Future<bool> autorise() async =>
      await _canal.invokeMethod<bool>('autorise') ?? false;

  @override
  Future<bool> demander() async =>
      await _canal.invokeMethod<bool>('demander') ?? false;

  @override
  Future<void> envoyer(String id, String numero, String texte) =>
      _canal.invokeMethod<void>('envoyer', {
        'id': id,
        'numero': numero,
        'texte': texte,
      });

  @override
  Stream<StatutRecu> get statuts => _flux.stream;

  @override
  Future<bool> ouvrirPrerempli(
    List<String> numeros,
    String texte, {
    String? image,
  }) async {
    if (image != null) {
      try {
        final ok = await _canal.invokeMethod<bool>('ouvrirMms', {
          'numeros': numeros,
          'texte': texte,
          'image': image,
        });
        if (ok == true) return true;
      } catch (e) {
        debugPrint('MMS : $e');
      }
      return false;
    }
    return ouvrirSmsPrerempli(numeros, texte);
  }
}

/// Ouverture de l'application SMS préremplie par un lien `sms:` ;
/// remplacée dans les essais.
Future<bool> Function(List<String> numeros, String texte) ouvrirSmsPrerempli =
    (numeros, texte) => launchUrl(
      Uri.parse('sms:${numeros.join(',')}?body=${Uri.encodeComponent(texte)}'),
      mode: LaunchMode.externalApplication,
    );

/// Destinataire d'un SMS : un contact (suiveur ou contact SOS), ou la copie
/// au navigateur (RG-SMS-08), sans contact.
class DestinataireSms {
  const DestinataireSms(this.numero, {this.contactId});
  final String numero;
  final String? contactId;
}

/// SMS envoyé automatiquement, suivi jusqu'à son dernier état.
class SmsSuivi {
  SmsSuivi({
    required this.id,
    required this.destinataire,
    required this.texte,
    this.rang,
  });
  final String id;
  final DestinataireSms destinataire;
  final String texte;

  /// Premier ou second SMS SOS (RG-SOS-07, RG-SOS-08).
  final int? rang;
  EtatSms etat = EtatSms.enAttente;
  int essais = 0;
  DateTime? misAJourLe;

  Map<String, Object?> versJson() => {
    'contactId': destinataire.contactId,
    'telephone': destinataire.numero,
    'rang': ?rang,
    'statut': etatSmsJson(etat),
    'essais': essais,
    if (misAJourLe != null) 'misAJourLe': heureRfc3339(misAJourLe!),
  };
}

/// Envois automatiques et leurs nouvelles tentatives (RG-SMS-07) : SMS SOS
/// retenté chaque minute jusqu'à la réussite ou l'arrêt par le navigateur ;
/// autre SMS (positions, début, notes, photos, notes vocales, fin,
/// invitations) : 3 essais, puis l'échec est affiché avec « Réessayer ».
class EnvoisSms extends ChangeNotifier {
  EnvoisSms({
    required this.canal,
    required this.nouvelId,
    DateTime Function()? maintenant,
    this.pasSos = const Duration(minutes: 1),
    this.pasPosition = const Duration(minutes: 1),
  }) : _maintenant = maintenant ?? DateTime.now {
    _abonnement = canal.statuts.listen(_statut);
  }

  final CanalSms canal;
  final String Function() nouvelId;
  final DateTime Function() _maintenant;
  final Duration pasSos;
  final Duration pasPosition;

  /// Essais d'un SMS de position automatique avant d'afficher l'échec.
  static const essaisPosition = 3;

  StreamSubscription<StatutRecu>? _abonnement;
  final _parId = <String, SmsSuivi>{};
  final _groupes = <String, List<SmsSuivi>>{};
  final _sos = <String>{};
  final _minuteries = <String, Timer>{};
  final _rappels = <String, void Function(List<SmsSuivi>)>{};

  /// SMS envoyés automatiquement, hors SOS, en échec après 3 essais
  /// (« Réessayer », RG-SMS-07, D-146).
  final List<SmsSuivi> echecsPosition = [];

  /// SMS d'un groupe (une alerte SOS, une position) dans leur dernier état.
  List<SmsSuivi> groupe(String groupeId) =>
      List.unmodifiable(_groupes[groupeId] ?? const []);

  /// Envoie automatiquement chaque texte de [textes] à chaque destinataire ;
  /// [rappel] reçoit les SMS du groupe à chaque changement d'état (statuts
  /// des SMS SOS envoyés au serveur, RG-SOS-12).
  Future<List<SmsSuivi>> envoyer(
    String groupeId,
    List<DestinataireSms> destinataires,
    List<String> textes, {
    bool sos = false,
    void Function(List<SmsSuivi>)? rappel,
  }) async {
    final liste = _groupes.putIfAbsent(groupeId, () => []);
    if (sos) _sos.add(groupeId);
    if (rappel != null) _rappels[groupeId] = rappel;
    for (var r = 0; r < textes.length; r++) {
      for (final d in destinataires) {
        final s = SmsSuivi(
          id: nouvelId(),
          destinataire: d,
          texte: textes[r],
          rang: sos ? r + 1 : null,
        );
        _parId[s.id] = s;
        liste.add(s);
        await _essayer(s);
      }
    }
    _rappeler(groupeId);
    return groupe(groupeId);
  }

  Future<void> _essayer(SmsSuivi s) async {
    s.essais++;
    s.misAJourLe = _maintenant();
    try {
      await canal.envoyer(s.id, s.destinataire.numero, s.texte);
    } catch (e) {
      debugPrint('SMS ${s.id} : $e');
      _changer(s, EtatSms.echec);
    }
  }

  void _statut(StatutRecu r) {
    final s = _parId[r.id];
    if (s == null) return;
    // Un accusé de réception ne revient pas en arrière (RG-SOS-12).
    if (s.etat == EtatSms.livraisonConfirmee) return;
    _changer(s, r.etat);
  }

  String? _groupeDe(SmsSuivi s) {
    for (final e in _groupes.entries) {
      if (e.value.contains(s)) return e.key;
    }
    return null;
  }

  void _changer(SmsSuivi s, EtatSms etat) {
    s.etat = etat;
    s.misAJourLe = _maintenant();
    final g = _groupeDe(s);
    if (etat == EtatSms.echec && g != null) {
      if (_sos.contains(g)) {
        _programmer(s, pasSos);
      } else if (s.essais < essaisPosition) {
        _programmer(s, pasPosition);
      } else if (!echecsPosition.contains(s)) {
        echecsPosition.add(s);
      }
    }
    if (g != null) _rappeler(g);
    notifyListeners();
  }

  void _programmer(SmsSuivi s, Duration pas) {
    _minuteries[s.id]?.cancel();
    _minuteries[s.id] = Timer(pas, () {
      _minuteries.remove(s.id);
      if (s.etat == EtatSms.echec) unawaited(_essayer(s));
    });
  }

  void _rappeler(String groupeId) => _rappels[groupeId]?.call(groupe(groupeId));

  /// « Réessayer » un SMS de position automatique en échec (RG-SMS-07).
  Future<void> reessayer(SmsSuivi s) async {
    echecsPosition.remove(s);
    s.essais = 0;
    notifyListeners();
    await _essayer(s);
  }

  /// Arrêt des nouvelles tentatives des SMS SOS par le navigateur (RG-SMS-07).
  void arreterSos(String groupeId) {
    for (final s in _groupes[groupeId] ?? const <SmsSuivi>[]) {
      _minuteries.remove(s.id)?.cancel();
    }
    _sos.remove(groupeId);
    notifyListeners();
  }

  /// Vrai tant que des SMS SOS du groupe sont en échec et retentés.
  bool sosRetentes(String groupeId) =>
      _sos.contains(groupeId) &&
      (_groupes[groupeId] ?? const []).any((s) => s.etat == EtatSms.echec);

  @override
  void dispose() {
    _abonnement?.cancel();
    for (final t in _minuteries.values) {
      t.cancel();
    }
    super.dispose();
  }
}
