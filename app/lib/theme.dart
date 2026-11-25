import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Couleurs du design « Radar de pluie » (docs/05-identite-marque.md §14, D-69, D-70).
class NlColors {
  static const sky = Color(0xFFEAF4FB); // fond
  static const ink = Color(0xFF0E2A47); // texte
  static const accent = Color(0xFF0E6BA8); // actions
  static const line = Color(0xFFCFE0EE);
  // Thème sombre validé (D-97).
  static const skyDark = Color(0xFF0F2438);
  static const accentDark = Color(0xFF5AAEE6);
  static const inkDark = Color(0xFFE3EEF7);
  static const surfaceDark = Color(0xFF15314D);
  static const lineDark = Color(0xFF24476A);
  static const onAccentDark = Color(0xFF08172A);
  static const alertDark = Color(0xFFE35D5D);
  static const radarGreen = Color(0x614CAF50);
  static const radarYellow = Color(0x80F2C14E);
  static const radarRed = Color(0x80D94343);
  // Noms historiques, conservés pour le reste du code.
  static const navy = ink;
  static const teal = accent;
  static const aqua = accentDark;
  static const white = Color(0xFFFFFFFF);
  static const lightGrey = sky;
  static const alert = Color(0xFFD94343);
  static const beta = Color(0xFFF2C14E);
}

const kDisplayFont = 'SpaceGrotesk';
const kMonoFont = 'IBMPlexMono';

/// Titres en Space Grotesk (police variable : la graisse passe par l'axe wght).
TextStyle displayStyle(double size, {double weight = 700, Color? color}) =>
    TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      fontVariations: [FontVariation('wght', weight)],
      fontWeight: weight >= 600 ? FontWeight.w700 : FontWeight.w500,
      color: color,
      height: 1.15,
    );

ThemeData nlTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? NlColors.skyDark : NlColors.sky;
  final fg = dark ? NlColors.inkDark : NlColors.ink;
  final accent = dark ? NlColors.accentDark : NlColors.accent;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NlColors.accent,
        brightness: brightness,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? NlColors.onAccentDark : NlColors.white,
        secondary: fg,
        error: dark ? NlColors.alertDark : NlColors.alert,
        surface: dark ? NlColors.surfaceDark : NlColors.white,
        onSurface: fg,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.copyWith(
      headlineSmall: displayStyle(24, color: fg),
      titleLarge: displayStyle(20, color: fg),
      titleMedium: displayStyle(16, weight: 600, color: fg),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: displayStyle(20, color: fg),
      shape: Border(
        bottom: BorderSide(color: dark ? NlColors.lineDark : NlColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 1.5),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: dark ? NlColors.lineDark : NlColors.line),
      ),
    ),
  );
}

/// Échos radar vert, jaune, rouge en décor, derrière le contenu (design « Radar de pluie »).
class RadarBackground extends StatelessWidget {
  const RadarBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _RadarPainter())),
        ),
        child,
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter();

  void _echo(Canvas canvas, Offset c, double rx, double ry, Color color) {
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(rect),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .78, size.height * .16);
    _echo(canvas, c.translate(-20, 30), 190, 140, NlColors.radarGreen);
    _echo(canvas, c, 120, 90, NlColors.radarYellow);
    _echo(canvas, c.translate(10, -8), 62, 46, NlColors.radarRed);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => false;
}

/// Bouton SOS rouge, réservé à l'alerte (RG-SOS-01).
class SosButton extends StatelessWidget {
  const SosButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: NlColors.white,
        minimumSize: const Size.fromHeight(64),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.sos, size: 28),
      label: Text(AppLocalizations.of(context).sosButton),
    );
  }
}

/// Commit dont l'application est construite, fourni par le workflow
/// « Site GitHub Pages » (`--dart-define=NAUTILINK_COMMIT=<sha>`) ; vide en local.
const String buildCommit = String.fromEnvironment('NAUTILINK_COMMIT');

/// Mention du sponsor : la SRT et son guidon, puis le commit de construction.
class SponsorFooter extends StatelessWidget {
  const SponsorFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      // Fond de l'application, en thème clair comme en sombre (D-97).
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: const Border(
          top: BorderSide(color: Color(0xFFF8D818), width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/sponsor-srt.png',
                height: 30,
                semanticLabel: l.sponsorLogoLabel,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l.sponsorText,
                  style: TextStyle(
                    color: dark ? NlColors.inkDark : const Color(0xFF1E3296),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            buildCommit.isEmpty
                ? l.buildLocal
                : l.buildCommit(
                    buildCommit.length > 7
                        ? buildCommit.substring(0, 7)
                        : buildCommit,
                  ),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Bandeau rappelant que tout est simulé.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: NlColors.beta,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        AppLocalizations.of(context).demoBanner,
        style: const TextStyle(
          color: Color(0xFF3A2A00),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
