import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../theme.dart';
import 'navigation.dart';

/// Tableau de bord de la plateforme Web (cahier des charges §6.1).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onlyMine = false});
  final bool onlyMine;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String filter = 'tout';

  @override
  void initState() {
    super.initState();
    if (widget.onlyMine) filter = 'navigateur';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final all = state.voyages.where(
      (v) => switch (filter) {
        'navigateur' => !v.asFollower,
        'ami' => v.asFollower,
        _ => true,
      },
    );
    final live = all.where((v) => v.inProgress).toList();
    final past = all.where((v) => !v.inProgress).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.onlyMine ? l.savedVoyages : l.dashboard,
        ),
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'tout', label: Text(l.filterAll)),
                        ButtonSegment(
                          value: 'navigateur',
                          label: Text(l.filterNavigator),
                        ),
                        ButtonSegment(
                          value: 'ami',
                          label: Text(l.filterFollower),
                        ),
                      ],
                      selected: {filter},
                      onSelectionChanged: (s) =>
                          setState(() => filter = s.first),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.inProgress,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (live.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(l.noVoyageInProgress),
                      ),
                    for (final v in live) _VoyageCard(voyage: v),
                    const SizedBox(height: 20),
                    Text(
                      l.history,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final v in past) _VoyageCard(voyage: v),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoyageCard extends StatelessWidget {
  const _VoyageCard({required this.voyage});
  final Voyage voyage;

  @override
  Widget build(BuildContext context) {
    final v = voyage;
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          v.inProgress ? Icons.sailing : Icons.anchor,
          color: v.inProgress ? NlColors.teal : null,
          size: 32,
        ),
        title: Text(
          v.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${fmtDate(l, v.start)} · ${fmtDuration(l, v.duration)} · ${l.distanceNm(v.distanceNm.toStringAsFixed(1))}'
          '${v.asFollower ? l.voyageCardFollowed(v.navigator ?? '') : ''}',
        ),
        trailing: v.inProgress
            ? Chip(
                label: Text(l.live),
                backgroundColor: NlColors.aqua,
              )
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => VoyageScreen(voyage: v))),
      ),
    );
  }
}

