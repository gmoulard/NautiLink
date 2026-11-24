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
  Contact({required this.name, this.phone, this.email, this.follower = true, bool sos = true})
      : sos = sos && phone != null;
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

enum EventKind { start, autoPosition, manualPosition, note, photo, voice, sos, end }

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
    List<Position>? track,
    List<LogEvent>? log,
  })  : track = track ?? [],
        log = log ?? [];
  String name;
  final Boat boat;
  final DateTime start;
  DateTime? end;
  String? destination;
  final String navigator;
  final bool asFollower;
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

  static double _haversineNm(Position a, Position b) {
    const r = 3440.065; // rayon de la Terre en milles nautiques
    double rad(double d) => d * pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLon = rad(b.lon - a.lon);
    final h = pow(sin(dLat / 2), 2) + cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLon / 2), 2);
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
  const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${months[t.month - 1]} ${t.year}, $hh:$mm';
}

String fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Fréquences possibles (RG-NAV-05).
const frequencies = <int, String>{
  3: '3 minutes',
  4: '4 minutes',
  5: '5 minutes',
  10: '10 minutes',
  15: '15 minutes',
  30: '30 minutes',
  60: '1 heure',
};

class AppState extends ChangeNotifier {
  AppState() {
    _seed();
  }

  final boats = const [
    Boat(name: 'Alizé', type: 'Voilier', length: '9,50 m', registration: 'VA 123456', homePort: 'Port-Haliguen'),
    Boat(name: 'Petit Pingouin', type: 'Bateau à moteur', length: '6,20 m', registration: 'VA 654321', homePort: 'La Trinité-sur-Mer'),
  ];

  final contacts = <Contact>[
    Contact(name: 'Claire (sœur)', phone: '06 12 34 56 78', email: 'claire@example.org'),
    Contact(name: 'Marc (voisin de ponton)', phone: '06 98 76 54 32'),
    Contact(name: 'Inès', email: 'ines@example.org'),
  ];

  final voyages = <Voyage>[];
  Voyage? current;

  bool warningAccepted = false; // RG-CPT-06
  bool firstVoyageReminderSeen = false; // RG-NAV-23
  int defaultFrequency = 10;
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

  void startVoyage({required Boat boat, String? destination, required int frequency}) {
    final now = DateTime.now();
    final p = Position(47.4875, -3.0970, now);
    _cursor = p;
    final v = Voyage(
      name: '${boat.name} — ${destination?.isNotEmpty == true ? destination : fmtDate(now)}',
      boat: boat,
      start: now,
      destination: destination,
      navigator: 'Moi',
      track: [p],
      log: [LogEvent(EventKind.start, now, position: p, text: 'Fréquence : ${frequencies[frequency]}')],
    );
    current = v;
    voyages.insert(0, v);
    notifyListeners();
  }

  void addEvent(EventKind kind, {String? text}) {
    final v = current;
    if (v == null) return;
    final withPos = kind == EventKind.manualPosition || kind == EventKind.autoPosition || kind == EventKind.sos;
    final p = withPos ? nextPosition() : null;
    if (p != null) v.track.add(p);
    v.log.add(LogEvent(kind, DateTime.now(), text: text, position: p));
    notifyListeners();
  }

  void endVoyage() {
    final v = current;
    if (v == null) return;
    v.end = DateTime.now();
    v.log.add(LogEvent(EventKind.end, v.end!, position: v.track.isEmpty ? null : v.track.last));
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
    voyages.add(Voyage(
      name: 'Alizé — Belle-Île',
      boat: boats[0],
      start: base,
      end: base.add(const Duration(hours: 3, minutes: 40)),
      destination: 'Le Palais, Belle-Île',
      navigator: 'Moi',
      track: t1,
      log: [
        LogEvent(EventKind.start, t1.first.time, position: t1.first, text: 'Fréquence : 10 minutes'),
        LogEvent(EventKind.autoPosition, t1[6].time, position: t1[6]),
        LogEvent(EventKind.note, t1[8].time, text: 'Vent d\'ouest 12 nœuds, mer belle. Grand-voile haute.'),
        LogEvent(EventKind.photo, t1[12].time, text: 'Phare de Kerdonis par le travers'),
        LogEvent(EventKind.voice, t1[16].time, text: 'Arrivée en vue du Palais, on affale dans vingt minutes.'),
        LogEvent(EventKind.end, t1.last.time, position: t1.last),
      ],
    ));

    final base2 = DateTime.now().subtract(const Duration(hours: 1, minutes: 25));
    final t2 = track(47.5830, -3.0750, 9, base2);
    voyages.add(Voyage(
      name: 'Héloïse — Houat',
      boat: const Boat(name: 'Héloïse', type: 'Voilier', length: '11 m', registration: 'LO 778899', homePort: 'Lorient'),
      start: base2,
      destination: 'Houat',
      navigator: 'Paul (ami)',
      asFollower: true,
      track: t2,
      log: [
        LogEvent(EventKind.start, t2.first.time, position: t2.first),
        LogEvent(EventKind.autoPosition, t2[4].time, position: t2[4]),
        LogEvent(EventKind.note, t2[6].time, text: 'Tout va bien à bord, café servi.'),
        LogEvent(EventKind.autoPosition, t2.last.time, position: t2.last),
      ],
    ));

    final base3 = DateTime.now().subtract(const Duration(days: 9));
    final t3 = track(47.5680, -3.0710, 14, base3);
    voyages.add(Voyage(
      name: 'Petit Pingouin — Pêche aux Birvideaux',
      boat: boats[1],
      start: base3,
      end: base3.add(const Duration(hours: 2, minutes: 15)),
      navigator: 'Moi',
      track: t3,
      log: [
        LogEvent(EventKind.start, t3.first.time, position: t3.first),
        LogEvent(EventKind.photo, t3[7].time, text: 'Trois bars ce matin'),
        LogEvent(EventKind.end, t3.last.time, position: t3.last),
      ],
    ));
  }
}
