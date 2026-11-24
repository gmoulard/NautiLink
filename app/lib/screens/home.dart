import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
import 'dashboard.dart';
import 'navigation.dart';

/// Écran d'accueil de l'application mobile (cahier des charges §5.2).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final left = AppState.quotaMinutes - state.usedMinutes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NautiLink'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              final page = switch (v) {
                'contacts' => const ContactsScreen(),
                'params' => const SettingsScreen(),
                'quota' => const QuotaScreen(),
                _ => const DashboardScreen(),
              };
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'contacts', child: Text('Contacts')),
              PopupMenuItem(value: 'params', child: Text('Paramètres')),
              PopupMenuItem(value: 'quota', child: Text('Quota et abonnement')),
              PopupMenuItem(value: 'web', child: Text('Tableau de bord (Web)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined, color: NlColors.teal),
                    title: Text('${fmtDuration(Duration(minutes: left))} de navigation gratuite disponibles'),
                    subtitle: const Text('sur les 7 derniers jours glissants'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuotaScreen())),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: state.current != null ? null : () => openStart(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Démarrer navigation'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.current == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NavigationScreen())),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reprendre la dernière navigation'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen(onlyMine: true))),
                  icon: const Icon(Icons.history),
                  label: const Text('Navigations enregistrées'),
                ),
                const SizedBox(height: 32),
                SosButton(onPressed: () => confirmSos(context)),
                const SizedBox(height: 8),
                Text(
                  'En cas de détresse, alertez d\'abord par le canal 16 de la VHF ou le 196.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openStart(BuildContext context) async {
  final state = AppScope.of(context);
  if (!state.firstVoyageReminderSeen) {
    // Rappel avant la première navigation sur ce téléphone (RG-NAV-23).
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Avant votre première navigation'),
        content: const Text(
          'NautiLink est en version bêta et n\'est pas un équipement de sécurité. '
          'En cas de détresse, alertez d\'abord les secours par le canal 16 de la VHF ou le 196.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    state.seeFirstReminder();
  }
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StartScreen()));
}

/// Contacts : une seule liste, cases « Suiveur » et « Contact SOS » (RG-CTC-01).
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Par défaut, chaque contact est à la fois suiveur et contact SOS.'),
          const SizedBox(height: 12),
          for (final c in state.contacts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text([c.phone, c.email].whereType<String>().join(' · ')),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Suiveur'),
                            value: c.follower,
                            onChanged: (v) {
                              c.follower = v ?? false;
                              state.touch();
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Contact SOS'),
                            subtitle: c.phone == null ? const Text('Numéro requis') : null,
                            value: c.sos,
                            onChanged: c.phone == null
                                ? null
                                : (v) {
                                    c.sos = v ?? false;
                                    state.touch();
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paramètres généraux (RG-PRM-01, RG-SMS-02).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: state.defaultFrequency,
            decoration: const InputDecoration(labelText: 'Fréquence par défaut', border: OutlineInputBorder()),
            items: [for (final e in frequencies.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) {
              state.defaultFrequency = v ?? state.defaultFrequency;
              state.touch();
            },
          ),
          const SizedBox(height: 16),
          SmsSettings(state: state),
          const SizedBox(height: 8),
          const Text('Les SMS SOS partent toujours, quels que soient ces réglages.'),
        ],
      ),
    );
  }
}

class SmsSettings extends StatelessWidget {
  const SmsSettings({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('SMS activés', style: TextStyle(fontWeight: FontWeight.w700)),
          value: state.smsEnabled,
          onChanged: (v) {
            state.smsEnabled = v;
            state.touch();
          },
        ),
        for (final k in state.smsByType.keys)
          SwitchListTile(
            title: Text(k),
            value: state.smsByType[k]!,
            onChanged: state.smsEnabled
                ? (v) {
                    state.smsByType[k] = v;
                    state.touch();
                  }
                : null,
          ),
      ],
    );
  }
}

/// Quota et abonnement (RG-ECO-09).
class QuotaScreen extends StatelessWidget {
  const QuotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final used = state.usedMinutes.clamp(0, AppState.quotaMinutes);
    final ratio = used / AppState.quotaMinutes;
    return Scaffold(
      appBar: AppBar(title: const Text('Quota et abonnement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Navigation gratuite : 24 h sur les 7 derniers jours glissants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: ratio, minHeight: 14, borderRadius: BorderRadius.circular(7)),
          const SizedBox(height: 12),
          Text('Consommé : ${fmtDuration(Duration(minutes: used))}'),
          Text('Disponible : ${fmtDuration(Duration(minutes: AppState.quotaMinutes - used))}'),
          const SizedBox(height: 8),
          const Text('Prochaines minutes récupérables : 3 h 40 min dans 4 jours (navigation du début de semaine).'),
          const SizedBox(height: 24),
          const Card(
            child: ListTile(
              title: Text('Abonnement'),
              subtitle: Text('Navigation sans limite, au mois ou à l\'année. Prix à venir. Suivre et consulter l\'historique restent gratuits.'),
            ),
          ),
        ],
      ),
    );
  }
}
