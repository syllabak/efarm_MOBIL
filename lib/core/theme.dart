import 'package:flutter/material.dart';

// Palette reprise du site web (tailwind green-900 / green-700 / green-600)
const efarmGreen = Color(0xFF15803D);
const efarmDeep = Color(0xFF14532D);
// Cabinet vétérinaire : cyan-800 / cyan-900 comme sur le site web
const efarmCyan = Color(0xFF155E75);
const efarmCyanDeep = Color(0xFF164E63);

ThemeData buildTheme(Brightness b, {bool vet = false}) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: vet ? efarmCyan : efarmGreen, brightness: b),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? null : (vet ? efarmCyanDeep : efarmDeep),
      foregroundColor: dark ? null : Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
  );
}
