import 'package:flutter/material.dart';

/// Couleurs du design « Radar de pluie » (docs/05-identite-marque.md §14, D-69, D-70).
class NlColors {
  static const sky = Color(0xFFEAF4FB); // fond
  static const ink = Color(0xFF0E2A47); // texte
  static const accent = Color(0xFF0E6BA8); // actions
  static const line = Color(0xFFCFE0EE);
  static const skyDark = Color(0xFF0B2236);
  static const accentDark = Color(0xFF5DB3EA);
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
  final fg = dark ? const Color(0xFFE3F0FA) : NlColors.ink;
  final accent = dark ? NlColors.accentDark : NlColors.accent;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NlColors.accent,
        brightness: brightness,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xFF071827) : NlColors.white,
        secondary: fg,
        error: NlColors.alert,
        surface: dark ? const Color(0xFF0E2A43) : NlColors.white,
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
        bottom: BorderSide(
          color: dark ? const Color(0xFF1D3B55) : NlColors.line,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 1.5),
        textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: dark ? const Color(0xFF1D3B55) : NlColors.line),
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
        backgroundColor: NlColors.alert,
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
      label: const Text('Envoyer un SOS'),
    );
  }
}

/// Mention du sponsor : la SRT et son guidon.
class SponsorFooter extends StatelessWidget {
  const SponsorFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: NlColors.white,
        border: Border(top: BorderSide(color: Color(0xFFF8D818), width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/sponsor-srt.png',
            height: 30,
            semanticLabel: 'Guidon de la SRT',
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Sponsorisée par la SRT',
              style: TextStyle(
                color: Color(0xFF1E3296),
                fontWeight: FontWeight.w700,
              ),
            ),
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
      child: const Text(
        'Version bêta · Démonstration : rien n\'est réellement envoyé',
        style: TextStyle(
          color: Color(0xFF3A2A00),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
