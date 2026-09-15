import 'package:flutter/material.dart';

class B3Theme {
  static const Color b3Primary = Color(0xFF2C3E50); // Sombre, sérieux, professionnel
  static const Color b3Surface = Color(0xFFF8F9FA); // Fond légèrement teinté (gris très clair) au lieu de blanc pur
  
  static const Color b3Green = Color(0xFF2E7D32);
  static const Color b3Orange = Color(0xFFE65100);
  static const Color b3Red = Color(0xFFC62828);
  static const Color b3Gray = Color(0xFF78909C);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: b3Primary,
        primary: b3Primary,
        surface: b3Surface,
        onSurface: const Color(0xFF1F2937),
      ),
      scaffoldBackgroundColor: b3Surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: b3Primary),
        titleTextStyle: TextStyle(
          color: b3Primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: b3Primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: b3Primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: b3Primary,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: b3Primary, height: 1.2),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: b3Primary, height: 1.3),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: b3Primary),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF374151)),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4B5563)),
      ),
    );
  }
}
