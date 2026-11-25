import 'dart:math';

import 'package:flutter/foundation.dart';

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
  LogEvent(this.kind, this.time, {this.text, this.position});
  final EventKind kind;
  final DateTime time;
  final String? text;
  final Position? position;

  String get label => switch (kind) {
    EventKind.start => 'Début de navigation',
    EventKind.autoPosition => 'Position automatique',
    EventKind.manualPosition => 'Position envoyée',
    EventKind.note => 'Note',
    EventKind.photo => 'Photo',
    EventKind.voice => 'Note vocale',
    EventKind.sos => 'Alerte SOS',
    EventKind.end => 'Fin de navigation',
  };
}

class Voyage {
  Voyage({
    required this.name,
    required this.boat,
    required this.start,
    this.end,
    this.destination,
    required this.navigator,
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
  final String navigator;
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

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h h $m min' : '$m:$s';
}

String fmtClock(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String fmtDate(DateTime t) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${months[t.month - 1]} ${t.year}, $hh:$mm';
}

String fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Fréquences possibles, en minutes (RG-NAV-05).
const frequencies = <int, String>{
  15: '15 minutes',
  30: '30 minutes',
  60: '1 heure',
  120: '2 heures',
  180: '3 heures',
  360: '6 heures',
  720: '12 heures',
  1440: '1 jour',
  2880: '2 jours',
  14400: '10 jours',
};

/// Page d'information sur l'abonnement du site de présentation (RG-ECO-10).
const subscriptionInfoUrl =
    'https://gmoulard.github.io/NautiLink/abonnement.html';

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
  final smsByType = <String, bool>{
    'Début de navigation': true,
    'Positions automatiques': false,
    'Positions manuelles': true,
    'Notes écrites': true,
    'Photos': false,
    'Notes vocales': true,
    'Fin de navigation': true,
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
  List<Contact> get alertable => contacts.where((c) => c.follower || c.sos).toList();

  void addContact(Contact c) {
    contacts.add(c);
    notifyListeners();
  }

  /// Contacts SOS alertés pendant la navigation en cours.
  List<Contact> get sosContactsNow {
    final v = current;
    return contacts.where((c) => c.sos && (v == null || v.alerted.contains(c.name))).toList();
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
          '${boat.name} — ${destination?.isNotEmpty == true ? destination : fmtDate(now)}',
      boat: boat,
      start: now,
      destination: destination,
      navigator: 'Moi',
      personsOnBoard: persons,
      alerted: alerted ?? alertable.map((c) => c.name).toSet(),
      weatherStart: demoWeather(p),
      track: [p],
      log: [
        LogEvent(
          EventKind.start,
          now,
          position: p,
          text: 'Fréquence : ${frequencies[frequency]}',
        ),
      ],
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
        navigator: 'Moi',
        personsOnBoard: 3,
        weatherStart: 'Ouest 12 nœuds · mer peu agitée · 1016 hPa',
        weatherEnd: 'Ouest 15 nœuds · mer agitée · 1014 hPa',
        track: t1,
        log: [
          LogEvent(
            EventKind.start,
            t1.first.time,
            position: t1.first,
            text: 'Fréquence : 30 minutes',
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
          LogEvent(
            EventKind.voice,
            t1[16].time,
            text: 'Enregistrement · 0:14',
          ),
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
        navigator: 'Moi',
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
  }
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
];

/// Nom du lieu le plus proche à moins de 8 milles, sinon les coordonnées.
String placeName(Position p) {
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
  return bestNm < 0.5 ? best : 'à ${bestNm.toStringAsFixed(1)} milles de $best';
}

/// Météo de démonstration : en vrai, relevée par le serveur (RG-NAV-28, Q-39).
String demoWeather(Position p) {
  final r = Random(p.lat.hashCode ^ p.lon.hashCode);
  const dirs = ['Nord', 'Nord-Ouest', 'Ouest', 'Sud-Ouest', 'Sud'];
  const seas = ['mer belle', 'mer peu agitée', 'mer agitée'];
  return '${dirs[r.nextInt(dirs.length)]} ${8 + r.nextInt(12)} nœuds · ${seas[r.nextInt(seas.length)]} · ${1008 + r.nextInt(14)} hPa';
}

