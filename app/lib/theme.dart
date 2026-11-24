import 'package:flutter/material.dart';

/// Couleurs de docs/05-identite-marque.md.
class NlColors {
  static const navy = Color(0xFF082B46);
  static const teal = Color(0xFF13A6AD);
  static const aqua = Color(0xFF7EDDE4);
  static const white = Color(0xFFFFFFFF);
  static const lightGrey = Color(0xFFF2F5F7);
  static const alert = Color(0xFFD94343);
  static const beta = Color(0xFFF2C14E);
}

ThemeData nlTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: NlColors.teal,
    brightness: brightness,
  ).copyWith(
    primary: dark ? NlColors.aqua : NlColors.teal,
    onPrimary: dark ? NlColors.navy : NlColors.white,
    secondary: NlColors.navy,
    error: NlColors.alert,
    surface: dark ? const Color(0xFF0B2B44) : NlColors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF061C2E) : NlColors.lightGrey,
    appBarTheme: const AppBarTheme(
      backgroundColor: NlColors.navy,
      foregroundColor: NlColors.white,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: dark ? const Color(0xFF1B4462) : const Color(0xFFD3DEE6)),
      ),
    ),
  );
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
        textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: .5),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.sos, size: 28),
      label: const Text('Envoyer un SOS'),
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
        style: TextStyle(color: Color(0xFF3A2A00), fontWeight: FontWeight.w600, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
