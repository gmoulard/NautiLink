import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Priorités de la file (08-architecture.md §5) : l'alerte SOS avant tout le
/// reste, puis les éléments légers, enfin les fichiers.
abstract final class Priorite {
  static const sos = 0;
  static const leger = 1;
  static const fichier = 2;
}

/// Un envoi de la file d'attente, enregistré sur le téléphone avant toute
/// tentative (RG-COM-05). `operation` : `demarrage`, `evenement`, `fin`,
/// `alerte_sos`, `statuts_sms` (schéma `ElementFile`) ou `fichier`
/// (`PUT /v1/fichiers/{id}`, à part).
class ElementFile {
  const ElementFile({
    required this.operation,
    required this.id,
    this.navigationId,
    this.contenu,
    required this.priorite,
    this.sequence = 0,
    this.essais = 0,
    this.misDeCote = false,
    this.dernierStatut,
    this.derniereErreur,
    this.chemin,
    this.typeMedia,
    this.creeLe,
  });

  final String operation;
  final String id;
  final String? navigationId;

  /// Corps JSON de l'appel unitaire correspondant.
  final Object? contenu;
  final int priorite;

  /// Rang d'enregistrement sur le téléphone : la file part dans cet ordre.
  final int sequence;
  final int essais;

  /// Refus définitif (4xx) : gardé, sans nouvel essai (08-architecture.md §5).
  final bool misDeCote;
  final int? dernierStatut;
  final String? derniereErreur;

  /// Fichier d'une photo ou d'une note vocale, et son type.
  final String? chemin;
  final String? typeMedia;
  final DateTime? creeLe;

  /// Clé unique dans la file : une même opération sur un même identifiant n'y est qu'une fois.
  String get cle => '$operation:$id';
}

/// Base locale du téléphone : file d'attente, numéros d'ordre et dernières
/// copies reçues du serveur (navigations, contacts, paramètres, quota…), qui
/// servent hors connexion (RG-COM-06, RG-CTC-03, RG-PRM-02).
abstract class BaseLocale {
  /// Enregistre un élément ; un élément de même clé déjà présent est gardé tel quel.
  Future<void> ajouterElement(ElementFile e);

  /// Éléments à envoyer (hors mis de côté), par priorité puis dans l'ordre d'enregistrement.
  Future<List<ElementFile>> elementsAEnvoyer();

  Future<List<ElementFile>> elementsMisDeCote();

  Future<void> retirer(String cle);

  /// Note un essai sans succès ; `misDeCote` pour un refus définitif.
  Future<void> noterEchec(
    String cle, {
    int? statut,
    String? erreur,
    bool misDeCote = false,
  });

  Future<int> compter();

  /// Numéro d'ordre suivant pour la navigation (1, 2, 3…), attribué par le téléphone.
  Future<int> numeroOrdreSuivant(String navigationId);

  Future<void> ecrireCopie(String cle, Object? valeur, DateTime recueLe);

  Future<({Object? valeur, DateTime recueLe})?> lireCopie(String cle);

  /// Efface les copies reçues du serveur (changement de compte) ; la file reste.
  Future<void> effacerCopies();

  Future<void> fermer();
}

/// Base SQLite (sqflite) des téléphones Android et iPhone.
class BaseSqlite implements BaseLocale {
  BaseSqlite._(this._db);
  final Database _db;

