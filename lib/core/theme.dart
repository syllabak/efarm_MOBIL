import 'package:flutter/material.dart';

// Palette reprise du site web (tailwind green-900 / green-700 / green-600)
const efarmGreen = Color(0xFF15803D);
const efarmDeep = Color(0xFF14532D);
const efarmButton = Color(0xFF16A34A);
// Cabinet vétérinaire : cyan-800 / cyan-900 / cyan-600 comme sur le site web
const efarmCyan = Color(0xFF155E75);
const efarmCyanDeep = Color(0xFF164E63);
const efarmCyanButton = Color(0xFF0891B2);

/// Thème du site web : fond `#f8f9fa`, cartes blanches arrondies (.75rem) à ombre légère, boutons vert 600 (cyan 600 au cabinet),
/// champs à bordure grise et focus vert, barre vert 900 (cyan 900 au cabinet).
ThemeData buildTheme(Brightness b, {bool vet = false}) {
  final dark = b == Brightness.dark;
  final button = vet ? efarmCyanButton : efarmButton;
  final scheme = ColorScheme.fromSeed(seedColor: vet ? efarmCyan : efarmGreen, brightness: b).copyWith(
    primary: dark ? null : button,
    onPrimary: dark ? null : Colors.white,
    surface: dark ? null : Colors.white,
    surfaceTint: Colors.transparent,
  );
  final field = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: dark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB)));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? null : const Color(0xFFF8F9FA),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? null : (vet ? efarmCyanDeep : efarmDeep),
      foregroundColor: dark ? null : Colors.white,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: field,
      enabledBorder: field,
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: button, width: 2)),
      filled: !dark,
      fillColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: dark ? null : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: const Size(64, 44))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? null : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: vet ? const Color(0xFFCFFAFE) : const Color(0xFFDCFCE7),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  );
}
