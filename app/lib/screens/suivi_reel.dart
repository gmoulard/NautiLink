import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';

import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/depot_reel.dart';
import '../reel/suivi.dart';
import '../theme.dart';
import 'pied.dart';
import 'dashboard.dart' show SeaMap;
import 'navigation.dart' show fmtSeconds;

/// Vue ami de la vraie application, sur Android et iPhone (RG-IOS-05,
/// RG-AND-09) : tableau de bord des navigations, comme sur le Web (cahier
/// des charges §6.1), et page d'une navigation avec la carte, en lecture
/// seule (§6.2, §6.4, RG-PAR-07, RG-PAR-08).

/// Tableau de bord : navigations en cours en haut (les miennes et celles que
/// je suis), puis l'historique, filtrable « comme navigateur » / « comme
/// ami » (D-23).
class SuiviReelScreen extends StatefulWidget {
  const SuiviReelScreen({super.key});

  @override
  State<SuiviReelScreen> createState() => _SuiviReelScreenState();
}

class _SuiviReelScreenState extends State<SuiviReelScreen> {
  String? role; // vide : toutes
  List<ResumeNavigation>? navigations;
  Object? erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _charger();
      // RG-AND-02 : autorisation des notifications au moment où elle sert.
      (DepotScope.of(context) as DepotReel).preparerNotifications();
    });
  }

  Future<void> _charger() async {
    final d = DepotScope.of(context) as DepotReel;
    try {
      final r = await d.api.appelObjet(
        'GET',
        '/v1/navigations',
        parametres: {'role': ?role},
      );
      final l = [
        for (final n in (r['navigations'] as List?) ?? const [])
          ?ResumeNavigation.depuisJson(n),
      ];
      if (mounted) {
        setState(() {
          navigations = l;
          erreur = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => erreur = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final liste = navigations;
    final enCours = liste?.where((n) => n.enCours).toList() ?? const [];
    final historique = liste?.where((n) => !n.enCours).toList() ?? const [];
    Widget carte(ResumeNavigation n) => Card(
      child: ListTile(
        leading: Icon(
          n.enCours ? Icons.sailing : Icons.history,
          color: n.enCours ? NlColors.alert : NlColors.teal,
        ),
        title: Text(n.nom),
        subtitle: Text(
          [
            n.bateauNom,
            fmtDate(l, n.debut),
            if (n.dureeMinutes != null)
              fmtDuration(l, Duration(minutes: n.dureeMinutes!)),
            if (n.distanceMetres != null)
              l.distanceNm((n.distanceMetres! / 1852).toStringAsFixed(1)),
            if (n.commeAmi) l.filterFriend,
          ].whereType<String>().join(' · '),
        ),
        trailing: n.enCours ? Text(l.live) : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NavigationSuivieScreen(navigationId: n.id),
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.dashboard)),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final (v, t) in [
                  (null, l.filterAll),
                  ('navigateur', l.filterNavigator),
                  ('ami', l.filterFriend),
                ])
                  ChoiceChip(
                    label: Text(t),
                    selected: role == v,
                    onSelected: (_) {
                      setState(() => role = v);
                      _charger();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (erreur != null) Text(l.followLoadError),
            if (liste == null && erreur == null)
              const Center(child: CircularProgressIndicator()),
            if (liste != null && liste.isEmpty) Text(l.followNoVoyage),
            if (enCours.isNotEmpty) ...[
              Text(
                l.inProgress,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final n in enCours) carte(n),
              const SizedBox(height: 12),
            ],
            if (historique.isNotEmpty) ...[
              Text(l.history, style: Theme.of(context).textTheme.titleMedium),
              for (final n in historique) carte(n),
            ],
            const PiedDePage(),
          ],
        ),
      ),
    );
  }
}

/// Page d'une navigation, en lecture seule : informations, fiche du bateau,
/// carte et tracé, journal avec photos et notes vocales, alertes SOS,
/// amis ; mise à jour pendant une navigation en cours.
class NavigationSuivieScreen extends StatefulWidget {
  const NavigationSuivieScreen({
    super.key,
    required this.navigationId,
    this.pas = const Duration(seconds: 30),
  });
  final String navigationId;
  final Duration? pas;

  @override
  State<NavigationSuivieScreen> createState() => _NavigationSuivieScreenState();
}

