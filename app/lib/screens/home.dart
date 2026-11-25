import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../reel/depot_reel.dart';
import '../theme.dart';
import 'connexion.dart';
import 'dashboard.dart';
import 'memo.dart';
import 'navigation.dart';
import 'navigation_reel.dart';

/// Écran d'accueil de l'application mobile (cahier des charges §5.2).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final depot = DepotScope.of(context);
    final l = AppLocalizations.of(context);
    final demo = depot.demonstration;
    final quota = depot.quota;
    final enCours = depot.navigationEnCours;
    final profil = depot.profil;
    final quotaRecu = quota?.recuLe;
    final list = ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (!demo && profil != null && !profil.emailVerifie) ...[
          _EmailNonVerifie(email: profil.email),
          const SizedBox(height: 12),
        ],
        Card(
          child: ListTile(
            leading: const Icon(Icons.timer_outlined, color: NlColors.teal),
            // RG-ECO-10 : lien vers « Quota et abonnement ».
            title: Text(
              l.homeFreeVersion,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
            subtitle: Text(
              quota == null
                  ? l.quotaUnknown
                  : [
                      l.homeFreeLeft(
                        fmtDuration(
                          l,
                          Duration(minutes: quota.disponibleMinutes),
                        ),
                      ),
                      // Hors connexion : dernier état reçu, avec son heure (RG-COM-06).
                      if (depot.horsConnexion && quotaRecu != null)
                        l.quotaAsOf(fmtDate(l, quotaRecu)),
                    ].join('\n'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const QuotaScreen())),
          ),
        ),
        if (!demo && enCours != null) ...[
          const SizedBox(height: 12),
          Text(
            l.voyageInProgress(enCours.nom),
            key: const Key('voyage-in-progress'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: (demo ? state.current != null : enCours != null)
              ? null
              : () => demo ? openStart(context) : openStartReel(context),
          icon: const Icon(Icons.play_arrow),
          label: Text(l.startVoyage),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (demo ? state.current == null : enCours == null)
              ? null
              : () => demo
                    ? Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NavigationScreen(),
                        ),
                      )
                    : showNotYet(context),
          icon: const Icon(Icons.restore),
          label: Text(l.resumeVoyage),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => demo
                  ? const DashboardScreen(onlyMine: true)
                  : const SavedVoyagesScreen(),
            ),
          ),
          icon: const Icon(Icons.history),
          label: Text(l.savedVoyages),
        ),
        const SizedBox(height: 32),
        SosButton(
          onPressed: () => demo ? confirmSos(context) : confirmSosReel(context),
        ),
        const SizedBox(height: 8),
        Text(
          l.homeDistressHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        // Mémo sécurité en mer intégré, lisible hors connexion (RG-SOS-22).
        TextButton.icon(
          icon: const Icon(Icons.health_and_safety_outlined),
          label: Text(l.homeSecurityMemo),
          onPressed: () => openSecurityMemo(context),
        ),
      ],
    );
    final actualise = depot.actualiseLe;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') {
                depot.deconnecter();
                return;
              }
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
              if (demo) ...[
                PopupMenuItem(value: 'contacts', child: Text(l.menuContacts)),
                PopupMenuItem(value: 'params', child: Text(l.menuSettings)),
              ],
              PopupMenuItem(value: 'quota', child: Text(l.menuQuota)),
              if (demo)
                PopupMenuItem(value: 'web', child: Text(l.menuDashboard))
              else
                PopupMenuItem(value: 'logout', child: Text(l.logout)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (demo)
            const DemoBanner()
          else
            BetaBanner(
              detail: depot.horsConnexion
                  ? l.offlineSince(
                      actualise == null ? '—' : fmtDate(l, actualise),
                    )
                  : null,
            ),
          Expanded(
            child: RadarBackground(
              child: demo
                  ? list
                  // Actualisation de l'accueil en tirant la liste (Q-84).
                  : RefreshIndicator(onRefresh: depot.actualiser, child: list),
            ),
          ),
          const SponsorFooter(),
        ],
      ),
    );
  }
}

