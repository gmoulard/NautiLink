import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../theme.dart';
import 'dashboard.dart';
import 'home.dart';

/// Écran de démarrage (cahier des charges §5.3).
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int boat = 0;
  int? frequency;
  int? persons;
  Set<String>? alerted;
  final destination = TextEditingController();

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    frequency ??= state.defaultFrequency;
    persons ??= state.lastPersonsOnBoard;
    alerted ??= state.alertable.map((c) => c.name).toSet();
    final sosChecked = state.contacts.any((c) => c.sos && alerted!.contains(c.name));
    return Scaffold(
      appBar: AppBar(title: Text(l.startVoyage)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.boats.length > 1) ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: boat,
              decoration: InputDecoration(labelText: l.boat, border: const OutlineInputBorder()),
              items: [
                for (var i = 0; i < state.boats.length; i++)
                  DropdownMenuItem(value: i, child: Text('${state.boats[i].name} · ${state.boats[i].type}')),
              ],
              onChanged: (v) => setState(() => boat = v ?? 0),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
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
            decoration: InputDecoration(labelText: l.personsOnBoard, border: const OutlineInputBorder()),
            child: Row(
              children: [
                IconButton(
                  tooltip: l.onePersonLess,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: persons! > 1 ? () => setState(() => persons = persons! - 1) : null,
                ),
                Expanded(
                  child: Text(
                    '${persons!}',
                    key: const Key('persons'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: kMonoFont, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: l.onePersonMore,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => persons = persons! + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: frequency,
            decoration: InputDecoration(labelText: l.autoFrequency, border: const OutlineInputBorder()),
            items: [for (final e in frequencies.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => frequency = v),
          ),
          const SizedBox(height: 20),
          // RG-NAV-25 et RG-NAV-26 : personnes alertées, ajout d'un contact.
          Text(l.alertedPersons, style: Theme.of(context).textTheme.titleMedium),
          for (final c in state.alertable)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: alerted!.contains(c.name),
              onChanged: (v) => setState(() => v == true ? alerted!.add(c.name) : alerted!.remove(c.name)),
              title: Text(c.name),
              subtitle: Text([if (c.follower) l.alertedRoleFollower, if (c.sos) l.alertedRoleSos].join(' · ')),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(l.addPerson),
              onPressed: () async {
                final c = await Navigator.of(context).push<Contact>(
                  MaterialPageRoute(builder: (_) => const AddPersonScreen()),
                );
                if (c == null) return;
                state.addContact(c);
                setState(() => alerted!.add(c.name));
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.tune),
              label: Text(l.voyageSettings),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SafeArea(child: SingleChildScrollView(child: SmsSettings(state: state))),
              ),
            ),
          ),
          if (!sosChecked)
            Card(
              color: const Color(0xFFFBE9E9),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: NlColors.alert),
                title: Text(l.noSosChecked),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              state.startVoyage(
                boat: state.boats[boat],
                destination: destination.text.trim(),
                frequency: frequency!,
                persons: persons!,
                alerted: {...alerted!},
              );
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const NavigationScreen()));
            },
            child: Text(l.sendStart),
          ),
        ],
      ),
    );
  }
}

/// Page « Ajouter une personne » : nouveau contact permanent (RG-NAV-26, RG-CTC-01).
class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ok = name.text.trim().isNotEmpty && (phone.text.trim().isNotEmpty || email.text.trim().isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: Text(l.addPerson)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.addPersonText),
          const SizedBox(height: 16),
          TextField(
            key: const Key('add-name'),
            controller: name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.name, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('add-phone'),
            controller: phone,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.phone, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l.email, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text(l.phoneNeededForSos),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ok
                ? () => Navigator.of(context).pop(
                      Contact(
                        name: name.text.trim(),
                        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                        email: email.text.trim().isEmpty ? null : email.text.trim(),
                      ),
                    )
                : null,
            child: Text(l.add),
          ),
        ],
      ),
    );
  }
}

/// Termine la navigation puis ouvre sa page détaillée (RG-NAV-13).
void endAndOpenDetail(BuildContext context) {
  final state = AppScope.of(context);
  final v = state.current;
  if (v == null) return;
  state.endVoyage();
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => VoyageScreen(voyage: v)));
}

