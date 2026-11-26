import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';

/// Données d'exemple et état du prototype. Rien n'est envoyé : chaque
/// « envoi » est simulé et seulement ajouté au journal (D-57).

class Boat {
  const Boat({
    required this.name,
    required this.type,
    required this.length,
    required this.registration,
    required this.homePort,
  });
  final String name;
  final String type;
  final String length;
  final String registration;
  final String homePort;
}

class Contact {
  Contact({
    required this.name,
    this.phone,
    this.email,
    this.follower = true,
    bool sos = true,
  }) : sos = sos && phone != null;
  String name;
  String? phone;
  String? email;
  bool follower;
  bool sos; // RG-CTC-05 : contact SOS seulement avec un numéro.
}

class Position {
  const Position(this.lat, this.lon, this.time);
  final double lat;
  final double lon;
  final DateTime time;

  String get text => '${_dms(lat, 'N', 'S')}, ${_dms(lon, 'E', 'W')}';

  static String _dms(double v, String pos, String neg) {
    final a = v.abs();
    final d = a.floor();
    final m = (a - d) * 60;
    return '$d° ${m.toStringAsFixed(2)}\' ${v >= 0 ? pos : neg}';
  }
}

enum EventKind {
  start,
  autoPosition,
  manualPosition,
  note,
  photo,
  voice,
  sos,
  end,
}

class LogEvent {
  LogEvent(this.kind, this.time, {this.text, this.position, this.frequency});
  final EventKind kind;
  final DateTime time;
  final String? text;
  final Position? position;

  /// Fréquence choisie, pour l'événement de début (RG-NAV-05).
  final int? frequency;

  /// Libellé du type d'événement, dans la langue de l'interface.
  String label(AppLocalizations l) => switch (kind) {
    EventKind.start => l.eventStart,
    EventKind.autoPosition => l.eventAutoPosition,
    EventKind.manualPosition => l.eventManualPosition,
    EventKind.note => l.eventNote,
    EventKind.photo => l.eventPhoto,
    EventKind.voice => l.eventVoice,
    EventKind.sos => l.eventSos,
    EventKind.end => l.eventEnd,
  };

  /// Détail affiché sous le libellé : texte saisi, ou fréquence du début.
  String? details(AppLocalizations l) => frequency != null
      ? l.eventFrequency(frequencyLabel(l, frequency!))
      : text;
}

class Voyage {
  Voyage({
    required this.name,
    required this.boat,
    required this.start,
    this.end,
    this.destination,
    this.navigator,
    this.asFollower = false,
    this.personsOnBoard = 1,
    this.weatherStart,
    this.weatherEnd,
    Set<String>? alerted,
    List<Position>? track,
    List<LogEvent>? log,
  }) : alerted = alerted ?? {},
       track = track ?? [],
       log = log ?? [];
  String name;
  final Boat boat;
  final DateTime start;
  DateTime? end;
  String? destination;
  final String? navigator; // null : le navigateur est l'utilisateur lui-même
  final bool asFollower;
  final int personsOnBoard; // RG-NAV-27
  String? weatherStart; // RG-NAV-28
  String? weatherEnd;
  final Set<String> alerted; // noms des contacts alertés (RG-NAV-25)
  final List<Position> track;
  final List<LogEvent> log;

  bool get inProgress => end == null;
  Duration get duration => (end ?? DateTime.now()).difference(start);

  double get distanceNm {
    var total = 0.0;
    for (var i = 1; i < track.length; i++) {
      total += _haversineNm(track[i - 1], track[i]);
    }
    return total;
  }

  static double distanceMeters(Position a, Position b) =>
      _haversineNm(a, b) * 1852;

  static double _haversineNm(Position a, Position b) {
    const r = 3440.065; // rayon de la Terre en milles nautiques
    double rad(double d) => d * pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLon = rad(b.lon - a.lon);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }
}

String fmtDuration(AppLocalizations l, Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? l.durationHoursMinutes(d.inHours, m) : '$m:$s';
}