/// Fonction de la vraie application pas encore réalisée (démarrage TODO-5.2,
/// SOS TODO-5.5, écran de navigation TODO-5.3).
Future<void> showNotYet(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('${l.notYetAvailable}\n\n${l.homeDistressHint}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
      ],
    ),
  );
}

/// Adresse non confirmée : démarrage et invitations bloqués (RG-CPT-09).
class _EmailNonVerifie extends StatefulWidget {
  const _EmailNonVerifie({required this.email});
  final String email;

  @override
  State<_EmailNonVerifie> createState() => _EmailNonVerifieState();
}

class _EmailNonVerifieState extends State<_EmailNonVerifie> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.emailNotVerified(widget.email)),
            TextButton(
              onPressed: () async {
                final depot = DepotScope.of(context) as DepotReel;
                String m;
                try {
                  await depot.renvoyerLienVerification();
                  m = l.linkSent;
                } catch (e) {
                  m = messageErreur(l, e);
                }
                if (mounted) setState(() => _message = m);
              },
              child: Text(l.resendLink),
            ),
            if (_message != null) Text(_message!),
          ],
        ),
      ),
    );
  }
}

/// « Navigations enregistrées » de la vraie application : liste reçue du
/// serveur ; hors connexion, la dernière liste reçue, marquée « hors
/// connexion », et la page Web ne s'ouvre pas (cahier des charges §5.2, RG-COM-06).
class SavedVoyagesScreen extends StatelessWidget {
  const SavedVoyagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final depot = DepotScope.of(context);
    final recue = depot is DepotReel ? depot.navigationsRecuesLe : null;
    final mine = depot.navigations.where((n) => !n.commeSuiveur).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.savedVoyages)),
      body: RefreshIndicator(
        onRefresh: depot.actualiser,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (depot.horsConnexion)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.savedOffline(recue == null ? '—' : fmtDate(l, recue)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (mine.isEmpty) Text(l.noSavedVoyages),
            for (final n in mine)
              Card(
                child: ListTile(
                  title: Text(n.nom),
                  subtitle: Text(
                    [
                      n.bateauNom,
                      fmtDate(l, n.debut),
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    if (depot.horsConnexion) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.pageOffline)));
                      return;
                    }
                    launchUrl(
                      Uri.parse(voyagePageUrl(n.id)),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Page d'une navigation sur la plateforme Web, servie par le serveur à côté
/// de l'API (`<chemin>/navigations/<id>`, TODO-6.2).
String voyagePageUrl(String id) {
  final b = kApiUrl.endsWith('/api')
      ? kApiUrl.substring(0, kApiUrl.length - 4)
      : kApiUrl;
  return '$b/navigations/$id';
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
    final depot = DepotScope.of(context);
    final q = depot.quota;
    final used = q?.consommeMinutes ?? 0;
    final left = q?.disponibleMinutes ?? 0;
    final ratio = q == null || used + left == 0
        ? 0.0
        : (used / (used + left)).clamp(0.0, 1.0);
    final l = AppLocalizations.of(context);
    final next = q?.prochainesMinutes;
    final nextAt = q?.prochainesMinutesLe;
    final recu = q?.recuLe;
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
            if (q == null)
              Text(l.quotaUnknown)
            else ...[
              Text(l.quotaUsed(fmtDuration(l, Duration(minutes: used)))),
              Text(l.quotaLeft(fmtDuration(l, Duration(minutes: left)))),
            ],
            const SizedBox(height: 8),
            if (depot.demonstration)
              Text(l.quotaNextRecovery)
            else if (next != null && nextAt != null)
              Text(
                l.quotaNextAt(
                  fmtDuration(l, Duration(minutes: next)),
                  fmtDate(l, nextAt),
                ),
              ),
            // Dernier état reçu, avec son heure (RG-COM-06).
            if (!depot.demonstration && recu != null)
              Text(l.quotaAsOf(fmtDate(l, recu))),
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
