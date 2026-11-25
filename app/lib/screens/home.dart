import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final left = AppState.quotaMinutes - state.usedMinutes;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              final page = switch (v) {
                'contacts' => const ContactsScreen(),
                'params' => const SettingsScreen(),
                'quota' => const QuotaScreen(),
                _ => const DashboardScreen(),
              };
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => page));
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'contacts', child: Text(l.menuContacts)),
              PopupMenuItem(value: 'params', child: Text(l.menuSettings)),
              PopupMenuItem(value: 'quota', child: Text(l.menuQuota)),
              PopupMenuItem(value: 'web', child: Text(l.menuDashboard)),
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
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.timer_outlined,
                        color: NlColors.teal,
                      ),
                      // RG-ECO-10 : lien vers « Quota et abonnement ».
                      title: Text(
                        l.homeFreeVersion,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      subtitle: Text(
                        l.homeFreeLeft(fmtDuration(l, Duration(minutes: left))),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QuotaScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: state.current != null
                        ? null
                        : () => openStart(context),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l.startVoyage),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.current == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NavigationScreen(),
                            ),
                          ),
                    icon: const Icon(Icons.restore),
                    label: Text(l.resumeVoyage),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(onlyMine: true),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: Text(l.savedVoyages),
                  ),
                  const SizedBox(height: 32),
                  SosButton(onPressed: () => confirmSos(context)),
                  const SizedBox(height: 8),
                  Text(
                    l.homeDistressHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  // TODO-3.12 : mémo sécurité du site, ouvert dans le navigateur (vraie application : intégré, RG-SOS-22).
                  TextButton.icon(
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: Text(l.homeSecurityMemo),
                    onPressed: () => launchUrl(
                      Uri.parse(securityMemoUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SponsorFooter(),
        ],
      ),
    );
  }
}

Future<void> openStart(BuildContext context) async {
  final state = AppScope.of(context);
  final l = AppLocalizations.of(context);
  if (!state.firstVoyageReminderSeen) {
    // Rappel avant la première navigation sur ce téléphone (RG-NAV-23).
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
    state.seeFirstReminder();
  }
  if (!context.mounted) return;
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const StartScreen()));
}

/// Contacts : une seule liste, cases « Suiveur » et « Contact SOS » (RG-CTC-01).
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuContacts)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.contactsDefault),
          const SizedBox(height: 12),
          for (final c in state.contacts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text([c.phone, c.email].whereType<String>().join(' · ')),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(l.roleFollower),
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
                            title: Text(l.roleSos),
                            subtitle: c.phone == null
                                ? Text(l.phoneRequired)
                                : null,
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: state.defaultFrequency,
            decoration: InputDecoration(
              labelText: l.defaultFrequency,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final f in frequencies)
                DropdownMenuItem(value: f, child: Text(frequencyLabel(l, f))),
            ],
            onChanged: (v) {
              state.defaultFrequency = v ?? state.defaultFrequency;
              state.touch();
            },
          ),
          const SizedBox(height: 16),
          SmsSettings(state: state),
          const SizedBox(height: 8),
          Text(l.sosAlwaysSent),
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
          title: Text(
            AppLocalizations.of(context).smsEnabled,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          value: state.smsEnabled,
          onChanged: (v) {
            state.smsEnabled = v;
            state.touch();
          },
        ),
        for (final k in state.smsByType.keys)
          SwitchListTile(
            title: Text(smsTypeLabel(AppLocalizations.of(context), k)),
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuQuota)),
      body: RadarBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l.quotaHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 14,
              borderRadius: BorderRadius.circular(7),
            ),
            const SizedBox(height: 12),
            Text(l.quotaUsed(fmtDuration(l, Duration(minutes: used)))),
            Text(
              l.quotaLeft(
                fmtDuration(l, Duration(minutes: AppState.quotaMinutes - used)),
              ),
            ),
            const SizedBox(height: 8),
            Text(l.quotaNextRecovery),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                title: Text(l.subscriptionTitle),
                subtitle: Text(l.subscriptionText),
              ),
            ),
            const SizedBox(height: 12),
            // RG-ECO-10 : page d'information sur l'abonnement du site.
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(l.subscriptionMore),
              onPressed: () => launchUrl(
                Uri.parse(subscriptionInfoUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
