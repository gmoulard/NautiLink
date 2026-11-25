import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/conduite.dart';
import '../reel/depot_reel.dart';
import '../reel/file_attente.dart';
import '../reel/gps.dart';
import '../theme.dart';
import 'connexion.dart';
import 'home.dart';
import 'navigation.dart';

/// Écrans de la navigation de la vraie application (D-127) : mêmes écrans que
/// la démonstration (`navigation.dart`), branchés sur le serveur par
/// [ConduiteNavigation] et la file d'attente.

DepotReel _depot(BuildContext context) => DepotScope.of(context) as DepotReel;

/// Résultat de chaque circuit d'un envoi, affiché dans la fenêtre « OK »
/// (RG-COM-03). Le circuit SMS n'est pas encore réalisé (TODO-5.4) ; il
/// n'existe pas sur iPhone (RG-IOS-02).
List<String> lignesResultat(
  AppLocalizations l,
  EtatEnvoi etat, {
  bool sms = true,
}) => [
  if (etat.refuse)
    l.voyageRefused(
      etat.refus!.message.isEmpty ? l.errorGeneric : etat.refus!.message,
    )
  else
    etat.recu ? l.serverSent : l.serverQueued,
  if (sms && DepotReel.plateformeDuTelephone() != 'ios') l.smsNotYet,
];

// ---------------------------------------------------------------- démarrage

/// « Démarrer navigation » de la vraie application : rappel avant la première
/// navigation sur ce téléphone (RG-NAV-23), puis écran de démarrage.
Future<void> openStartReel(BuildContext context) async {
  final depot = _depot(context);
  final l = AppLocalizations.of(context);
  if (!depot.session.rappelPremiereNavigationVu) {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.firstVoyageTitle),
        content: Text(l.firstVoyageText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.understood),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await depot.session.voirRappelPremiereNavigation();
  }
  final bateaux = await depot.bateauxDuTelephone();
  if (!context.mounted) return;
  if (bateaux.isEmpty) {
    // Compte sans bateau : la fiche se crée sur le Web (Q-81, Q-88).
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.noBoatYet),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
    return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => StartReelScreen(bateaux: bateaux)));
}

/// Écran de démarrage (cahier des charges §5.3) de la vraie application.
class StartReelScreen extends StatefulWidget {
  const StartReelScreen({super.key, required this.bateaux});
  final List<BateauNl> bateaux;

  @override
  State<StartReelScreen> createState() => _StartReelScreenState();
}

class _StartReelScreenState extends State<StartReelScreen> {
  int bateau = 0;
  int? frequence;
  int? personnes;
  Set<String>? alertees;
  Map<String, bool>? smsParType;
  bool? smsActifs;
  bool envoi = false;
  final destination = TextEditingController();

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  List<ContactNl> _alertables(Depot d) =>
      d.contacts.where((c) => c.suiveur || c.contactSos).toList();

  /// Paramètres de cette navigation seulement (RG-NAV-06) : copie des
  /// paramètres généraux, modifiée par « Paramètres de cette navigation ».
  ParametresGeneraux? _parametres(Depot d) {
    final p = d.parametres;
    if (p == null && smsActifs == null) return null;
    return ParametresGeneraux(
      smsActifs: smsActifs ?? p?.smsActifs ?? true,
      smsParType: {...?p?.smsParType, ...?smsParType},
      photoEnMms: p?.photoEnMms ?? false,
      frequenceParDefaut: p?.frequenceParDefaut ?? 30,
    );
  }

  static const _typesSms = {
    'debut': SmsType.start,
    'positionsAutomatiques': SmsType.autoPosition,
    'positionsManuelles': SmsType.manualPosition,
    'notes': SmsType.note,
    'photos': SmsType.photo,
    'notesVocales': SmsType.voice,
    'fin': SmsType.end,
  };