/// Écran de navigation en cours (cahier des charges §5.4). Aucune carte (RG-NAV-09).
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Timer? ticker;
  DateTime lastSend = DateTime.now();

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  /// Envoi réussi : remet le chronomètre à zéro (RG-NAV-10) et affiche le
  /// résultat par circuit dans une fenêtre (RG-COM-03).
  Future<void> sent(String what) async {
    setState(() => lastSend = DateTime.now());
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final sms = state.smsEnabled ? l.smsPrefilled : l.smsDisabled;
    await showSendResult(context, what, [l.serverSent, sms, l.nothingReallySent]);
    if (mounted) await proposeEndIfStationary();
  }

  /// RG-NAV-24 : proposer de terminer une navigation immobile depuis 2 heures.
  Future<void> proposeEndIfStationary() async {
    final state = AppScope.of(context);
    if (!state.isStationary()) return;
    final l = AppLocalizations.of(context);
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.voyageEnded),
        content: Text(l.stationaryText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.continueLabel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.endVoyage)),
        ],
      ),
    );
    if (end != true || !mounted) return;
    endAndOpenDetail(context);
  }

  Future<String?> askText(String title, String hint) {
    final c = TextEditingController();
    final l = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLines: 3, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l.validateSend)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final v = state.current;
    if (v == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noVoyageInProgress)));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(v.boat.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.demoMenu,
            onSelected: (_) async {
              state.simulateStationary();
              await proposeEndIfStationary();
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'immobile', child: Text(l.demoStationary))],
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: RadarBackground(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: _Chrono(label: l.sinceStart, value: fmtClock(v.duration))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Chrono(label: l.sinceLastSend, value: fmtClock(DateTime.now().difference(lastSend))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: Text(l.sendPosition),
                    onPressed: () {
                      state.addEvent(EventKind.manualPosition);
                      sent(l.positionSent);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: Text(l.noteButton),
                          onPressed: () async {
                            final t = await askText(l.noteTitle, l.noteHint);
                            if (t == null || t.isEmpty) return;
                            state.addEvent(EventKind.note, text: t);
                            sent(l.noteSent);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(l.photoButton),
                          onPressed: () {
                            state.addEvent(EventKind.photo, text: 'Photo d\'exemple');
                            sent(l.photoSent);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.mic_none),
                          label: Text(l.voiceButton),
                          onPressed: () async {
                            final seconds = await recordVoice(context);
                            if (seconds == null) return;
                            state.addEvent(EventKind.voice, text: 'Enregistrement · ${fmtSeconds(seconds)}');
                            sent(l.voiceSent);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SosButton(onPressed: () => confirmSos(context)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l.endVoyageQuestion),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.end)),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      endAndOpenDetail(context);
                    },
                    child: Text(l.endVoyage),
                  ),
                  const SizedBox(height: 20),
                  Text(l.logbook, style: Theme.of(context).textTheme.titleMedium),
                  for (final e in v.log.reversed) LogTile(event: e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String fmtSeconds(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Note vocale : enregistrement de la voix, 1 minute au plus, sans transcription (RG-JRN-04).
/// Démonstration : l'enregistrement est simulé. Renvoie la durée en secondes, ou null si annulé.
Future<int?> recordVoice(BuildContext context) => showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RecordDialog(),
    );

class _RecordDialog extends StatefulWidget {
  const _RecordDialog();

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  int seconds = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => seconds++);
      if (seconds >= 60) _stop(); // 1 minute au plus
    });
  }

  void _stop() {
    timer?.cancel();
    if (mounted) Navigator.of(context).pop(seconds == 0 ? 1 : seconds);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.mic, color: NlColors.alert, size: 40),
      title: Text(l.recording),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fmtSeconds(seconds), style: const TextStyle(fontFamily: kMonoFont, fontSize: 32, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(l.recordingHint),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            timer?.cancel();
            Navigator.of(context).pop();
          },
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _stop, child: Text(l.stopAndSend)),
      ],
    );
  }
}

class _Chrono extends StatelessWidget {
  const _Chrono({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: kMonoFont,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne du journal : nom du lieu pour les positions (RG-JRN-10), photo en grand
/// et écoute des notes vocales (RG-JRN-09).
class LogTile extends StatelessWidget {
  const LogTile({super.key, required this.event});
  final LogEvent event;

  IconData get icon => switch (event.kind) {
        EventKind.start => Icons.flag_outlined,
        EventKind.autoPosition || EventKind.manualPosition => Icons.place_outlined,
        EventKind.note => Icons.edit_note,
        EventKind.photo => Icons.photo_outlined,
        EventKind.voice => Icons.mic_none,
        EventKind.sos => Icons.sos,
        EventKind.end => Icons.sports_score,
      };

  void _open(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (event.kind == EventKind.photo) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 260,
                width: double.infinity,
                color: const Color(0xFFDCEFF8),
                child: const Icon(Icons.sailing, size: 120, color: NlColors.accent),
              ),
              ListTile(
                title: Text(event.text ?? l.photo),
                subtitle: Text(l.samplePhoto(fmtTime(event.time))),
                trailing: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
              ),
            ],
          ),
        ),
      );
    } else if (event.kind == EventKind.voice) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.play_circle_outline, color: NlColors.accent, size: 44),
          title: Text(l.listenVoice),
          content: Text(l.noSoundRecorded(event.text ?? l.recordingDefault)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = event.kind == EventKind.sos;
    final pos = event.position;
    final details = [event.text, if (pos != null) placeName(pos)].whereType<String>().join('\n');
    final openable = event.kind == EventKind.photo || event.kind == EventKind.voice;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: sos ? NlColors.alert : NlColors.teal),
      title: Text(
        '${fmtTime(event.time)} · ${event.label}',
        style: TextStyle(fontWeight: FontWeight.w600, color: sos ? NlColors.alert : null),
      ),
      subtitle: details.isEmpty ? null : Text(details),
      trailing: openable
          ? Icon(event.kind == EventKind.photo ? Icons.open_in_full : Icons.play_arrow, color: NlColors.accent)
          : null,
      onTap: openable ? () => _open(context) : null,
    );
  }
}

