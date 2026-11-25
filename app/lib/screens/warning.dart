import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../theme.dart';

/// Avertissement bêta à accepter (RG-CPT-06). Texte : docs/textes/avertissement-beta.md,
/// repris dans lib/l10n/app_fr.arb (warningSection…).
class WarningScreen extends StatefulWidget {
  const WarningScreen({super.key});

  @override
  State<WarningScreen> createState() => _WarningScreenState();
}

class _WarningScreenState extends State<WarningScreen> {
  bool checked = false;


  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final sections = [
      (l.warningSection1Title, l.warningSection1Body),
      (l.warningSection2Title, l.warningSection2Body),
      (l.warningSection3Title, l.warningSection3Body),
      (l.warningSection4Title, l.warningSection4Body),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.warningTitle)),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      l.warningHeading,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    for (final (title, body) in sections) ...[
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(body),
                      const SizedBox(height: 16),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      onChanged: (v) => setState(() => checked = v ?? false),
                      title: Text(l.warningAccept),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: checked ? state.acceptWarning : null,
                      child: Text(l.continueLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