  Future<void> _reglages(Depot d) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final p = _parametres(d);
          final actifs = p?.smsActifs ?? true;
          void changer(void Function() f) {
            setState(f);
            setSheet(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      l.smsEnabled,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: actifs,
                    onChanged: (v) => changer(() => smsActifs = v),
                  ),
                  for (final e in _typesSms.entries)
                    SwitchListTile(
                      title: Text(smsTypeLabel(l, e.value)),
                      value: p?.smsParType[e.key] ?? true,
                      onChanged: actifs
                          ? (v) => changer(() => (smsParType ??= {})[e.key] = v)
                          : null,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.sosAlwaysSent),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Explication avant la demande d'autorisation de localisation (RG-AND-02).
  Future<void> _expliquerPosition() async {
    final l = AppLocalizations.of(context);
    final gps = _depot(context).positions;
    if (gps is! GpsTelephone || await gps.autorisee() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.my_location, color: NlColors.teal, size: 36),
        title: Text(l.locationTitle),
        content: Text(l.locationExplain),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
  }

  Future<void> _demarrer() async {
    final depot = _depot(context);
    final l = AppLocalizations.of(context);
    setState(() => envoi = true);
    try {
      await _expliquerPosition();
      final n = await depot.demarrer(
        bateau: widget.bateaux[bateau],
        frequenceMinutes: frequence!,
        personnesABord: personnes!,
        personnesAlertees: alertees!.toList(),
        destination: destination.text,
        parametres: _parametres(depot),
      );
      if (!mounted) return;
      final etat = await depot.file.etat('demarrage:${n.id}');
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NavigationReelScreen(
            resultat: (l.voyageStarted, lignesResultat(l, etat)),
          ),
        ),
      );
    } on RefusDemarrage catch (r) {
      if (mounted) await _refus(r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(messageErreur(l, e))));
    } finally {
      if (mounted) setState(() => envoi = false);
    }
  }

  /// Démarrage refusé : quota épuisé (RG-ECO-04, avec l'heure du retour des
  /// minutes et l'abonnement) ou message du serveur.
  Future<void> _refus(RefusDemarrage r) {
    final l = AppLocalizations.of(context);
    final quand = r.disponibleLe;
    final texte = r.quotaEpuise
        ? (quand == null
              ? l.startQuotaExhaustedNoDate
              : l.startQuotaExhausted(fmtDate(l, quand.toLocal())))
        : (r.erreur?.message.isNotEmpty == true
              ? r.erreur!.message
              : l.errorGeneric);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.startRefused),
        content: Text(texte, key: const Key('start-refused')),
        actions: [
          if (r.quotaEpuise)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const QuotaScreen()));
              },
              child: Text(l.menuQuota),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depot = _depot(context);
    final l = AppLocalizations.of(context);
    final alertables = _alertables(depot);
    frequence ??= depot.parametres?.frequenceParDefaut ?? 30;
    if (!frequencies.contains(frequence)) frequence = 30;
    personnes ??= depot.session.dernierNombrePersonnes;
    alertees ??= {for (final c in alertables) c.id};
    final aucunSos = !depot.contacts.any((c) => c.contactSos);
    final sosCoche = alertables.any(
      (c) => c.contactSos && alertees!.contains(c.id),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.startVoyage)),
      body: Column(
        children: [
          const BetaBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // RG-NAV-02 : pas de choix avec un seul bateau.
                if (widget.bateaux.length > 1) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: bateau,
                    decoration: InputDecoration(
                      labelText: l.boat,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < widget.bateaux.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(widget.bateaux[i].nom),
                        ),
                    ],
                    onChanged: (v) => setState(() => bateau = v ?? 0),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(
                    '${l.boat} : ${widget.bateaux.first.nom}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                // RG-NAV-04 : destination facultative, en texte (carte : TODO).
                TextField(
                  key: const Key('start-destination'),
                  controller: destination,
                  decoration: InputDecoration(
                    labelText: l.destinationOptional,
                    hintText: l.destinationHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // RG-NAV-27 : nombre de personnes à bord, repris dans le SOS.
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l.personsOnBoard,
                    border: const OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l.onePersonLess,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: personnes! > 1
                            ? () => setState(() => personnes = personnes! - 1)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '${personnes!}',
                          key: const Key('persons'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kMonoFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.onePersonMore,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () =>
                            setState(() => personnes = personnes! + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // RG-NAV-05 : fréquence préremplie par les paramètres généraux.
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: frequence,
                  decoration: InputDecoration(
                    labelText: l.autoFrequency,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in frequencies)
                      DropdownMenuItem(
                        value: f,
                        child: Text(frequencyLabel(l, f)),
                      ),
                  ],
                  onChanged: (v) => setState(() => frequence = v),
                ),
                const SizedBox(height: 20),
                // RG-NAV-25 : personnes alertées, toutes cochées.
                Text(
                  l.alertedPersons,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (alertables.isEmpty) Text(l.noAlertablePerson),
                for (final c in alertables)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: alertees!.contains(c.id),
                    onChanged: (v) => setState(
                      () => v == true
                          ? alertees!.add(c.id)
                          : alertees!.remove(c.id),
                    ),
                    title: Text(c.nom),
                    subtitle: Text(
                      [
                        if (c.suiveur) l.alertedRoleFollower,
                        if (c.contactSos) l.alertedRoleSos,
                      ].join(' · '),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(l.voyageSettings),
                    onPressed: () => _reglages(depot),
                  ),
                ),
                // RG-SOS-14, RG-NAV-25 : avertissement sans contact SOS.
                if (aucunSos || !sosCoche)
                  Card(
                    color: const Color(0xFFFBE9E9),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: NlColors.alert,
                      ),
                      title: Text(aucunSos ? l.noSosContact : l.noSosChecked),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: envoi ? null : _demarrer,
                  child: envoi
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.sendStart),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- navigation

/// Écran de navigation en cours (cahier des charges §5.4) de la vraie
/// application. Aucune carte (RG-NAV-09).
class NavigationReelScreen extends StatefulWidget {
  const NavigationReelScreen({super.key, this.resultat});

  /// Résultat du démarrage à afficher à l'ouverture (RG-COM-03).
  final (String, List<String>)? resultat;

  @override
  State<NavigationReelScreen> createState() => _NavigationReelScreenState();
}

class _NavigationReelScreenState extends State<NavigationReelScreen> {
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    final r = widget.resultat;
    if (r != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSendResult(context, r.$1, r.$2);
      });
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depot = _depot(context);
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: depot.conduite,
      builder: (context, _) {
        final n = depot.conduite.enCours;
        if (n == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l.noVoyageInProgress)),
          );
        }
        final maintenant = depot.conduite.maintenant;
        final refus = n.refus;
        return Scaffold(
          appBar: AppBar(title: Text(n.bateauNom)),
          body: Column(
            children: [
              BetaBanner(
                detail: depot.horsConnexion
                    ? l.offlineSince(
                        depot.actualiseLe == null
                            ? '—'
                            : fmtDate(l, depot.actualiseLe!),
                      )
                    : null,
              ),
              Expanded(
                child: RadarBackground(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        n.nom,
                        key: const Key('voyage-name'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (refus != null)
                        Card(
                          color: const Color(0xFFFBE9E9),
                          child: ListTile(
                            leading: const Icon(
                              Icons.error_outline,
                              color: NlColors.alert,
                            ),
                            title: Text(l.voyageRefused(refus)),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Chrono(
                              label: l.sinceStart,
                              value: fmtClock(maintenant.difference(n.debut)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // RG-NAV-10 : remis à zéro par tout envoi reçu.
                          Expanded(
                            child: Chrono(
                              key: const Key('since-last-send'),
                              label: l.sinceLastSend,
                              value: fmtClock(
                                maintenant.difference(
                                  n.dernierEnvoi ?? n.debut,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (refus == null &&
                          depot.conduite.prochaineAutomatique != null) ...[
                        const SizedBox(height: 8),
                        // RG-GPS-03 : positions automatiques à la fréquence choisie.
                        Text(
                          l.nextAutoPosition(
                            fmtTime(depot.conduite.prochaineAutomatique!),
                          ),
                          key: const Key('next-auto-position'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        l.logbook,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final e in n.journal.reversed)
                        EvenementTile(evenement: e),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ligne du journal tenu sur le téléphone ; les noms de lieux viennent du
/// serveur (RG-JRN-10) et se lisent sur la page Web de la navigation.
class EvenementTile extends StatelessWidget {
  const EvenementTile({super.key, required this.evenement});
  final EvenementLocal evenement;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = evenement;
    final (icone, titre) = switch (e.type) {
      'debut' => (Icons.flag_outlined, l.eventStart),
      'position_automatique' => (Icons.place_outlined, l.eventAutoPosition),
      'position_manuelle' => (Icons.place_outlined, l.eventManualPosition),
      'note' => (Icons.edit_note, l.eventNote),
      'photo' => (Icons.photo_outlined, l.eventPhoto),
      'note_vocale' => (Icons.mic_none, l.eventVoice),
      'sos' => (Icons.sos, l.eventSos),
      'fin' => (Icons.sports_score, l.eventEnd),
      _ => (Icons.circle_outlined, e.type),
    };
    final p = e.position;
    final positionnable = const {
      'debut',
      'position_automatique',
      'position_manuelle',
      'sos',
      'fin',
    }.contains(e.type);
    final details = [
      if (e.texte != null && e.texte!.isNotEmpty) e.texte!,
      if (e.dureeSecondes != null) fmtSeconds(e.dureeSecondes!),
      if (p != null)
        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
      else if (positionnable)
        l.gpsUnavailable,
    ];
    final sos = e.type == 'sos';
    return ListTile(
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
    );
  }
}
