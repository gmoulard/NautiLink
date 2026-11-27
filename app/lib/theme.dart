import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'depot/depot.dart';
import 'data.dart';
import 'l10n/app_localizations.dart';

/// Couleurs de l'identité graphique du 2026-11-26 (docs/05-identite-marque.md
/// §15, D-157), qui remplace le design « Radar de pluie » (D-69, D-70) ; thème
/// sombre de D-97.
class NlColors {
  static const sky = Color(0xFFF4FAFE); // fond des écrans
  static const skyTop = Color(0xFFDDEFFB); // haut du dégradé ciel
  static const ink = Color(0xFF0B2A55); // bleu marine : titres, texte
  static const ink2 = Color(0xFF4A6380); // texte secondaire
  static const accent = Color(0xFF1565C0); // liens
  static const turquoise = Color(0xFF17A2B0); // traits, décors
  static const button = Color(0xFF0B7F86); // boutons : contraste AA (D-161)
  static const line = Color(0xFFD6E6F2);
  // Thème sombre (D-97).
  static const skyDark = Color(0xFF08172A);
  static const skyTopDark = Color(0xFF0F2438);
  static const accentDark = Color(0xFF5AAEE6);
  static const buttonDark = Color(0xFF2BC0C6);
  static const inkDark = Color(0xFFE3EEF7);
  static const surfaceDark = Color(0xFF15314D);
  static const lineDark = Color(0xFF24476A);
  static const onAccentDark = Color(0xFF08172A);
  static const alertDark = Color(0xFFE35D5D);
  // Avertissement bêta : rouge sur rose (§15).
  static const betaBg = Color(0xFFFDE8E8);
  static const betaFg = Color(0xFFB3261E);
  static const betaBgDark = Color(0xFF3A1518);
  static const betaFgDark = Color(0xFFFFB4AB);
  // Noms historiques, conservés pour le reste du code.
  static const navy = ink;
  static const teal = button;
  static const aqua = accentDark;
  static const white = Color(0xFFFFFFFF);
  static const lightGrey = sky;
  static const alert = Color(0xFFD94343);
  static const beta = betaBg;
}

/// Inter partout (§15) ; les chiffres des chronomètres en chiffres tabulaires.
const kFont = 'Inter';
const kDisplayFont = kFont;
const kMonoFont = kFont;

/// Titres en Inter ExtraBold, resserrés (§15).
TextStyle displayStyle(double size, {double weight = 800, Color? color}) =>
    TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      fontWeight: weight >= 750
          ? FontWeight.w800
          : (weight >= 650 ? FontWeight.w700 : FontWeight.w600),
      letterSpacing: -0.2,
      color: color,
      height: 1.15,
    );

/// Thème de l'application. [reel] : vraie application, au look du
/// 2026-11-27 (D-178, §15) : texte plus petit, formes plus rondes, menu sur
/// la couleur de fond des pages ; la démonstration, figée (D-144), garde le
/// thème du 2026-11-26.
ThemeData nlTheme(Brightness brightness, {bool reel = false}) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? NlColors.skyDark : NlColors.sky;
  final fg = dark ? NlColors.inkDark : NlColors.ink;
  final accent = dark ? NlColors.accentDark : NlColors.accent;
  final bouton = dark ? NlColors.buttonDark : NlColors.button;
  final ligne = dark ? NlColors.lineDark : NlColors.line;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NlColors.button,
        brightness: brightness,
      ).copyWith(
        primary: bouton,
        onPrimary: dark ? NlColors.onAccentDark : NlColors.white,
        secondary: accent,
        error: dark ? NlColors.alertDark : NlColors.alert,
        surface: dark ? NlColors.surfaceDark : NlColors.white,
        onSurface: fg,
        outline: ligne,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: kFont,
  );
  const pilule = StadiumBorder();
  final theme = base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.copyWith(
      headlineSmall: displayStyle(24, color: fg),
      titleLarge: displayStyle(20, color: fg),
      titleMedium: displayStyle(16, weight: 700, color: fg),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? NlColors.skyTopDark : NlColors.white,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: const Color(0x220B2A55),
      centerTitle: false,
      titleTextStyle: displayStyle(20, color: fg),
      shape: Border(bottom: BorderSide(color: ligne)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: bouton,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shadowColor: NlColors.turquoise.withValues(alpha: .4),
        textStyle: const TextStyle(
          fontFamily: kFont,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        shape: pilule,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: fg,
        backgroundColor: scheme.surface,
        side: BorderSide(color: ligne, width: 1.2),
        textStyle: const TextStyle(
          fontFamily: kFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: pilule,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ligne),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ligne),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: const Color(0x1F0B2A55),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ligne),
      ),
    ),
  );
  if (!reel) return theme;
  // D-178 : texte plus petit, formes plus rondes.
  final texte = Typography.englishLike2021
      .merge(theme.textTheme)
      .apply(fontSizeFactor: .92);
  final rond = BorderRadius.circular(22);
  return theme.copyWith(
    textTheme: texte.copyWith(
      headlineSmall: displayStyle(22, color: fg),
      titleLarge: displayStyle(18, color: fg),
      titleMedium: displayStyle(15, weight: 700, color: fg),
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: displayStyle(18, color: fg),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: theme.filledButtonTheme.style!.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: kFont,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: theme.outlinedButtonTheme.style!.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: kFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: rond,
        borderSide: BorderSide(color: ligne),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: rond,
        borderSide: BorderSide(color: ligne),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rond,
        borderSide: BorderSide(color: bouton, width: 1.6),
      ),
    ),
    cardTheme: theme.cardTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: rond,
        side: BorderSide(color: ligne),
      ),
    ),
    // D-178 : menu ⋮ aux angles arrondis, sur la couleur de fond des pages.
    popupMenuTheme: PopupMenuThemeData(
      color: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ligne),
      ),
      textStyle: TextStyle(fontFamily: kFont, fontSize: 15, color: fg),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    chipTheme: theme.chipTheme.copyWith(shape: pilule),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
  );
}

