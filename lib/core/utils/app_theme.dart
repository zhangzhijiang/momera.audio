import 'package:flutter/material.dart';

/// The app's palette, resolved from the active theme.
///
/// A [ThemeExtension] rather than a set of constants, because the same nine
/// roles have to mean different colours in light and dark. Widgets ask for a
/// role — `AppTheme.of(context).surface` — and never for a specific colour, so
/// switching themes is a matter of which palette the theme carries.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.accent,
    required this.accentLight,
    required this.recordRed,
    required this.onAccent,
    required this.rowAlternate,
  });

  /// Behind everything.
  final Color background;

  /// Cards, bars and sheets that sit on [background].
  final Color surface;

  /// Hairlines and dividers.
  final Color borderLight;

  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  /// The violet the app is built around.
  final Color accent;

  /// A tint of [accent] for the backgrounds of accented controls.
  final Color accentLight;

  /// Recording indicators and destructive actions.
  ///
  /// The one role that does not change between themes: it fills the record
  /// button, and a red light enough to read as text on a dark ground would not
  /// carry white glyphs on that button.
  final Color recordRed;

  /// Text and icons drawn on top of [accent].
  ///
  /// Not simply white: the dark theme's accent is a *light* violet, so white on
  /// it would be unreadable. This flips with the palette while [accent] does the
  /// opposite, which is the whole reason it is a role of its own.
  final Color onAccent;

  /// Every other row in a list, so long lists stay scannable. Deliberately a
  /// hair off [surface] rather than a visible stripe: it should register as
  /// texture, not as a table.
  final Color rowAlternate;

  static const AppColors light = AppColors(
    background: Color(0xFFF4F4F6),
    surface: Color(0xFFFFFFFF),
    borderLight: Color(0xFFE4E4E4),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF6B6B6B),
    textHint: Color(0xFFBBBBBB),
    accent: Color(0xFF8B5CF6),
    accentLight: Color(0xFFF3E8FF),
    recordRed: Color(0xFFEF4444),
    onAccent: Color(0xFFFFFFFF),
    rowAlternate: Color(0xFFFAFAFC),
  );

  /// Not the light palette inverted: on a dark ground the accent has to lighten
  /// to stay legible, and the "light" accent tint becomes a dark violet wash.
  static const AppColors dark = AppColors(
    background: Color(0xFF101012),
    surface: Color(0xFF1B1B1F),
    borderLight: Color(0xFF2E2E33),
    textPrimary: Color(0xFFF2F2F4),
    textSecondary: Color(0xFFA5A5AD),
    textHint: Color(0xFF6E6E77),
    accent: Color(0xFFA78BFA),
    accentLight: Color(0xFF2E2545),
    recordRed: Color(0xFFEF4444),
    onAccent: Color(0xFF16161A),
    rowAlternate: Color(0xFF202025),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? borderLight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? accent,
    Color? accentLight,
    Color? recordRed,
    Color? onAccent,
    Color? rowAlternate,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      borderLight: borderLight ?? this.borderLight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      recordRed: recordRed ?? this.recordRed,
      onAccent: onAccent ?? this.onAccent,
      rowAlternate: rowAlternate ?? this.rowAlternate,
    );
  }

  /// Value equality, so a rebuild with an equal palette is not mistaken for a
  /// theme change — by Flutter's own theme machinery or by our painters.
  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.background == background &&
      other.surface == surface &&
      other.borderLight == borderLight &&
      other.textPrimary == textPrimary &&
      other.textSecondary == textSecondary &&
      other.textHint == textHint &&
      other.accent == accent &&
      other.accentLight == accentLight &&
      other.recordRed == recordRed &&
      other.onAccent == onAccent &&
      other.rowAlternate == rowAlternate;

  @override
  int get hashCode => Object.hash(background, surface, borderLight, textPrimary,
      textSecondary, textHint, accent, accentLight, recordRed, onAccent,
      rowAlternate);

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      recordRed: Color.lerp(recordRed, other.recordRed, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      rowAlternate: Color.lerp(rowAlternate, other.rowAlternate, t)!,
    );
  }
}

class AppTheme {
  /// The palette for the active theme.
  ///
  /// Falls back to [AppColors.light] rather than throwing: a widget pumped in a
  /// bare `MaterialApp` — which several tests do — should render, not crash.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.light;

  static ThemeData get light => _themeFor(AppColors.light, Brightness.light);
  static ThemeData get dark => _themeFor(AppColors.dark, Brightness.dark);

  static ThemeData _themeFor(AppColors colors, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        surface: colors.surface,
      ),
      // Dialogs, sheets and snackbars are built by Material, not by this app,
      // so they take their colours from here rather than from the extension.
      dialogTheme: DialogThemeData(backgroundColor: colors.surface),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      extensions: [colors],
    );
  }
}