class _NavigationSuivieScreenState extends State<NavigationSuivieScreen> {
  SuiviNavigation? suivi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (suivi != null) return;
    final d = DepotScope.of(context) as DepotReel;
    suivi = SuiviNavigation(
      api: d.api,
      navigationId: widget.navigationId,
      pas: widget.pas,
    )..charger();
  }

  @override
  void dispose() {
    suivi?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = suivi!;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final d = s.detail;
        if (s.chargement) {
          return Scaffold(
            appBar: AppBar(),
            body: const PageAvecPied(child: CircularProgressIndicator()),
          );
        }
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: PageAvecPied(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l.followLoadError),
              ),
            ),
          );
        }
        final r = d.resume;
        String info(String t, String? v) => '$t : ${v ?? '—'}';
        final fiche = d.fiche;
        return Scaffold(
          appBar: AppBar(title: Text(r.nom)),
          body: RefreshIndicator(
            onRefresh: s.actualiser,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (r.enCours)
                  Text(
                    l.live,
                    key: const Key('follow-live'),
                    style: const TextStyle(
                      color: NlColors.alert,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(info(l.boat, r.bateauNom)),
                Text(info(l.infoNavigator, d.navigateur?.nom)),
                Text(info(l.infoDeparture, fmtDate(l, r.debut.toLocal()))),
                Text(info(l.infoDeparturePlace, d.lieuDepart)),
                if (d.destination != null)
                  Text(info(l.infoDestination, d.destination)),
                if (r.fin != null) ...[
                  Text(info(l.infoArrival, fmtDate(l, r.fin!.toLocal()))),
                  Text(info(l.infoArrivalPlace, d.lieuArrivee)),
                ],
                if (r.dureeMinutes != null)
                  Text(
                    info(
                      l.infoDuration,
                      fmtDuration(l, Duration(minutes: r.dureeMinutes!)),
                    ),
                  ),
                if (r.distanceMetres != null)
                  Text(
                    info(
                      l.infoDistance,
                      l.distanceNm(
                        (r.distanceMetres! / 1852).toStringAsFixed(1),
                      ),
                    ),
                  ),
                if (d.personnesABord != null)
                  Text(info(l.personsOnBoard, '${d.personnesABord}')),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: CarteSuivi(trace: s.trace, enCours: r.enCours),
                ),
                const SizedBox(height: 16),
                // RG-PAR-08 : fiche du bateau et amis.
                if (fiche != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l.followBoatSheet),
                    children: [
                      for (final (t, k, u) in [
                        (l.boatLength, 'longueurMetres', ' m'),
                        (l.boatRegistration, 'immatriculation', ''),
                        (l.boatHomePort, 'portAttache', ''),
                        (l.boatEngine, 'moteur', ''),
                        (l.boatDraft, 'tirantEauMetres', ' m'),
                      ])
                        if (fiche[k] != null)
                          ListTile(
                            dense: true,
                            title: Text(t),
                            trailing: Text('${fiche[k]}$u'),
                          ),
                    ],
                  ),
                // D-176, D-186 : une seule liste « Amis ».
                if (d.amis.isNotEmpty)
                  ExpansionTile(
                    key: const Key('follow-friends'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '${l.followFollowers} '
                      '(${d.amis.length})',
                    ),
                    children: [
                      for (final p in d.amis)
                        ListTile(
                          dense: true,
                          title: Text(p.nom),
                          subtitle: p.telephone == null
                              ? null
                              : Text(p.telephone!),
                        ),
                    ],
                  ),
                if (s.alertes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.followSosAlerts,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: NlColors.alert),
                  ),
                  for (final a in s.alertes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sos, color: NlColors.alert),
                      title: Text(fmtDate(l, a.heure)),
                      subtitle: Text(
                        [
                          if (a.probleme != null) a.probleme!,
                          if (a.position != null)
                            '${a.position!.latitude.toStringAsFixed(5)}, ${a.position!.longitude.toStringAsFixed(5)}',
                        ].join('\n'),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(l.logbook, style: Theme.of(context).textTheme.titleMedium),
                for (final e in s.journal.reversed)
                  EvenementSuiviTile(evenement: e, suivi: s),
                const PiedDePage(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Carte de la navigation : tracé, dernière position (cahier des charges §6.2),
/// fonds OpenStreetMap et OpenSeaMap.
class CarteSuivi extends StatelessWidget {
  const CarteSuivi({super.key, required this.trace, required this.enCours});
  final List<PositionGps> trace;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pts = [for (final p in trace) LatLng(p.latitude, p.longitude)];
    if (pts.isEmpty) {
      return Center(child: Text(l.followNoPosition));
    }
    final bounds = LatLngBounds.fromPoints(
      pts.length == 1 ? [pts.first, pts.first] : pts,
    );
    Widget point(Color c, {bool anneau = false}) => DecoratedBox(
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: anneau ? Border.all(color: NlColors.white, width: 4) : null,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        key: const Key('follow-map'),
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(36),
            maxZoom: 14,
          ),
          backgroundColor: const Color(0xFFDCEFF8),
        ),
        children: [
          if (SeaMap.tilesEnabled) ...[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.nautilink.nautilink',
            ),
            TileLayer(
              urlTemplate:
                  'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.nautilink.nautilink',
            ),
          ],
          PolylineLayer(
            polylines: [
              Polyline(points: pts, strokeWidth: 3.5, color: NlColors.ink),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: pts.first,
                width: 16,
                height: 16,
                child: point(NlColors.ink),
              ),
              Marker(
                point: pts.last,
                width: 22,
                height: 22,
                child: point(
                  enCours ? NlColors.alert : NlColors.accent,
                  anneau: true,
                ),
              ),
            ],
          ),
          const MentionCarte(),
        ],
      ),
    );
  }
}