/// Fond des écrans (§15) : dégradé ciel et vagues en bas, derrière le contenu.
/// Garde son ancien nom (décor « Radar de pluie » jusqu'à D-157).
class RadarBackground extends StatelessWidget {
  const RadarBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Vraie application (D-178) : fond des pages, avec les isobares.
    if (DepotScope.reel(context)) return Isobares(child: child);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .45],
          colors: dark
              ? const [NlColors.skyTopDark, NlColors.skyDark]
              : const [NlColors.skyTop, NlColors.sky],
        ),
      ),
      child: child,
    );
  }
}

/// Décor de la variante 1 « Isobares » de la planche météo (D-178,
/// `site/designs/meteo.html`) : isobares fines autour d'un point, à droite,
/// avec la pression en hectopascals, derrière le contenu.
class Isobares extends StatelessWidget {
  const Isobares({super.key, required this.child, this.centreY = 330});
  final Widget child;

  /// Hauteur du centre des isobares, depuis le haut de la zone.
  final double centreY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: CustomPaint(
        painter: _IsobaresPainter(
          couleur: dark ? NlColors.accentDark : const Color(0xFF0E6BA8),
          centreY: centreY,
        ),
        child: child,
      ),
    );
  }
}

class _IsobaresPainter extends CustomPainter {
  const _IsobaresPainter({required this.couleur, required this.centreY});
  final Color couleur;
  final double centreY;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * .88, centreY);
    const rayons = [47.0, 85.0, 123.0, 161.0, 199.0];
    const opacites = [.22, .17, .13, .09, .05];
    for (var i = 0; i < rayons.length; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: centre,
          width: rayons[i] * 2.3,
          height: rayons[i] * 2,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = couleur.withValues(alpha: opacites[i]),
      );
    }
    final texte = TextPainter(
      text: TextSpan(
        text: '1012',
        style: TextStyle(
          fontFamily: kFont,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: couleur.withValues(alpha: .3),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texte.paint(canvas, centre - Offset(texte.width / 2, texte.height / 2));
  }

  @override
  bool shouldRepaint(covariant _IsobaresPainter old) =>
      old.couleur != couleur || old.centreY != centreY;
}

/// Bandeau photo du bateau, en haut de l'accueil et de la connexion (D-178,
/// étude Nautilinkimages261126.png) : la photo, le logo, « NautiLink » et la
/// signature, puis une vague turquoise et la vague blanche (couleur des
/// pages). [actions] : boutons posés en haut à droite (menu ⋮ de l'accueil).
class BandeauPhoto extends StatelessWidget {
  const BandeauPhoto({super.key, this.hauteur = 230, this.actions});
  final double hauteur;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final haut = MediaQuery.paddingOf(context).top;
    return SizedBox(
      key: const Key('bandeau-photo'),
      height: hauteur + haut,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            'assets/bandeau-bateau.jpg',
            fit: BoxFit.cover,
            // Le voilier, à droite de la photo, reste visible.
            alignment: const Alignment(.6, .3),
            excludeFromSemantics: true,
          ),
          // Ciel éclairci derrière le logo et le nom.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment(.5, .2),
                colors: [Color(0xB3F4FAFE), Color(0x00F4FAFE)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: actions == null ? 16 : 52,
            top: haut + 16,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/logo-nautilink.png',
                    key: const Key('brand-logo'),
                    width: 56,
                    height: 56,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NautiLink',
                        style: displayStyle(26, color: NlColors.ink),
                      ),
                      Text(
                        'Your sea, your safety, your story.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NlColors.ink,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (actions != null)
            Positioned(right: 4, top: haut + 4, child: actions!),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: 48,
            child: CustomPaint(
              painter: _VagueBandeauPainter(theme.scaffoldBackgroundColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _VagueBandeauPainter extends CustomPainter {
  const _VagueBandeauPainter(this.fond);
  final Color fond;

  Path _vague(
    Size s,
    double gauche,
    double creux,
    double bosse,
    double droite,
  ) => Path()
    ..moveTo(0, s.height * gauche)
    ..cubicTo(
      s.width * .3,
      s.height * creux,
      s.width * .65,
      s.height * bosse,
      s.width,
      s.height * droite,
    )
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _vague(size, .2, .95, -.2, .15),
      Paint()..color = NlColors.turquoise.withValues(alpha: .9),
    );
    canvas.drawPath(_vague(size, .5, 1.15, .05, .45), Paint()..color = fond);
  }

  @override
  bool shouldRepaint(covariant _VagueBandeauPainter old) => old.fond != fond;
}

/// Vagues turquoise et bleues (§15), au-dessus du pied de page.
class Vagues extends StatelessWidget {
  const Vagues({super.key, this.hauteur = 36});
  final double hauteur;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: hauteur,
    width: double.infinity,
    child: const CustomPaint(painter: _VaguesPainter()),
  );
}

class _VaguesPainter extends CustomPainter {
  const _VaguesPainter();

  Path _vague(Size s, double base, double amplitude, double decalage) {
    final p = Path()..moveTo(0, s.height * base);
    for (var i = 0; i < 2; i++) {
      final x0 = s.width * i / 2;
      final w = s.width / 2;
      p.cubicTo(
        x0 + w * .25 + decalage,
        s.height * (base - amplitude),
        x0 + w * .75 + decalage,
        s.height * (base + amplitude),
        x0 + w,
        s.height * base,
      );
    }
    return p
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _vague(size, .45, .35, 0),
      Paint()..color = NlColors.turquoise.withValues(alpha: .22),
    );
    canvas.drawPath(
      _vague(size, .65, .3, 30),
      Paint()..color = NlColors.accent.withValues(alpha: .18),
    );
  }

  @override
  bool shouldRepaint(covariant _VaguesPainter oldDelegate) => false;
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

/// Version, build et commit de l'application (D-128, docs/09-versions.md),
/// fournis par le workflow « Site GitHub Pages » (`--dart-define=NAUTILINK_VERSION=…`,
/// `NAUTILINK_BUILD`, `NAUTILINK_COMMIT`) ; vides en construction locale.
const String buildVersion = String.fromEnvironment('NAUTILINK_VERSION');
const String buildNumber = String.fromEnvironment('NAUTILINK_BUILD');
const String buildCommit = String.fromEnvironment('NAUTILINK_COMMIT');

/// Dépôt affiché dans le pied de page.
const String repositoryUrl = 'https://github.com/gmoulard/NautiLink';

/// Mention du sponsor : la SRT et son guidon.
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
      child: Row(
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
          const SizedBox(width: 10),
          // TODO-3.13 : petit lien vers le site de présentation.
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(siteUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l.footerSiteLink,
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.underline,
                ),
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
      child: Text(
        AppLocalizations.of(context).demoBanner,
        style: const TextStyle(
          color: NlColors.betaFg,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Cadre de tous les écrans (`MaterialApp.builder`). Dans la démonstration
/// (figée, D-144), le pied de page [BuildFooterLine] reste fixé en bas de
/// l'écran (D-128) ; dans la vraie application, il est intégré à la fin de
/// chaque page, après les boutons, avec le lien vers le mémo sécurité en mer
/// (`PiedDePage`, Q-102).
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (DepotScope.reel(context)) return child;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          // Le pied de page prend la marge du bas (barre de gestes) à sa charge.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          ),
        ),
        Material(
          color: theme.scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: BuildFooterLine(
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// « Tous droits réservés · NautiLink · Version bêta · V0.0.1 · build 12 ·
/// commit 93b0f97 » ; « NautiLink » ouvre le site vitrine (D-149, D-178). La démonstration,
/// figée (D-144), garde l'adresse du dépôt (D-128).
class BuildFooterLine extends StatelessWidget {
  const BuildFooterLine({super.key, this.style, this.beta});

  final TextStyle? style;

  /// Vraie application : lien « Version bêta », vers l'avertissement, qui
  /// remplace le bandeau bêta (D-178, RG-CPT-07).
  final VoidCallback? beta;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final linkStyle = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
    );
    final build = buildVersion.isEmpty
        ? l.buildLocal
        : l.buildInfo(
            buildVersion,
            buildNumber,
            buildCommit.length > 7 ? buildCommit.substring(0, 7) : buildCommit,
          );
    final reel = DepotScope.reel(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${l.rightsReserved} · ', style: style),
        InkWell(
          key: const Key('footer-site'),
          onTap: () => launchUrl(
            Uri.parse(reel ? siteUrl : repositoryUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(reel ? l.appTitle : repositoryUrl, style: linkStyle),
        ),
        if (beta != null) ...[
          Text(' · ', style: style),
          InkWell(
            key: const Key('footer-beta'),
            onTap: beta,
            child: Text(l.betaBanner, style: linkStyle),
          ),
        ],
        Text(' · $build', style: style),
      ],
    );
  }
}
