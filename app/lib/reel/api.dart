import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'stockage_session.dart';

/// Réponse du serveur : code HTTP et corps JSON décodé (vide sans corps).
class ReponseApi {
  const ReponseApi(this.statut, this.corps);
  final int statut;
  final Object? corps;

  bool get reussie => statut >= 200 && statut < 300;
}

/// Erreur rendue par le serveur : objet `Erreur` de `docs/api/openapi.yaml`
/// (`code` stable, `message` dans la langue de l'utilisateur).
class ErreurApi implements Exception {
  const ErreurApi(this.statut, this.code, this.message, {this.disponibleLe});

  factory ErreurApi.depuis(ReponseApi r) {
    final c = r.corps;
    if (c is Map) {
      return ErreurApi(
        r.statut,
        (c['code'] as String?) ?? 'erreur_interne',
        (c['message'] as String?) ?? '',
        disponibleLe: c['disponibleLe'] is String
            ? DateTime.tryParse(c['disponibleLe'] as String)
            : null,
      );
    }
    return ErreurApi(
      r.statut,
      r.statut >= 500 ? 'erreur_interne' : 'invalide',
      '',
    );
  }

  final int statut;
  final String code;
  final String message;

  /// Pour `quota_epuise` : heure à laquelle des minutes redeviennent disponibles (RG-ECO-04).
  final DateTime? disponibleLe;

  @override
  String toString() => 'ErreurApi($statut, $code, $message)';
}

/// Le serveur n'a pas répondu : pas d'Internet, serveur injoignable ou délai dépassé.
class HorsConnexion implements Exception {
  const HorsConnexion([this.cause]);
  final Object? cause;

  @override
  String toString() => 'HorsConnexion($cause)';
}

/// Client de l'API du serveur central (08-architecture.md §4).
///
/// Session de l'application mobile (RG-CPT-12, D-116) : le jeton d'accès est
/// présenté en `Authorization: Bearer` ; sur une réponse 401, la session est
/// renouvelée une fois (`POST /v1/sessions/renouvellement`) puis l'appel est
/// refait. Si le renouvellement est refusé, les jetons sont oubliés et
/// [surSessionPerdue] est appelé.
class ClientApi {
  ClientApi({
    required String base,
    required this.session,
    http.Client? client,
    this.delai = const Duration(seconds: 30),
  }) : base = base.endsWith('/') ? base.substring(0, base.length - 1) : base,
       _client = client ?? http.Client();

  /// Point d'entrée, sans `/v1` (`https://vdl.moulard.org/nautilink/api`).
  final String base;
  final StockageSession session;
  final http.Client _client;
  final Duration delai;

  /// Appelé quand la session est perdue (renouvellement refusé : session
  /// expirée, mot de passe changé, RG-CPT-08, RG-CPT-10).
  void Function()? surSessionPerdue;

  Future<bool>? _renouvellementEnCours;

  Uri adresse(String chemin, [Map<String, String>? parametres]) {
    final u = Uri.parse('$base$chemin');
    return parametres == null || parametres.isEmpty
        ? u
        : u.replace(queryParameters: {...u.queryParameters, ...parametres});
  }

  /// Appel brut : rend la réponse quel que soit son code, lève [HorsConnexion]
  /// sans réponse. `json` est encodé en JSON ; `octets` est envoyé tel quel
  /// avec `typeContenu` (fichiers).
  Future<ReponseApi> requete(
    String methode,
    String chemin, {
    Object? json,
    List<int>? octets,
    String? typeContenu,
    Map<String, String>? parametres,
    bool authentifie = true,
  }) async {
    var r = await _envoyer(
      methode,
      chemin,
      json,
      octets,
      typeContenu,
      parametres,
      authentifie,
    );
    if (r.statut == 401 && authentifie && session.jetonRenouvellement != null) {
      if (await _renouveler()) {
        r = await _envoyer(
          methode,
          chemin,
          json,
          octets,
          typeContenu,
          parametres,
          authentifie,
        );
      }
    }
    return r;
  }

  /// Appel qui lève [ErreurApi] pour toute réponse hors 2xx ; rend le corps décodé.
  Future<Object?> appel(
    String methode,
    String chemin, {
    Object? json,
    Map<String, String>? parametres,
    bool authentifie = true,
  }) async {
    final r = await requete(
      methode,
      chemin,
      json: json,
      parametres: parametres,
      authentifie: authentifie,
    );
    if (!r.reussie) throw ErreurApi.depuis(r);
    return r.corps;
  }

  Future<Map<String, Object?>> appelObjet(
    String methode,
    String chemin, {
    Object? json,
    Map<String, String>? parametres,
    bool authentifie = true,
  }) async {
    final c = await appel(
      methode,
      chemin,
      json: json,
      parametres: parametres,
      authentifie: authentifie,
    );
    return c is Map<String, Object?> ? c : <String, Object?>{};
  }

  Future<ReponseApi> _envoyer(
    String methode,
    String chemin,
    Object? json,
    List<int>? octets,
    String? typeContenu,
    Map<String, String>? parametres,
    bool authentifie,
  ) async {
    final req = http.Request(methode, adresse(chemin, parametres));
    req.headers['Accept'] = 'application/json';
    final jeton = session.jetonAcces;
    if (authentifie && jeton != null) {
      req.headers['Authorization'] = 'Bearer $jeton';
    }
    if (json != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.bodyBytes = utf8.encode(jsonEncode(json));
    } else if (octets != null) {
      req.headers['Content-Type'] = typeContenu ?? 'application/octet-stream';
      req.bodyBytes = octets;
    }
    try {
      final rep = await http.Response.fromStream(
        await _client.send(req).timeout(delai),
      ).timeout(delai);
      Object? corps;
      if (rep.bodyBytes.isNotEmpty) {
        try {
          corps = jsonDecode(utf8.decode(rep.bodyBytes));
        } on FormatException {
          corps = null; // page d'erreur d'un relais, pas du serveur NautiLink
        }
      }
      return ReponseApi(rep.statusCode, corps);
    } on http.ClientException catch (e) {
      throw HorsConnexion(e);
    } on TimeoutException catch (e) {
      throw HorsConnexion(e);
    }
  }

  /// Un seul renouvellement à la fois, partagé par les appels en cours.
  Future<bool> _renouveler() {
    final jeton = session.jetonRenouvellement;
    if (jeton == null) return Future.value(false);
    return _renouvellementEnCours ??= () async {
      try {
        final r = await _envoyer(
          'POST',
          '/v1/sessions/renouvellement',
          {'jetonRenouvellement': jeton},
          null,
          null,
          null,
          false,
        );
        if (r.statut == 200 && r.corps is Map<String, Object?>) {
          await session.enregistrer(r.corps as Map<String, Object?>);
          return true;
        }
        if (r.statut == 401) {
          await session.effacer();
          surSessionPerdue?.call();
        }
        return false;
      } finally {
        _renouvellementEnCours = null;
      }
    }();
  }
}