String fmtClock(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Date et heure, au format de la langue de l'interface.
String fmtDate(AppLocalizations l, DateTime t) =>
    l.dateTime(DateFormat.yMMMd(l.localeName).format(t), fmtTime(t));

String fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Fréquences possibles, en minutes (RG-NAV-05).
const frequencies = [15, 30, 60, 120, 180, 360, 720, 1440, 2880, 14400];

String frequencyLabel(AppLocalizations l, int minutes) => minutes % 1440 == 0
    ? l.frequencyDays(minutes ~/ 1440)
    : minutes % 60 == 0
    ? l.frequencyHours(minutes ~/ 60)
    : l.frequencyMinutes(minutes);

/// Types de messages réglables un par un (RG-SMS-02).
enum SmsType { start, autoPosition, manualPosition, note, photo, voice, end }

String smsTypeLabel(AppLocalizations l, SmsType t) => switch (t) {
  SmsType.start => l.smsTypeStart,
  SmsType.autoPosition => l.smsTypeAutoPosition,
  SmsType.manualPosition => l.smsTypeManualPosition,
  SmsType.note => l.smsTypeNote,
  SmsType.photo => l.smsTypePhoto,
  SmsType.voice => l.smsTypeVoice,
  SmsType.end => l.smsTypeEnd,
};

/// Page d'information sur l'abonnement du site de présentation (RG-ECO-10).
const subscriptionInfoUrl =
    'https://gmoulard.github.io/NautiLink/abonnement.html';

/// Mémo sécurité en mer du site de présentation (TODO-3.12 ; vraie application : RG-SOS-22).
const securityMemoUrl = 'https://gmoulard.github.io/NautiLink/securite.html';

/// Site de présentation, cité en pied de page sous le sponsor (TODO-3.13).
const siteUrl = 'https://gmoulard.github.io/NautiLink/';

class AppState extends ChangeNotifier {
  AppState() {
    _seed();
  }

  final boats = const [
    Boat(
      name: 'Alizé',
      type: 'Voilier',
      length: '9,50 m',
      registration: 'VA 123456',
      homePort: 'Port-Haliguen',
    ),
    Boat(
      name: 'Petit Pingouin',
      type: 'Bateau à moteur',
      length: '6,20 m',
      registration: 'VA 654321',
      homePort: 'La Trinité-sur-Mer',
    ),
  ];

  final contacts = <Contact>[
    Contact(
      name: 'Claire (sœur)',
      phone: '06 12 34 56 78',
      email: 'claire@example.org',
    ),
    Contact(name: 'Marc (voisin de ponton)', phone: '06 98 76 54 32'),
    Contact(name: 'Inès', email: 'ines@example.org'),
  ];

  final voyages = <Voyage>[];
  Voyage? current;

  bool warningAccepted = false; // RG-CPT-06
  bool firstVoyageReminderSeen = false; // RG-NAV-23
  int defaultFrequency = 30;
  bool smsEnabled = true;
  final smsByType = <SmsType, bool>{
    SmsType.start: true,
    SmsType.autoPosition: false,
    SmsType.manualPosition: true,
    SmsType.note: true,
    SmsType.photo: false,
    SmsType.voice: true,
    SmsType.end: true,
  };

  /// Quota simulé : minutes consommées sur les 7 derniers jours (RG-ECO-01).
  int usedMinutes = 9 * 60 + 40;
  static const quotaMinutes = 24 * 60;

  final _rnd = Random(7);
  Position _cursor = Position(47.4875, -3.0970, DateTime.now());

  void acceptWarning() {
    warningAccepted = true;
    notifyListeners();
  }

  void seeFirstReminder() {
    firstVoyageReminderSeen = true;
    notifyListeners();
  }

  Position nextPosition() {
    _cursor = Position(
      _cursor.lat - 0.004 - _rnd.nextDouble() * 0.003,
      _cursor.lon - 0.002 + _rnd.nextDouble() * 0.006,
      DateTime.now(),
    );
    return _cursor;
  }

  /// Nombre de personnes à bord de la navigation précédente (RG-NAV-27).
  int lastPersonsOnBoard = 1;

  /// Contacts alertés par défaut : suiveurs et contacts SOS (RG-NAV-25).
  List<Contact> get alertable =>
      contacts.where((c) => c.follower || c.sos).toList();

  void addContact(Contact c) {
    contacts.add(c);
    notifyListeners();
  }

  /// Contacts SOS alertés pendant la navigation en cours.
  List<Contact> get sosContactsNow {
    final v = current;
    return contacts
        .where((c) => c.sos && (v == null || v.alerted.contains(c.name)))
        .toList();
  }

  void startVoyage({
    required Boat boat,
    String? destination,
    required int frequency,
    int persons = 1,
    Set<String>? alerted,
  }) {
    final now = DateTime.now();
    final p = Position(47.4875, -3.0970, now);
    _cursor = p;
    final v = Voyage(
      name:
          '${boat.name} — ${destination?.isNotEmpty == true ? destination : DateFormat('yyyy-MM-dd HH:mm').format(now)}',
      boat: boat,
      start: now,
      destination: destination,
      personsOnBoard: persons,
      alerted: alerted ?? alertable.map((c) => c.name).toSet(),
      weatherStart: demoWeather(p),
      track: [p],
      log: [LogEvent(EventKind.start, now, position: p, frequency: frequency)],
    );
    lastPersonsOnBoard = persons;
    current = v;
    voyages.insert(0, v);
    notifyListeners();
  }

  void addEvent(EventKind kind, {String? text}) {
    final v = current;
    if (v == null) return;
    final withPos =
        kind == EventKind.manualPosition ||
        kind == EventKind.autoPosition ||
        kind == EventKind.sos;
    final p = withPos ? nextPosition() : null;
    if (p != null) v.track.add(p);
    v.log.add(LogEvent(kind, DateTime.now(), text: text, position: p));
    notifyListeners();
  }

  /// RG-NAV-24 : aucune position à plus de 20 m de la dernière depuis 2 heures.
  bool isStationary({
    Duration span = const Duration(hours: 2),
    double meters = 20,
  }) {
    final v = current;
    if (v == null || v.track.isEmpty) return false;
    final last = v.track.last;
    if (last.time.difference(v.track.first.time) < span) return false;
    final since = last.time.subtract(span);
    final recent = v.track.where((p) => !p.time.isBefore(since));
    return recent.every((p) => Voyage.distanceMeters(p, last) <= meters);
  }

  /// Démonstration : simule 2 h 10 passées au même endroit après la dernière position.
  void simulateStationary() {
    final v = current;
    if (v == null || v.track.isEmpty) return;
    final base = v.track.last;
    for (var i = 1; i <= 13; i++) {
      v.track.add(
        Position(
          base.lat + (i.isEven ? 0.00004 : -0.00004),
          base.lon,
          base.time.add(Duration(minutes: 10 * i)),
        ),
      );
    }
    notifyListeners();
  }

  void endVoyage() {
    final v = current;
    if (v == null) return;
    v.end = DateTime.now();
    if (v.track.isNotEmpty) v.weatherEnd = demoWeather(v.track.last);
    v.log.add(
      LogEvent(
        EventKind.end,
        v.end!,
        position: v.track.isEmpty ? null : v.track.last,
      ),
    );
    usedMinutes += max(1, v.duration.inMinutes);
    current = null;
    notifyListeners();
  }

  void renameVoyage(Voyage v, String name) {
    v.name = name;
    notifyListeners();
  }

  void touch() => notifyListeners();

  void _seed() {
    final base = DateTime.now().subtract(const Duration(days: 3, hours: 5));
    List<Position> track(double lat, double lon, int n, DateTime t0) {
      final r = Random(n);
      final out = <Position>[];
      var la = lat, lo = lon;
      for (var i = 0; i < n; i++) {
        out.add(Position(la, lo, t0.add(Duration(minutes: 10 * i))));
        la += -0.006 + r.nextDouble() * 0.004;
        lo += 0.004 + r.nextDouble() * 0.006;
      }
      return out;
    }

    final t1 = track(47.4875, -3.0970, 22, base);
    voyages.add(
      Voyage(
        name: 'Alizé — Belle-Île',
        boat: boats[0],
        start: base,
        end: base.add(const Duration(hours: 3, minutes: 40)),
        destination: 'Le Palais, Belle-Île',
        personsOnBoard: 3,
        weatherStart: 'Ouest 12 nœuds · mer peu agitée · 1016 hPa',
        weatherEnd: 'Ouest 15 nœuds · mer agitée · 1014 hPa',
        track: t1,
        log: [
          LogEvent(
            EventKind.start,
            t1.first.time,
            position: t1.first,
            frequency: 30,
          ),
          LogEvent(EventKind.autoPosition, t1[6].time, position: t1[6]),
          LogEvent(
            EventKind.note,
            t1[8].time,
            text: 'Vent d\'ouest 12 nœuds, mer belle. Grand-voile haute.',
          ),
          LogEvent(
            EventKind.photo,
            t1[12].time,
            text: 'Phare de Kerdonis par le travers',
          ),
          LogEvent(EventKind.voice, t1[16].time, text: 'Enregistrement · 0:14'),
          LogEvent(EventKind.end, t1.last.time, position: t1.last),
        ],
      ),
    );

    final base2 = DateTime.now().subtract(
      const Duration(hours: 1, minutes: 25),
    );
    final t2 = track(47.5830, -3.0750, 9, base2);
    voyages.add(
      Voyage(
        name: 'Héloïse — Houat',
        boat: const Boat(
          name: 'Héloïse',
          type: 'Voilier',
          length: '11 m',
          registration: 'LO 778899',
          homePort: 'Lorient',
        ),
        start: base2,
        destination: 'Houat',
        navigator: 'Paul (ami)',
        asFollower: true,
        personsOnBoard: 4,
        weatherStart: 'Sud-Ouest 14 nœuds · mer agitée · 1011 hPa',
        track: t2,
        log: [
          LogEvent(EventKind.start, t2.first.time, position: t2.first),
          LogEvent(EventKind.autoPosition, t2[4].time, position: t2[4]),
          LogEvent(
            EventKind.note,
            t2[6].time,
            text: 'Tout va bien à bord, café servi.',
          ),
          LogEvent(EventKind.autoPosition, t2.last.time, position: t2.last),
        ],
      ),
    );

    final base3 = DateTime.now().subtract(const Duration(days: 9));
    final t3 = track(47.5680, -3.0710, 14, base3);
    voyages.add(
      Voyage(
        name: 'Petit Pingouin — Pêche aux Birvideaux',
        boat: boats[1],
        start: base3,
        end: base3.add(const Duration(hours: 2, minutes: 15)),
        personsOnBoard: 2,
        weatherStart: 'Nord-Ouest 8 nœuds · mer belle · 1019 hPa',
        weatherEnd: 'Nord-Ouest 10 nœuds · mer belle · 1018 hPa',
        track: t3,
        log: [
          LogEvent(EventKind.start, t3.first.time, position: t3.first),
          LogEvent(EventKind.photo, t3[7].time, text: 'Trois bars ce matin'),
          LogEvent(EventKind.end, t3.last.time, position: t3.last),
        ],
      ),
    );

    // Navigation en Méditerranée : Port du Niel (Giens) → Toulon, Vieille Darse,
    // par la pointe d'Escampobariou et le Cap Brun, à 5,5 nœuds.
    final d = DateTime.now().subtract(const Duration(days: 6));
    final base4 = DateTime(d.year, d.month, d.day, 9, 10);
    final t4 = route(const [
      (43.0368, 6.1285), // Port du Niel
      (43.0280, 6.1200),
      (43.0250, 6.0900),
      (43.0360, 6.0680), // pointe d'Escampobariou
      (43.0580, 6.0580),
      (43.0740, 6.0350),
      (43.0770, 6.0000), // au large du Pradet
      (43.0870, 5.9650), // Cap Brun
      (43.0960, 5.9500),
      (43.1040, 5.9400), // passe de la Grande Jetée
      (43.1120, 5.9340),
      (43.1197, 5.9330), // Vieille Darse
    ], base4);
    voyages.add(
      Voyage(
        name: 'Alizé — Toulon, Vieille Darse',
        boat: boats[0],
        start: base4,
        end: t4.last.time,
        destination: 'Toulon, Vieille Darse',
        personsOnBoard: 2,
        weatherStart: 'Est 10 nœuds · mer belle · 1018 hPa',
        weatherEnd: 'Est 12 nœuds · mer peu agitée · 1017 hPa',
        track: t4,
        log: [
          LogEvent(
            EventKind.start,
            t4.first.time,
            position: t4.first,
            frequency: 30,
          ),
          LogEvent(EventKind.autoPosition, t4[3].time, position: t4[3]),
          LogEvent(
            EventKind.note,
            t4[5].time.add(const Duration(minutes: 3)),
            text: 'Vent d\'est 10 nœuds, mer belle. Génois seul.',
          ),
          LogEvent(EventKind.autoPosition, t4[7].time, position: t4[7]),
          LogEvent(EventKind.autoPosition, t4[9].time, position: t4[9]),
          LogEvent(EventKind.end, t4.last.time, position: t4.last),
        ],
      ),
    );
  }
}

/// Positions d'un trajet donné point par point, datées selon la distance
/// parcourue à [knots] nœuds.
List<Position> route(
  List<(double, double)> points,
  DateTime start, {
  double knots = 5.5,
}) {
  final out = <Position>[];
  var t = start;
  for (var i = 0; i < points.length; i++) {
    final (lat, lon) = points[i];
    if (i > 0) {
      final prev = out.last;
      final nm = Voyage.distanceMeters(prev, Position(lat, lon, t)) / 1852;
      t = t.add(Duration(seconds: (nm / knots * 3600).round()));
    }
    out.add(Position(lat, lon, t));
  }
  return out;
}

/// Lieux connus pour le géocodage inverse de démonstration (RG-NAV-16, RG-JRN-10).
const _places = <(String, double, double)>[
  ('Port-Haliguen', 47.488, -3.100),
  ('Quiberon', 47.483, -3.120),
  ('Pointe de la Teignouse', 47.457, -3.046),
  ('Le Palais, Belle-Île', 47.348, -3.155),
  ('Sauzon, Belle-Île', 47.373, -3.218),
  ('Houat', 47.393, -2.958),
  ('Hoëdic', 47.338, -2.875),
  ('La Trinité-sur-Mer', 47.585, -3.029),
  ('Plateau des Birvideaux', 47.490, -3.290),
  ('Baie de Quiberon', 47.530, -3.050),
  ('Port du Niel, Giens', 43.037, 6.128),
  ('Pointe d\'Escampobariou', 43.030, 6.075),
  ('Carqueiranne', 43.088, 6.073),
  ('Le Pradet', 43.090, 6.020),
  ('Cap Brun', 43.093, 5.968),
  ('Grande Jetée de Toulon', 43.102, 5.943),
  ('Toulon, Vieille Darse', 43.1197, 5.933),
];

/// Nom du lieu le plus proche à moins de 8 milles, sinon les coordonnées.
String placeName(AppLocalizations l, Position p) {
  var best = '';
  var bestNm = double.infinity;
  for (final (name, lat, lon) in _places) {
    final d = Voyage.distanceMeters(p, Position(lat, lon, p.time)) / 1852;
    if (d < bestNm) {
      bestNm = d;
      best = name;
    }
  }
  if (bestNm > 8) return p.text;
  return bestNm < 0.5 ? best : l.nearPlace(bestNm.toStringAsFixed(1), best);
}

/// Météo de démonstration : en vrai, relevée par le serveur (RG-NAV-28, Q-39).
/// Donnée d'exemple, comme les noms de bateaux et de lieux : non traduite.
String demoWeather(Position p) {
  final r = Random(p.lat.hashCode ^ p.lon.hashCode);
  const dirs = ['Nord', 'Nord-Ouest', 'Ouest', 'Sud-Ouest', 'Sud'];
  const seas = ['mer belle', 'mer peu agitée', 'mer agitée'];
  return '${dirs[r.nextInt(dirs.length)]} ${8 + r.nextInt(12)} nœuds · ${seas[r.nextInt(seas.length)]} · ${1008 + r.nextInt(14)} hPa';
}

/// Météo marine de Météo-France, ouverte depuis l'écran de navigation (Q-102).
const meteoMarineUrl = 'https://meteofrance.com/meteo-marine';
