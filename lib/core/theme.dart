import 'package:flutter/material.dart';

// Palette reprise du site web (tailwind green-900 / green-700 / green-600)
const efarmGreen = Color(0xFF15803D);
const efarmDeep = Color(0xFF14532D);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: efarmGreen, brightness: b),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? null : efarmDeep,
      foregroundColor: dark ? null : Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
  );
}
