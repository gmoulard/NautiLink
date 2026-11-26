import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'data.dart';
import 'depot/depot.dart';
import 'depot/depot_demo.dart';
import 'l10n/app_localizations.dart';
import 'reel/depot_reel.dart';
import 'screens/connexion.dart';
import 'screens/dashboard.dart';
import 'screens/home.dart';
import 'screens/pied.dart';
import 'screens/suivi_reel.dart';
import 'screens/warning.dart';
import 'theme.dart';

/// Démonstration par défaut ; vraie application avec `--dart-define=NAUTILINK_MODE=reel` (D-127).
Future<void> main() async {
  if (kMode == ModeApplication.reel) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      NautiLinkApp(
        depot: await DepotReel.creer(),
        langueDuTelephone: !bool.hasEnvironment('NAUTILINK_LANG'),
      ),
    );
  } else {
    runApp(const NautiLinkApp());
  }
}

/// Donne l'état du prototype à tous les écrans.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Langue de l'interface : français par défaut (langue de référence, TODO-9.2).
/// Essai d'une autre langue : `--dart-define=NAUTILINK_LANG=en`.
const kDefaultLanguage = String.fromEnvironment(
  'NAUTILINK_LANG',
  defaultValue: 'fr',
);

/// Navigation de l'application, pour ouvrir une navigation depuis une
/// notification push (RG-AND-09).
final navigateurApp = GlobalKey<NavigatorState>();

class NautiLinkApp extends StatefulWidget {
  const NautiLinkApp({
    super.key,
    this.locale = const Locale(kDefaultLanguage),
    this.depot,
    this.langueDuTelephone = false,
  });
  final Locale locale;

  /// Vraie application : langue du téléphone par défaut, ou celle choisie
  /// dans les paramètres (RG-PRM-03) ; français si le téléphone est dans une
  /// autre langue.
  final bool langueDuTelephone;

  /// Dépôt de données ; par défaut celui du mode choisi à la construction (D-127).
  final Depot? depot;

  @override
  State<NautiLinkApp> createState() => _NautiLinkAppState();
}

class _NautiLinkAppState extends State<NautiLinkApp>
    with WidgetsBindingObserver {
  final state = AppState();
  late final Depot depot = widget.depot ?? DepotDemo(state);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    depot.ouvrir();
    if (widget.langueDuTelephone) depot.addListener(_langueChangee);
    _ecouterNotifications();
  }

  StreamSubscription<String>? _touchees;

  /// Notification touchée : la navigation s'ouvre dans l'application, sur
  /// Android comme sur iPhone (RG-AND-09, D-143).
  Future<void> _ecouterNotifications() async {
    final d = depot;
    final n = d is DepotReel ? d.notifications : null;
    if (n == null) return;
    void ouvrir(String id) => navigateurApp.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NavigationSuivieScreen(navigationId: id),
      ),
    );
    _touchees = n.navigationsTouchees.listen(ouvrir);
    final initiale = await n.navigationInitiale();
    if (initiale != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ouvrir(initiale));
    }
  }

  String? _langue;

  /// Langue changée dans les paramètres : l'application se redessine (RG-PRM-03).
  void _langueChangee() {
    final d = depot;
    if (d is DepotReel && d.langueChoisie != _langue && mounted) {
      setState(() => _langue = d.langueChoisie);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    depot.removeListener(_langueChangee);
    _touchees?.cancel();
    super.dispose();
  }

  /// Retour au premier plan : relecture du serveur et relance de la file
  /// (08-architecture.md §5, D-135).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      depot.actualiser();
      depot.envois.relancer();
    }
  }

  /// Vide : langue du téléphone, résolue par [MaterialApp.localeResolutionCallback].
  Locale? _locale() {
    final d = depot;
    if (!widget.langueDuTelephone || d is! DepotReel) return widget.locale;
    final l = d.langueChoisie;
    return l == null ? null : Locale(l);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: DepotScope(
        depot: depot,
        child: MaterialApp(
          navigatorKey: navigateurApp,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          locale: _locale(),
          localeResolutionCallback: (l, supportees) =>
              supportees.any((s) => s.languageCode == l?.languageCode)
              ? Locale(l!.languageCode)
              : const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: nlTheme(Brightness.light),
          darkTheme: nlTheme(Brightness.dark),
          // Pied de page de tous les écrans : licence, dépôt, version (D-128).
          builder: (context, child) => AppFrame(child: child!),
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    if (!depot.demonstration) {
      // Vraie application : connexion d'abord ; une session ouverte reste
      // ouverte hors connexion, sur les données locales (RG-COM-06).
      return switch (depot.etatSession) {
        EtatSession.chargement => const Scaffold(
          body: PageAvecPied(child: CircularProgressIndicator()),
        ),
        EtatSession.deconnecte => const ConnexionScreen(),
        EtatSession.connecte => const HomeScreen(),
      };
    }
    final state = AppScope.of(context);
    if (!state.warningAccepted) return const WarningScreen();
    return kIsWeb ? const ChooseSideScreen() : const HomeScreen();
  }
}

/// Démonstration Web : choisir le côté à essayer.
class ChooseSideScreen extends StatelessWidget {
  const ChooseSideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.chooseTitle)),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  shrinkWrap: true,
                  children: [
                    Text(
                      l.chooseQuestion,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _SideCard(
                      icon: Icons.sailing,
                      title: l.chooseNavigatorTitle,
                      text: l.chooseNavigatorText,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PhoneFrame(child: HomeScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SideCard(
                      icon: Icons.dashboard_outlined,
                      title: l.chooseFollowerTitle,
                      text: l.chooseFollowerText,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SponsorFooter(),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 36, color: NlColors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Sur grand écran, montre l'application mobile dans un cadre de téléphone.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) return child;
        return ColoredBox(
          color: NlColors.navy,
          child: Center(
            child: Container(
              width: 412,
              height: (c.maxHeight - 40).clamp(500, 900).toDouble(),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.black, width: 10),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
