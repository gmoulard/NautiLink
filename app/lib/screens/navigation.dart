import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
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
  final destination = TextEditingController();

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    frequency ??= state.defaultFrequency;
    return Scaffold(
      appBar: AppBar(title: const Text('Démarrer navigation')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.boats.length > 1) ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: boat,
              decoration: const InputDecoration(
                labelText: 'Bateau',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var i = 0; i < state.boats.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${state.boats[i].name} · ${state.boats[i].type}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => boat = v ?? 0),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: destination,
            decoration: const InputDecoration(
              labelText: 'Destination (facultative)',
              hintText: 'Adresse ou lieu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: frequency,
            decoration: const InputDecoration(
              labelText: 'Fréquence d\'envoi automatique',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in frequencies.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => frequency = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Paramètres de cette navigation'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SafeArea(
                  child: SingleChildScrollView(
                    child: SmsSettings(state: state),
                  ),
                ),
              ),
            ),
          ),
          if (!state.contacts.any((c) => c.sos))
            const Card(
              color: Color(0xFFFBE9E9),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: NlColors.alert),
                title: Text(
                  'Aucun contact SOS : personne ne recevra vos SMS SOS.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              state.startVoyage(
                boat: state.boats[boat],
                destination: destination.text.trim(),
                frequency: frequency!,
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const NavigationScreen()),
              );
            },
            child: const Text('Envoi message – Début de navigation'),
          ),
        ],
      ),
    );
  }
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
    final sms = state.smsEnabled
        ? 'SMS prérempli pour vos suiveurs'
        : 'SMS désactivés';
    await showSendResult(context, what, [
      'Serveur : envoyé',
      sms,
      '(démonstration : rien n\'est réellement envoyé)',
    ]);
    if (mounted) await proposeEndIfStationary();
  }

  /// RG-NAV-24 : proposer de terminer une navigation immobile depuis 2 heures.
  Future<void> proposeEndIfStationary() async {
    final state = AppScope.of(context);
    if (!state.isStationary()) return;
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Navigation terminée ?'),
        content: const Text(
          'Vous ne vous êtes pas éloigné de plus de 20 mètres depuis 2 heures.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer la navigation'),
          ),
        ],
      ),
    );
    if (end != true || !mounted) return;
    state.endVoyage();
    Navigator.of(context).pop();
  }

  Future<String?> askText(String title, String hint) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Valider l\'envoi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final v = state.current;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Aucune navigation en cours.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(v.boat.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Démonstration',
            onSelected: (_) async {
              state.simulateStationary();
              await proposeEndIfStationary();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'immobile',
                child: Text('Démo : simuler 2 h sans bouger'),
              ),
            ],
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
                      Expanded(
                        child: _Chrono(
                          label: 'Depuis le début',
                          value: fmtClock(v.duration),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Chrono(
                          label: 'Depuis le dernier envoi',
                          value: fmtClock(DateTime.now().difference(lastSend)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Envoyer information position'),
                    onPressed: () {
                      state.addEvent(EventKind.manualPosition);
                      sent('Position envoyée');
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: const Text('NOTE'),
                          onPressed: () async {
                            final t = await askText('Note', 'Votre note');
                            if (t == null || t.isEmpty) return;
                            state.addEvent(EventKind.note, text: t);
                            sent('Note envoyée');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Photo'),
                          onPressed: () {
                            state.addEvent(
                              EventKind.photo,
                              text: 'Photo d\'exemple',
                            );
                            sent('Photo envoyée');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.mic_none),
                          label: const Text('Vocal'),
                          onPressed: () async {
                            final t = await askText(
                              'Note vocale',
                              'Transcription de la dictée, à corriger',
                            );
                            if (t == null || t.isEmpty) return;
                            state.addEvent(EventKind.voice, text: t);
                            sent('Note vocale envoyée');
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
                          title: const Text('Terminer la navigation ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Terminer'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      state.endVoyage();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Terminer la navigation'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Journal de bord',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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

  @override
  Widget build(BuildContext context) {
    final sos = event.kind == EventKind.sos;
    final details = [
      event.text,
      event.position?.text,
    ].whereType<String>().join('\n');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: sos ? NlColors.alert : NlColors.teal),
      title: Text(
        '${fmtTime(event.time)} · ${event.label}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: sos ? NlColors.alert : null,
        ),
      ),
      subtitle: details.isEmpty ? null : Text(details),
    );
  }
}

/// Fenêtre de résultat d'un envoi, avec « OK », fermée seule au bout d'une minute (RG-COM-03).
Future<void> showSendResult(
  BuildContext context,
  String title,
  List<String> lines,
) {
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
      icon: const Icon(
        Icons.check_circle_outline,
        color: NlColors.teal,
        size: 36,
      ),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in widget.lines) Text(l)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// SOS : confirmation puis résultat simulé (RG-SOS-02, RG-SOS-04).
Future<void> confirmSos(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.sos, color: NlColors.alert, size: 40),
      title: const Text('Envoyer un SOS ?'),
      content: const Text(
        'Vos contacts SOS recevront votre position et la fiche du bateau. Alertez aussi les secours : canal 16 de la VHF ou 196.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NlColors.alert,
            minimumSize: const Size(140, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirmer le SOS'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  ScaffoldMessenger.of(context)
      .clearSnackBars(); // rien ne doit masquer l'écran SOS
  final state = AppScope.of(context);
  state.addEvent(EventKind.sos);
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SosResultScreen()));
}

class SosResultScreen extends StatelessWidget {
  const SosResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sosContacts = state.contacts.where((c) => c.sos).toList();
    final boat = state.current?.boat ?? state.boats.first;
    final pos = state.current?.track.last ?? state.nextPosition();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerte SOS'),
        backgroundColor: NlColors.alert,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const DemoBanner(),
          const SizedBox(height: 12),
          Text(
            'Démonstration : aucun SMS n\'est réellement parti.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'SOS ${boat.name}, ${boat.type}, ${boat.length}, ${boat.registration}.\n'
                'Position ${pos.text} à ${fmtTime(pos.time)}.\n'
                'https://maps.google.com/?q=${pos.lat.toStringAsFixed(5)},${pos.lon.toStringAsFixed(5)}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final c in sosContacts)
            ListTile(
              leading: const Icon(Icons.check_circle, color: NlColors.teal),
              title: Text(c.name),
              subtitle: Text('SMS SOS accepté pour envoi · ${c.phone}'),
            ),
          const ListTile(
            leading: Icon(Icons.check_circle, color: NlColors.teal),
            title: Text('Copie au navigateur'),
            subtitle: Text('SMS et e-mail en copie (RG-SMS-08, RG-NOT-03)'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_done_outlined, color: NlColors.teal),
            title: Text('Serveur'),
            subtitle: Text('Alerte reçue · e-mail aux suiveurs'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