  /// Ouvre la base ; `fabrique` et `chemin` servent aux essais
  /// (`databaseFactoryFfi`, `inMemoryDatabasePath`).
  static Future<BaseSqlite> ouvrir({
    DatabaseFactory? fabrique,
    String? chemin,
  }) async {
    final f = fabrique ?? databaseFactory;
    final p = chemin ?? '${await f.getDatabasesPath()}/nautilink.db';
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE file_attente (
            sequence INTEGER PRIMARY KEY AUTOINCREMENT,
            cle TEXT NOT NULL UNIQUE,
            operation TEXT NOT NULL,
            id TEXT NOT NULL,
            navigation_id TEXT,
            contenu TEXT,
            priorite INTEGER NOT NULL,
            essais INTEGER NOT NULL DEFAULT 0,
            mis_de_cote INTEGER NOT NULL DEFAULT 0,
            dernier_statut INTEGER,
            derniere_erreur TEXT,
            chemin TEXT,
            type_media TEXT,
            cree_le TEXT NOT NULL)''');
          await db.execute(
            'CREATE TABLE numeros_ordre (navigation_id TEXT PRIMARY KEY, dernier INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE copies (cle TEXT PRIMARY KEY, valeur TEXT, recue_le TEXT NOT NULL)',
          );
        },
      ),
    );
    return BaseSqlite._(db);
  }

  ElementFile _lire(Map<String, Object?> l) => ElementFile(
    operation: l['operation'] as String,
    id: l['id'] as String,
    navigationId: l['navigation_id'] as String?,
    contenu: l['contenu'] == null ? null : jsonDecode(l['contenu'] as String),
    priorite: l['priorite'] as int,
    sequence: l['sequence'] as int,
    essais: l['essais'] as int,
    misDeCote: l['mis_de_cote'] == 1,
    dernierStatut: l['dernier_statut'] as int?,
    derniereErreur: l['derniere_erreur'] as String?,
    chemin: l['chemin'] as String?,
    typeMedia: l['type_media'] as String?,
    creeLe: DateTime.tryParse(l['cree_le'] as String),
  );

  @override
  Future<void> ajouterElement(ElementFile e) => _db.insert('file_attente', {
    'cle': e.cle,
    'operation': e.operation,
    'id': e.id,
    'navigation_id': e.navigationId,
    'contenu': e.contenu == null ? null : jsonEncode(e.contenu),
    'priorite': e.priorite,
    'chemin': e.chemin,
    'type_media': e.typeMedia,
    'cree_le': (e.creeLe ?? DateTime.now()).toUtc().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  @override
  Future<List<ElementFile>> elementsAEnvoyer() async => [
    for (final l in await _db.query(
      'file_attente',
      where: 'mis_de_cote = 0',
      orderBy: 'priorite, sequence',
    ))
      _lire(l),
  ];

  @override
  Future<List<ElementFile>> elementsMisDeCote() async => [
    for (final l in await _db.query(
      'file_attente',
      where: 'mis_de_cote = 1',
      orderBy: 'sequence',
    ))
      _lire(l),
  ];

  @override
  Future<void> retirer(String cle) =>
      _db.delete('file_attente', where: 'cle = ?', whereArgs: [cle]);

  @override
  Future<void> noterEchec(
    String cle, {
    int? statut,
    String? erreur,
    bool misDeCote = false,
  }) => _db.rawUpdate(
    'UPDATE file_attente SET essais = essais + 1, dernier_statut = ?, derniere_erreur = ?, mis_de_cote = ? WHERE cle = ?',
    [statut, erreur, misDeCote ? 1 : 0, cle],
  );

  @override
  Future<int> compter() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT count(*) FROM file_attente WHERE mis_de_cote = 0',
        ),
      ) ??
      0;

  @override
  Future<int> numeroOrdreSuivant(String navigationId) =>
      _db.transaction((t) async {
        final l = await t.query(
          'numeros_ordre',
          where: 'navigation_id = ?',
          whereArgs: [navigationId],
        );
        final n = (l.isEmpty ? 0 : l.first['dernier'] as int) + 1;
        await t.insert('numeros_ordre', {
          'navigation_id': navigationId,
          'dernier': n,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return n;
      });

  @override
  Future<void> ecrireCopie(String cle, Object? valeur, DateTime recueLe) =>
      _db.insert('copies', {
        'cle': cle,
        'valeur': jsonEncode(valeur),
        'recue_le': recueLe.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<({Object? valeur, DateTime recueLe})?> lireCopie(String cle) async {
    final l = await _db.query('copies', where: 'cle = ?', whereArgs: [cle]);
    if (l.isEmpty) return null;
    return (
      valeur: jsonDecode(l.first['valeur'] as String),
      recueLe: DateTime.parse(l.first['recue_le'] as String),
    );
  }

  @override
  Future<void> effacerCopies() => _db.delete('copies');

  @override
  Future<void> fermer() => _db.close();
}

/// Base en mémoire : essais, et vraie application construite pour le Web,
/// où sqflite n'existe pas (rien n'y survit à la fermeture de la page).
class BaseMemoire implements BaseLocale {
  final _file = <String, ElementFile>{};
  final _ordres = <String, int>{};
  final _copies = <String, ({Object? valeur, DateTime recueLe})>{};
  var _sequence = 0;

  @override
  Future<void> ajouterElement(ElementFile e) async {
    _file.putIfAbsent(
      e.cle,
      () => ElementFile(
        operation: e.operation,
        id: e.id,
        navigationId: e.navigationId,
        contenu: e.contenu == null ? null : jsonDecode(jsonEncode(e.contenu)),
        priorite: e.priorite,
        sequence: ++_sequence,
        chemin: e.chemin,
        typeMedia: e.typeMedia,
        creeLe: e.creeLe ?? DateTime.now(),
      ),
    );
  }

  List<ElementFile> _tries(bool deCote) =>
      _file.values.where((e) => e.misDeCote == deCote).toList()..sort((a, b) {
        final p = a.priorite.compareTo(b.priorite);
        return deCote || p == 0 ? a.sequence.compareTo(b.sequence) : p;
      });

  @override
  Future<List<ElementFile>> elementsAEnvoyer() async => _tries(false);

  @override
  Future<List<ElementFile>> elementsMisDeCote() async => _tries(true);

  @override
  Future<void> retirer(String cle) async => _file.remove(cle);

  @override
  Future<void> noterEchec(
    String cle, {
    int? statut,
    String? erreur,
    bool misDeCote = false,
  }) async {
    final e = _file[cle];
    if (e == null) return;
    _file[cle] = ElementFile(
      operation: e.operation,
      id: e.id,
      navigationId: e.navigationId,
      contenu: e.contenu,
      priorite: e.priorite,
      sequence: e.sequence,
      essais: e.essais + 1,
      misDeCote: misDeCote,
      dernierStatut: statut,
      derniereErreur: erreur,
      chemin: e.chemin,
      typeMedia: e.typeMedia,
      creeLe: e.creeLe,
    );
  }

  @override
  Future<int> compter() async => _file.values.where((e) => !e.misDeCote).length;

  @override
  Future<int> numeroOrdreSuivant(String navigationId) async =>
      _ordres[navigationId] = (_ordres[navigationId] ?? 0) + 1;

  @override
  Future<void> ecrireCopie(
    String cle,
    Object? valeur,
    DateTime recueLe,
  ) async =>
      _copies[cle] = (valeur: jsonDecode(jsonEncode(valeur)), recueLe: recueLe);

  @override
  Future<({Object? valeur, DateTime recueLe})?> lireCopie(String cle) async =>
      _copies[cle];

  @override
  Future<void> effacerCopies() async => _copies.clear();

  @override
  Future<void> fermer() async {}
}
