import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Jetons de la session et identifiant du téléphone, gardés dans les
/// préférences de l'application, sans chiffrement matériel (RG-CPT-12, D-116).
class StockageSession {
  StockageSession(this._p);

  static Future<StockageSession> ouvrir() async =>
      StockageSession(await SharedPreferences.getInstance());

  final SharedPreferences _p;

  static const _acces = 'nautilink.jetonAcces';
  static const _renouvellement = 'nautilink.jetonRenouvellement';
  static const _expire = 'nautilink.sessionExpireLe';
  static const _appareil = 'nautilink.appareilId';
  static const _compte = 'nautilink.compteEmail';

  String? get jetonAcces => _p.getString(_acces);
  String? get jetonRenouvellement => _p.getString(_renouvellement);
  bool get ouverte => jetonAcces != null && jetonRenouvellement != null;

  /// Adresse du dernier compte connecté sur ce téléphone (changement de compte : D-133).
  String? get compteEmail => _p.getString(_compte);
  Future<void> retenirCompte(String email) => _p.setString(_compte, email);

  /// Enregistre une réponse `Session` du serveur.
  Future<void> enregistrer(Map<String, Object?> session) async {
    final a = session['jetonAcces'], r = session['jetonRenouvellement'];
    if (a is! String || r is! String) {
      throw const FormatException('Session sans jetons');
    }
    await _p.setString(_acces, a);
    await _p.setString(_renouvellement, r);
    final e = session['expireLe'];
    if (e is String) await _p.setString(_expire, e);
  }

  /// Oublie les jetons ; l'identifiant du téléphone et la file d'attente restent (RG-CPT-08).
  Future<void> effacer() async {
    await _p.remove(_acces);
    await _p.remove(_renouvellement);
    await _p.remove(_expire);
  }

  static const _rappel = 'nautilink.rappelPremiereNavigationVu';
  static const _personnes = 'nautilink.personnesABord';

  /// Rappel affiché avant la première navigation sur ce téléphone (RG-NAV-23).
  bool get rappelPremiereNavigationVu => _p.getBool(_rappel) ?? false;
  Future<void> voirRappelPremiereNavigation() => _p.setBool(_rappel, true);

  /// Nombre de personnes à bord de la navigation précédente, 1 la première
  /// fois (RG-NAV-27).
  int get dernierNombrePersonnes => _p.getInt(_personnes) ?? 1;
  Future<void> retenirNombrePersonnes(int n) => _p.setInt(_personnes, n);

  /// Navigation en cours sur ce téléphone, lue après un redémarrage par
  /// `RedemarrageRecepteur.kt` (« flutter.navigation_en_cours », RG-NAV-12).
  static const _navigationEnCours = 'navigation_en_cours';
  bool get navigationEnCours => _p.getBool(_navigationEnCours) ?? false;
  Future<void> marquerNavigationEnCours(bool v) async {
    if (navigationEnCours != v) await _p.setBool(_navigationEnCours, v);
  }

  /// Exclusion de l'optimisation de la batterie déjà proposée, au premier
  /// démarrage d'une navigation (RG-GPS-05).
  static const _batterie = 'nautilink.batterieProposee';
  bool get batterieProposee => _p.getBool(_batterie) ?? false;
  Future<void> proposerBatterie() => _p.setBool(_batterie, true);

  /// Langue choisie dans les paramètres ; vide : langue du téléphone (RG-PRM-03).
  static const _langue = 'nautilink.langue';
  String? get langue => _p.getString(_langue);
  Future<void> choisirLangue(String? l) =>
      l == null ? _p.remove(_langue) : _p.setString(_langue, l);

  /// Identifiant du téléphone (`PUT /v1/appareils/{id}`), tiré au hasard à
  /// la première ouverture puis gardé.
  Future<String> appareilId() async {
    final id = _p.getString(_appareil);
    if (id != null) return id;
    final nouveau = const Uuid().v4();
    await _p.setString(_appareil, nouveau);
    return nouveau;
  }
}
