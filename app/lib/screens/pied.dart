import 'package:flutter/material.dart';

import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'memo.dart';

/// Pied de page de la vraie application (Q-102) : intégré à la fin de la
/// page, après les boutons, et non plus fixé en bas de l'écran ; il porte le
/// lien vers le mémo sécurité en mer (RG-SOS-22) sur toutes les pages, puis
/// la ligne « Tous droits réservés · NautiLink · version » (D-128, D-149).
class PiedDePage extends StatelessWidget {
  const PiedDePage({super.key});

  @override
  Widget build(BuildContext context) {
    // La démonstration, figée (D-144), garde le pied de page fixé (AppFrame).
    if (!DepotScope.reel(context)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vagues au-dessus du pied de page (D-157, §15).
            const Vagues(),
            TextButton.icon(
              key: const Key('footer-memo'),
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(l.homeSecurityMemo),
              onPressed: () => openSecurityMemo(context),
            ),
            BuildFooterLine(
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page sans liste défilante (attente, message seul) : le contenu, centré,
/// puis le [PiedDePage] en fin de page.
class PageAvecPied extends StatelessWidget {
  const PageAvecPied({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                Expanded(child: Center(child: child)),
                const PiedDePage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
