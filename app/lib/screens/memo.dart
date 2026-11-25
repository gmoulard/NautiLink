import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data.dart';
import '../l10n/app_localizations.dart';

/// Mémo sécurité en mer intégré à l'application, lisible hors connexion
/// (RG-SOS-22, D-125) : copie de `site/securite.html` faite à chaque
/// construction par `outils/copier-memo.sh`.
const securityMemoAsset = 'assets/memo/securite.html';

/// Ouvre le mémo depuis l'accueil, par « Mémo sécurité en mer ». Sur le
/// téléphone (Android, iPhone), la copie intégrée ; dans la démonstration
/// Web, qui n'a pas de vue Web intégrée, la page du site.
Future<void> openSecurityMemo(BuildContext context) async {
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!mobile) {
    await launchUrl(
      Uri.parse(securityMemoUrl),
      mode: LaunchMode.externalApplication,
    );
    return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SecurityMemoScreen()));
}

class SecurityMemoScreen extends StatefulWidget {
  const SecurityMemoScreen({super.key});

  @override
  State<SecurityMemoScreen> createState() => _SecurityMemoScreenState();
}

class _SecurityMemoScreenState extends State<SecurityMemoScreen> {
  late final WebViewController _vue = WebViewController()
    // Liste « Avant de partir » cochable et message MAYDAY préparé : JavaScript de la page.
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) {
          // Liens vers les sources, appels (196, 112) : hors de l'application.
          final u = Uri.tryParse(r.url);
          if (u != null &&
              const {
                'http',
                'https',
                'tel',
                'mailto',
                'sms',
              }.contains(u.scheme)) {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    )
    ..loadFlutterAsset(securityMemoAsset);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeSecurityMemo),
      ),
      body: SafeArea(child: WebViewWidget(controller: _vue)),
    );
  }
}