/// Mention des fonds de carte, sur toutes les cartes (RG-NAV-29, D-180) :
/// « Fond de carte © les contributeurs d'OpenStreetMap · balisage ©
/// OpenSeaMap », en bas de la carte, sur un fond clair arrondi.
class MentionCarte extends StatelessWidget {
  const MentionCarte({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NlColors.white.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            AppLocalizations.of(context).mapAttribution,
            key: const Key('map-attribution'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: NlColors.ink),
          ),
        ),
      ),
    ),
  );
}

/// Ligne du journal : photo affichée, note vocale à écouter (RG-JRN-03).
class EvenementSuiviTile extends StatefulWidget {
  const EvenementSuiviTile({
    super.key,
    required this.evenement,
    required this.suivi,
  });
  final EvenementSuivi evenement;
  final SuiviNavigation suivi;

  @override
  State<EvenementSuiviTile> createState() => _EvenementSuiviTileState();
}

class _EvenementSuiviTileState extends State<EvenementSuiviTile> {
  Future<dynamic>? photo;
  AudioPlayer? lecteur;
  bool lecture = false;

  @override
  void initState() {
    super.initState();
    final e = widget.evenement;
    if (e.type == 'photo' && e.fichierRecu) {
      photo = widget.suivi.fichier(e.id);
    }
  }

  @override
  void dispose() {
    lecteur?.dispose();
    super.dispose();
  }

  /// Note vocale : fichier lu sur le serveur, écrit dans le cache, puis joué.
  Future<void> _ecouter() async {
    if (lecture) {
      await lecteur?.stop();
      setState(() => lecture = false);
      return;
    }
    final o = await widget.suivi.fichier(widget.evenement.id);
    if (o == null || !mounted) return;
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/vocal-${widget.evenement.id}.m4a');
      await f.writeAsBytes(o);
      final p = lecteur ??= AudioPlayer();
      p.onPlayerComplete.listen((_) {
        if (mounted) setState(() => lecture = false);
      });
      await p.play(DeviceFileSource(f.path));
      if (mounted) setState(() => lecture = true);
    } catch (e) {
      debugPrint('Note vocale : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = widget.evenement;
    final (icone, titre) = switch (e.type) {
      'debut' => (Icons.flag_outlined, l.eventStart),
      'position_automatique' => (Icons.place_outlined, l.eventAutoPosition),
      'position_manuelle' => (Icons.place_outlined, l.eventManualPosition),
      'note' || 'ajout' => (Icons.edit_note, l.eventNote),
      'photo' => (Icons.photo_outlined, l.eventPhoto),
      'note_vocale' => (Icons.mic_none, l.eventVoice),
      'sos' => (Icons.sos, l.eventSos),
      'fin' => (Icons.sports_score, l.eventEnd),
      _ => (Icons.circle_outlined, e.type),
    };
    final p = e.position;
    final details = [
      if (e.texte != null && e.texte!.isNotEmpty) e.texte!,
      if (e.lieu != null) e.lieu!,
      if (p != null)
        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
      if (e.dureeSecondes != null) fmtSeconds(e.dureeSecondes!),
    ];
    final sos = e.type == 'sos';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icone, color: sos ? NlColors.alert : NlColors.teal),
          title: Text(
            '${fmtTime(e.heure)} · $titre',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: sos ? NlColors.alert : null,
            ),
          ),
          subtitle: details.isEmpty ? null : Text(details.join('\n')),
          trailing: e.type == 'note_vocale'
              ? (e.fichierRecu
                    ? TextButton.icon(
                        icon: Icon(lecture ? Icons.stop : Icons.play_arrow),
                        label: Text(lecture ? l.followStop : l.followListen),
                        onPressed: _ecouter,
                      )
                    : null)
              : null,
        ),
        if (e.type == 'photo')
          e.fichierRecu
              ? FutureBuilder<dynamic>(
                  future: photo,
                  builder: (context, snap) => snap.data == null
                      ? const SizedBox(height: 8)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(snap.data, fit: BoxFit.cover),
                        ),
                )
              : Text(l.followFileMissing),
      ],
    );
  }
}
