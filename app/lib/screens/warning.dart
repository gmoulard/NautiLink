import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

/// Avertissement bêta à accepter (RG-CPT-06). Texte : docs/textes/avertissement-beta.md.
class WarningScreen extends StatefulWidget {
  const WarningScreen({super.key});

  @override
  State<WarningScreen> createState() => _WarningScreenState();
}

class _WarningScreenState extends State<WarningScreen> {
  bool checked = false;

  static const sections = [
    ('1. Version bêta',
        'NautiLink est actuellement proposé en version bêta, c\'est-à-dire en phase de test. Ses fonctions (suivi de position, envoi de SMS et d\'e-mails, alertes SOS, journal de bord) peuvent présenter des erreurs, des retards ou des interruptions, liés notamment à la couverture du réseau mobile, à l\'accès à Internet, à la réception GPS, à l\'état ou aux réglages du téléphone. La continuité et l\'exactitude du service ne sont pas garanties pendant cette phase.'),
    ('2. NautiLink n\'est pas un équipement de sécurité',
        'NautiLink n\'est pas un équipement de sécurité au sens de la réglementation maritime. Il ne remplace ni le matériel d\'armement et de sécurité obligatoire (radio VHF, moyens de signalisation, balise de détresse, etc.), ni les procédures officielles d\'alerte. En cas de détresse, alertez d\'abord les secours par le canal 16 de la VHF, le 196 ou le 112. Une alerte transmise par NautiLink, ou son absence de transmission, ne peut pas être considérée comme une alerte des secours.'),
    ('3. Responsabilité du chef de bord',
        'Le chef de bord reste seul responsable de la conduite du navire, de la sécurité des personnes embarquées, de la préparation de la sortie et du respect de la réglementation en vigueur.'),
    ('4. Limitation de responsabilité',
        'Dans toute la mesure permise par la loi, l\'éditeur de NautiLink ne saurait être tenu responsable des dommages indirects résultant d\'un dysfonctionnement, d\'une interruption ou d\'une indisponibilité du service, ni d\'une utilisation de l\'application non conforme à sa destination ou au présent avertissement.\n\nCette limitation ne s\'applique pas aux dommages corporels, ni en cas de faute lourde ou intentionnelle de l\'éditeur. Elle ne prive pas l\'utilisateur ayant la qualité de consommateur des droits que lui reconnaît la loi, notamment le Code de la consommation, auquel il ne peut être dérogé.'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Avertissement')),
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
                    Text('Version bêta et responsabilité', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    for (final (title, body) in sections) ...[
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(body),
                      const SizedBox(height: 16),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      onChanged: (v) => setState(() => checked = v ?? false),
                      title: const Text('J\'ai lu et j\'accepte cet avertissement'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: checked ? state.acceptWarning : null,
                      child: const Text('Continuer'),
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
