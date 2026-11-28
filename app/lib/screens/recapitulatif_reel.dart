import 'package:flutter/material.dart';

import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/conduite.dart';
import '../reel/depot_reel.dart';
import '../reel/suivi.dart';
import 'navigation_reel.dart' show EvenementTile;
import 'pied.dart';
import 'suivi_reel.dart';

/// Récapitulatif de la navigation terminée, dans l'application, après le
/// message d'envoi de « Terminer la navigation » (RG-NAV-13, D-190) : titre
/// (bateau — destination), fiche, carte du tracé, journal de bord, et
/// « Retour à l'accueil ». Avec la fin reçue par le serveur, il est fait
/// d'après la page de la navigation du serveur ; sinon (sans Internet,
/// RG-NAV-14, ou serveur injoignable), avec les données du téléphone.
class RecapitulatifScreen extends StatefulWidget {
  const RecapitulatifScreen({
    super.key,
    required this.navigation,
    required this.fin,
    this.positionFin,
    this.finRecue = false,
  });

  /// Navigation telle que le téléphone la tenait avant la fin.
  final NavigationLocale navigation;

  /// Heure de la fin enregistrée sur le téléphone.
  final DateTime fin;
  final PositionGps? positionFin;

  /// Le serveur a reçu la fin : le récapitulatif se lit sur le serveur.
  final bool finRecue;

  @override
  State<RecapitulatifScreen> createState() => _RecapitulatifScreenState();
}

class _RecapitulatifScreenState extends State<RecapitulatifScreen> {
  SuiviNavigation? suivi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (suivi != null || !widget.finRecue) return;
    final d = DepotScope.of(context) as DepotReel;
    suivi = SuiviNavigation(
      api: d.api,
      navigationId: widget.navigation.id,
      pas: null,
    )..charger();
  }

  @override
  void dispose() {
    suivi?.dispose();
    super.dispose();
  }

  /// Journal du téléphone, fin comprise (absente de la copie locale).
  List<EvenementLocal> get _journalLocal => [
    ...widget.navigation.journal,
    EvenementLocal(
      id: 'fin',
      type: 'fin',
      heure: widget.fin,
      position: widget.positionFin,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = suivi;
    if (s == null) return _page(context, null);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (s.chargement) {
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: false),
            body: const PageAvecPied(child: CircularProgressIndicator()),
          );
        }
        return _page(context, s.detail == null ? null : s);
      },
    );
  }

  /// [s] vide : récapitulatif fait avec les données du téléphone.
  Widget _page(BuildContext context, SuiviNavigation? s) {
    final l = AppLocalizations.of(context);
    final n = widget.navigation;
    final d = s?.detail;
    String info(String t, String? v) => '$t : ${v ?? '—'}';
    String? coordonnees(PositionGps? p) => p == null
        ? null
        : '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

    final bateau = d?.resume.bateauNom ?? n.bateauNom;
    final destination = d?.destination ?? n.destination;
    final titre = destination == null || destination.isEmpty
        ? (d?.resume.nom ?? n.nom)
        : '$bateau — $destination';
    final traceLocale = [
      for (final e in _journalLocal)
        if (e.position != null) e.position!,
    ];
    final trace = s?.trace ?? traceLocale;
    final duree = d?.resume.dureeMinutes != null
        ? Duration(minutes: d!.resume.dureeMinutes!)
        : widget.fin.difference(d?.resume.debut ?? n.debut);
    var distance = d?.resume.distanceMetres;
    if (distance == null) {
      distance = 0;
      for (var i = 1; i < trace.length; i++) {
        distance =
            distance! +
            ConduiteNavigation.distanceMetres(trace[i - 1], trace[i]);
      }
    }
    final meteoDepart = d?.meteoDepart;
    final meteoArrivee = d?.meteoArrivee;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(titre, key: const Key('recap-title')),
      ),
      body: ListView(
        key: const Key('recap'),
        padding: const EdgeInsets.all(16),
        children: [
          if (s == null) ...[
            Text(
              l.recapOffline,
              key: const Key('recap-offline'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          Text(info(l.boat, bateau)),
          Text(
            info(l.personsOnBoard, '${d?.personnesABord ?? n.personnesABord}'),
          ),
          if (d?.chefDeBord != null) Text(info(l.recapSkipper, d!.chefDeBord)),
          Text(
            info(
              l.infoDeparture,
              fmtDate(l, (d?.resume.debut ?? n.debut).toLocal()),
            ),
          ),
          Text(
            info(
              l.infoDeparturePlace,
              d?.lieuDepart ?? coordonnees(traceLocale.firstOrNull),
            ),
          ),
          if (meteoDepart != null)
            Text(info(l.infoWeatherStart, texteMeteo(l, meteoDepart))),
          if (meteoArrivee != null)
            Text(info(l.infoWeatherEnd, texteMeteo(l, meteoArrivee))),
          Text(info(l.infoDuration, fmtDuration(l, duree))),
          Text(
            info(
              l.infoDistance,
              l.distanceNm((distance! / 1852).toStringAsFixed(1)),
            ),
          ),
          if (trace.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: CarteSuivi(trace: trace, enCours: false),
            ),
          ],
          const SizedBox(height: 16),
          Text(l.logbook, style: Theme.of(context).textTheme.titleMedium),
          if (s != null)
            for (final e in s.journal.reversed)
              EvenementSuiviTile(evenement: e, suivi: s)
          else
            for (final e in _journalLocal.reversed) EvenementTile(evenement: e),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('recap-home'),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Text(l.recapBackHome),
          ),
          const PiedDePage(),
        ],
      ),
    );
  }
}

/// Météo d'une navigation (schéma `Meteo`, RG-NAV-28) en une ligne :
/// « vent 12 nœuds (270°) · mer peu agitée · 1015 hPa ».
String texteMeteo(AppLocalizations l, Map<String, Object?> m) {
  if (m['indisponible'] == true) return l.weatherUnavailable;
  final vent = m['ventVitesseNoeuds'] as num?;
  final direction = m['ventDirectionDegres'] as num?;
  final pression = m['pressionHpa'] as num?;
  final mer = m['etatMer'] as String?;
  final parties = [
    if (vent != null)
      l.weatherWind(vent.round().toString()) +
          (direction == null ? '' : ' (${direction.round()}°)'),
    if (mer != null) l.weatherSea(mer),
    if (pression != null) '${pression.round()} hPa',
  ];
  return parties.isEmpty ? l.weatherUnavailable : parties.join(' · ');
}
