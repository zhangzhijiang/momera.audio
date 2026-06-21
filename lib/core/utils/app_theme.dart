import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFF4F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE4E4E4);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFBBBBBB);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentLight = Color(0xFFF3E8FF);
  static const Color recordRed = Color(0xFFEF4444);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      );
}
