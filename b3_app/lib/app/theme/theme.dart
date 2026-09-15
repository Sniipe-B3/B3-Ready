import 'package:flutter/material.dart';

class B3Theme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2C3E50), // Un bleu gris sobre
        primary: const Color(0xFF2C3E50),
        secondary: const Color(0xFF27AE60), // Vert rassurant
        surface: Colors.white,
      ),
      useMaterial3: true,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50)),
        headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50)),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF34495E)),
        bodyLarge:
            TextStyle(fontSize: 18, color: Color(0xFF2C3E50), height: 1.5),
        bodyMedium:
            TextStyle(fontSize: 16, color: Color(0xFF7F8C8D), height: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFFBDC3C7)),
        ),
      ),
    );
  }
}