/// Fenêtre de résultat d'un envoi, avec « OK », fermée seule au bout d'une minute (RG-COM-03).
Future<void> showSendResult(BuildContext context, String title, List<String> lines) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SendResultDialog(title: title, lines: lines),
  );
}

class _SendResultDialog extends StatefulWidget {
  const _SendResultDialog({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  State<_SendResultDialog> createState() => _SendResultDialogState();
}

class _SendResultDialogState extends State<_SendResultDialog> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(minutes: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle_outline, color: NlColors.teal, size: 36),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in widget.lines) Text(l)],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(AppLocalizations.of(context).ok))],
    );
  }
}

/// SOS : confirmation avec « Problème rencontré » facultatif, puis résultat simulé
/// (RG-SOS-02, RG-SOS-04, RG-SOS-07).
Future<void> confirmSos(BuildContext context) async {
  final problem = await showDialog<String>(context: context, builder: (_) => const _SosDialog());
  if (problem == null || !context.mounted) return; // annulé
  ScaffoldMessenger.of(context).clearSnackBars(); // rien ne doit masquer l'écran SOS
  final state = AppScope.of(context);
  state.addEvent(EventKind.sos, text: problem.isEmpty ? null : 'Problème : $problem');
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SosResultScreen(problem: problem)));
}

/// Renvoie le problème saisi (chaîne vide si aucun) à la confirmation, null si annulé.
class _SosDialog extends StatefulWidget {
  const _SosDialog();

  @override
  State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  final problem = TextEditingController();

  @override
  void dispose() {
    problem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.sos, color: NlColors.alert, size: 40),
      title: Text(l.sosQuestion),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.sosConfirmText),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sos-problem'),
            controller: problem,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.sosProblem,
              hintText: l.sosProblemHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NlColors.alert, minimumSize: const Size(140, 44)),
          onPressed: () => Navigator.pop(context, problem.text.trim()),
          child: Text(l.sosConfirm),
        ),
      ],
    );
  }
}

class SosResultScreen extends StatelessWidget {
  const SosResultScreen({super.key, this.problem = ''});
  final String problem;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final sosContacts = state.sosContactsNow;
    final v = state.current;
    final boat = v?.boat ?? state.boats.first;
    final persons = v?.personsOnBoard ?? state.lastPersonsOnBoard;
    final pos = v?.track.last ?? state.nextPosition();
    // Contenu du SMS envoyé, pas texte d'interface : reste en français (langue des messages : Q-27).
    final sms = [
      'SOS ${boat.name}, ${boat.type}, ${boat.length}, ${boat.registration}.',
      '$persons personne${persons > 1 ? 's' : ''} à bord.',
      if (problem.isNotEmpty) 'Problème : $problem.',
      'Position ${pos.text} à ${fmtTime(pos.time)}.',
      'https://maps.google.com/?q=${pos.lat.toStringAsFixed(5)},${pos.lon.toStringAsFixed(5)}',
    ].join('\n');
    return Scaffold(
      appBar: AppBar(
        title: Text(l.sosAlert),
        backgroundColor: NlColors.alert,
        foregroundColor: NlColors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const DemoBanner(),
          const SizedBox(height: 12),
          Text(l.sosNoSmsSent, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(sms, key: const Key('sos-sms'), style: const TextStyle(fontFamily: kMonoFont)),
            ),
          ),
          const SizedBox(height: 12),
          for (final c in sosContacts)
            ListTile(
              leading: const Icon(Icons.check_circle, color: NlColors.teal),
              title: Text(c.name),
              subtitle: Text(l.sosSmsAccepted(c.phone ?? '')),
            ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: NlColors.teal),
            title: Text(l.sosCopyNavigator),
            subtitle: Text(l.sosCopyNavigatorDetail),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined, color: NlColors.teal),
            title: Text(l.sosServer),
            subtitle: Text(l.sosServerDetail),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.back)),
        ],
      ),
    );
  }
}
