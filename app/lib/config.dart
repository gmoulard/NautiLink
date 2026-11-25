/// Réglages choisis à la construction (D-127).
///
/// - `--dart-define=NAUTILINK_MODE=demo|reel` : démonstration (données
///   d'exemple, rien n'est envoyé ; par défaut, pour le site et le workflow
///   « Site GitHub Pages ») ou vraie application branchée sur le serveur.
/// - `--dart-define=NAUTILINK_API=<adresse>` : point d'entrée de l'API
///   (08-architecture.md §4), sans `/v1` final.
library;

enum ModeApplication { demo, reel }

const String _mode = String.fromEnvironment(
  'NAUTILINK_MODE',
  defaultValue: 'demo',
);

/// Mode choisi à la construction ; toute valeur autre que `reel` donne la démonstration.
const ModeApplication kMode = _mode == 'reel'
    ? ModeApplication.reel
    : ModeApplication.demo;

/// Adresse de l'API du serveur central (D-62, 08-architecture.md §4).
const String kApiUrl = String.fromEnvironment(
  'NAUTILINK_API',
  defaultValue: 'https://vdl.moulard.org/nautilink/api',
);