/// Page d'une navigation : carte du tracé et journal (cahier des charges §6.2).
class VoyageScreen extends StatelessWidget {
  const VoyageScreen({super.key, required this.voyage});
  final Voyage voyage;

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // se redessine quand l'état change
    final v = voyage;
    final l = AppLocalizations.of(context);
    final info = [
      (l.boat, '${v.boat.name} · ${v.boat.type} · ${v.boat.length}'),
      (l.personsOnBoard, '${v.personsOnBoard}'),
      (l.infoDeparture, fmtDate(l, v.start)),
      if (v.track.isNotEmpty) (l.infoDeparturePlace, placeName(l, v.track.first)),
      if (v.weatherStart != null) (l.infoWeatherStart, v.weatherStart!),
      if (v.end != null) (l.infoArrival, fmtDate(l, v.end!)),
      if (v.end != null && v.track.isNotEmpty) (l.infoArrivalPlace, placeName(l, v.track.last)),
      if (v.weatherEnd != null) (l.infoWeatherEnd, v.weatherEnd!),
      if (v.destination?.isNotEmpty == true) (l.infoDestination, v.destination!),
      (l.infoDuration, fmtDuration(l, v.duration)),
      (l.infoDistance, l.distanceNm(v.distanceNm.toStringAsFixed(1))),
      (l.infoNavigator, v.navigator ?? l.me),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(v.name),
        actions: [
          if (!v.asFollower)
            IconButton(
              tooltip: l.rename,
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final c = TextEditingController(text: v.name);
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.renameVoyage),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: Text(l.save),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty && context.mounted) {
                  AppScope.of(context).renameVoyage(v, name);
                }
              },
            ),
          IconButton(
            tooltip: l.exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.exportPdfSoon)),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 820;
          final map = AspectRatio(
            aspectRatio: wide ? 1 : 1.3,
            child: SeaMap(voyage: v),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (k, val) in info)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          k,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(child: Text(val)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                l.logbook,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final e in v.log) LogTile(event: e),
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const DemoBanner(),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: map),
                    const SizedBox(width: 20),
                    Expanded(child: details),
                  ],
                )
              else ...[
                map,
                const SizedBox(height: 16),
                details,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Carte simplifiée du tracé, sans fond cartographique (démonstration hors ligne).
class TrackMap extends StatelessWidget {
  const TrackMap({super.key, required this.voyage});
  final Voyage voyage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(painter: _TrackPainter(voyage)),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.v) : count = v.track.length;
  final Voyage v;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDCEFF3),
    );
    final grid = Paint()
      ..color = const Color(0xFFB9DCE3)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(
        Offset(size.width * i / 6, 0),
        Offset(size.width * i / 6, size.height),
        grid,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 6),
        Offset(size.width, size.height * i / 6),
        grid,
      );
    }
    final t = v.track;
    if (t.isEmpty) return;
    var minLat = t.map((p) => p.lat).reduce(min),
        maxLat = t.map((p) => p.lat).reduce(max);
    var minLon = t.map((p) => p.lon).reduce(min),
        maxLon = t.map((p) => p.lon).reduce(max);
    final span = max(max(maxLat - minLat, maxLon - minLon), 0.01) * 1.3;
    final cLat = (minLat + maxLat) / 2, cLon = (minLon + maxLon) / 2;
    Offset at(Position p) => Offset(
      size.width / 2 + (p.lon - cLon) / span * size.width,
      size.height / 2 - (p.lat - cLat) / span * size.height,
    );
    final path = Path()..moveTo(at(t.first).dx, at(t.first).dy);
    for (final p in t.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = NlColors.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in t) {
      canvas.drawCircle(at(p), 3, Paint()..color = NlColors.teal);
    }
    canvas.drawCircle(at(t.first), 7, Paint()..color = NlColors.navy);
    canvas.drawCircle(
      at(t.last),
      9,
      Paint()..color = v.inProgress ? NlColors.alert : NlColors.teal,
    );
    canvas.drawCircle(at(t.last), 4, Paint()..color = NlColors.white);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.v != v || old.count != count;
}

/// Carte de la page d'une navigation : fond OpenStreetMap et balisage
/// OpenSeaMap, avec leurs mentions de source (RG-NAV-29). Données du SHOM : Q-23.
class SeaMap extends StatelessWidget {
  const SeaMap({super.key, required this.voyage});
  final Voyage voyage;

  /// Les tests désactivent les tuiles (aucun accès réseau) : seul le tracé est dessiné.
  static bool tilesEnabled = true;

  @override
  Widget build(BuildContext context) {
    final pts = [for (final p in voyage.track) LatLng(p.lat, p.lon)];
    if (pts.isEmpty) return TrackMap(voyage: voyage);
    final bounds = LatLngBounds.fromPoints(pts.length == 1 ? [pts.first, pts.first] : pts);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36), maxZoom: 14),
          backgroundColor: const Color(0xFFDCEFF8),
        ),
        children: [
          if (tilesEnabled) ...[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.nautilink.nautilink',
            ),
            TileLayer(
              urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.nautilink.nautilink',
            ),
          ],
          PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 3.5, color: NlColors.ink)]),
          MarkerLayer(
            markers: [
              Marker(point: pts.first, width: 16, height: 16, child: const _Dot(color: NlColors.ink)),
              Marker(
                point: pts.last,
                width: 22,
                height: 22,
                child: _Dot(color: voyage.inProgress ? NlColors.alert : NlColors.accent, ring: true),
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xCCFFFFFF), borderRadius: BorderRadius.all(Radius.circular(6))),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('© OpenStreetMap · © OpenSeaMap', style: TextStyle(fontSize: 10, color: NlColors.ink)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.ring = false});
  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: ring ? Border.all(color: NlColors.white, width: 4) : null,
        ),
      );
}

