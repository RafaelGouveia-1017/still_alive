import 'package:flutter/material.dart';
import 'package:still_alive/src/rust/api/data/theme.dart';

/// Material 3 theme color definitions for the application.
///
/// Rust is responsible for storing and loading the selected theme.
///
/// Flutter is responsible for translating a theme selection into
/// a Material 3 [ThemeData] and [ColorScheme].
///
/// Theme colors should only be defined here.
class AppThemes {
  /// Builds a Material 3 [ThemeData] from a theme selection.
  ///
  /// The resulting theme is intended to be used as the root
  /// application theme:
  ///
  /// ```dart
  /// MaterialApp(
  ///   theme: AppThemes.themeData(theme),
  /// )
  /// ```
  ///
  /// The returned theme applies design-system styling for:
  /// * Material 3 support
  /// * Color schemes
  /// * Cards
  /// * Scaffold background colors
  static ThemeData getTheme(CustomTheme theme) {
    ColorScheme scheme = _scheme(theme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(color: scheme.surfaceContainer, elevation: 0),
    );
  }

  /// Returns the Material 3 color palette for a theme.
  ///
  /// Each Rust theme variant maps to a Material 3 [ColorScheme].
  ///
  /// All theme-specific colors should be centralized here.
  static ColorScheme _scheme(CustomTheme theme) {
    switch (theme) {
      case CustomTheme.default_:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D6FFF),
          brightness: Brightness.dark,
        ).copyWith(
          // Brand
          primary: Color(0xFF3D6FFF),
          onPrimary: Color(0xFFE8EAF0),
          primaryContainer: Color(0xFF253D8F),
          onPrimaryContainer: Color(0xFFE8EAF0),

          secondary: Color(0xFF6C63FF),
          onSecondary: Color(0xFFE8EAF0),
          secondaryContainer: Color(0xFF433CB8),
          onSecondaryContainer: Color(0xFFE8EAF0),

          tertiary: Color(0xFF00C9A7),
          onTertiary: Color(0xFF062019),
          tertiaryContainer: Color(0xFF005E4E),
          onTertiaryContainer: Color(0xFF062019),

          // Error
          error: Color(0xFFEF5350),
          onError: Color(0xFFE8EAF0),
          errorContainer: Color(0xFFBA1A1A),
          onErrorContainer: Color(0xFFE8EAF0),

          // Surfaces
          surfaceDim: Color(0xFF0A0B10),
          surface: Color(0xFF0E0F14),
          surfaceBright: Color(0xFF1B1D25),
          onSurface: Color(0xFFE8EAF0),
          onSurfaceVariant: Color(0xFF8A8FA3),

          // Containers
          surfaceContainerLowest: Color(0xFF08090D),
          surfaceContainerLow: Color(0xFF12141A),
          surfaceContainer: Color(0xFF16181F),
          surfaceContainerHigh: Color(0xFF1B1D25),
          surfaceContainerHighest: Color(0xFF22242D),

          // Outline
          outline: Color(0xFF444A59),
          outlineVariant: Color(0xFF2D313D),
        );

      case CustomTheme.dracula:
        return ColorScheme.fromSeed(
          seedColor: Color(0xFF6272A4),
          brightness: Brightness.dark,
        ).copyWith(
          primary: Color(0xFF6272A4),
          secondary: Color(0xFFBD93F9),

          surface: Color(0xFF282A36),
          surfaceContainerLowest: Color(0xFF282A36),
          surfaceContainerLow: Color(0xFF323543),
          surfaceContainer: Color(0xFF3A3D4D),
          surfaceContainerHigh: Color(0xFF44475A),
          surfaceContainerHighest: Color(0xFF4D5064),

          onPrimary: Color(0xFFF8F8F2),
          onSecondary: Color(0xFFF8F8F2),
          onSurface: Color(0xFFF8F8F2),

          outline: Color(0xFF6272A4),
          outlineVariant: Color(0xFF44475A),
        );

      case CustomTheme.alucard:
        return ColorScheme.fromSeed(
          seedColor: Color(0xFF6272A4),
          brightness: Brightness.light,
        ).copyWith(
          primary: Color(0xFF6272A4),
          secondary: Color(0xFFBD93F9),

          surface: Color(0xFFF8F8F2),

          surfaceContainerLowest: Color(0xFFF8F8F2),
          surfaceContainerLow: Color(0xFFF2F2EC),
          surfaceContainer: Color(0xFFECECE7),
          surfaceContainerHigh: Color(0xFFE6E6E6),
          surfaceContainerHighest: Color(0xFFD2D2D2),

          onPrimary: Color(0xFFF8F8F2),
          onSecondary: Color(0xFFF8F8F2),
          onSurface: Color(0xFF282A36),

          outline: Color(0xFF6272A4),
          outlineVariant: Color(0xFF44475A),
        );

      case CustomTheme.solarized:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF268BD2),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF268BD2),
          secondary: const Color(0xFFB58900),

          surface: const Color(0xFF002B36),

          surfaceContainerLowest: const Color(0xFF002B36),
          surfaceContainerLow: const Color(0xFF012F3B),
          surfaceContainer: const Color(0xFF033340),
          surfaceContainerHigh: const Color(0xFF073642),
          surfaceContainerHighest: const Color(0xFF586E75),

          onSurface: const Color(0xFF839496),

          outline: const Color(0xFF586E75),
          outlineVariant: const Color(0xFF586E75),
        );

      case CustomTheme.nord:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF88C0D0),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF88C0D0),
          secondary: const Color(0xFFEBCB8B),

          surface: const Color(0xFF2E3440),

          surfaceContainerLowest: const Color(0xFF2E3440),
          surfaceContainerLow: const Color(0xFF323945),
          surfaceContainer: const Color(0xFF363D4B),
          surfaceContainerHigh: const Color(0xFF3B4252),
          surfaceContainerHighest: const Color(0xFF434C5E),

          onSurface: const Color(0xFFD8DEE9),

          outline: const Color(0xFF434C5E),
          outlineVariant: const Color(0xFF4C566A),
        );

      case CustomTheme.monokai:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF66D9EF),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF66D9EF),
          secondary: const Color(0xFFE6DB74),

          surface: const Color(0xFF272822),

          surfaceContainerLowest: const Color(0xFF272822),
          surfaceContainerLow: const Color(0xFF2E2F28),
          surfaceContainer: const Color(0xFF35352F),
          surfaceContainerHigh: const Color(0xFF49483E),
          surfaceContainerHighest: const Color(0xFF75715E),

          onSurface: const Color(0xFFF8F8F2),

          outline: const Color(0xFF49483E),
          outlineVariant: const Color(0xFF75715E),
        );

      case CustomTheme.gruvbox:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF83A598),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF83A598),
          secondary: const Color(0xFFFABD2F),

          surface: const Color(0xFF282828),

          surfaceContainerLowest: const Color(0xFF282828),
          surfaceContainerLow: const Color(0xFF302E2D),
          surfaceContainer: const Color(0xFF363230),
          surfaceContainerHigh: const Color(0xFF3C3836),
          surfaceContainerHighest: const Color(0xFF504945),

          onSurface: const Color(0xFFEBDBB2),

          outline: const Color(0xFF504945),
          outlineVariant: const Color(0xFF928374),
        );

      case CustomTheme.catppuccinLatte:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E66F5), // Blue
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF1E66F5),
          secondary: const Color(0xFF8839EF),

          surface: const Color(0xFFEFF1F5),

          surfaceContainerLowest: const Color(0xFFEFF1F5),
          surfaceContainerLow: const Color(0xFFE6E9EF),
          surfaceContainer: const Color(0xFFDCE0E8),
          surfaceContainerHigh: const Color(0xFFCCD0DA),
          surfaceContainerHighest: const Color(0xFFBCC0CC),

          onSurface: const Color(0xFF4C4F69),

          outline: const Color(0xFF9CA0B0),
          outlineVariant: const Color(0xFFBCC0CC),
        );

      case CustomTheme.catppuccinFrappe:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF8CAAEE),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8CAAEE),
          secondary: const Color(0xFFCA9EE6),

          surface: const Color(0xFF303446),

          surfaceContainerLowest: const Color(0xFF303446),
          surfaceContainerLow: const Color(0xFF414559),
          surfaceContainer: const Color(0xFF51576D),
          surfaceContainerHigh: const Color(0xFF626880),
          surfaceContainerHighest: const Color(0xFF737994),

          onSurface: const Color(0xFFC6D0F5),

          outline: const Color(0xFF737994),
          outlineVariant: const Color(0xFF626880),
        );

      case CustomTheme.catppuccinMacchiato:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AADF4),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8AADF4),
          secondary: const Color(0xFFC6A0F6),

          surface: const Color(0xFF24273A),

          surfaceContainerLowest: const Color(0xFF24273A),
          surfaceContainerLow: const Color(0xFF363A4F),
          surfaceContainer: const Color(0xFF494D64),
          surfaceContainerHigh: const Color(0xFF5B6078),
          surfaceContainerHighest: const Color(0xFF6E738D),

          onSurface: const Color(0xFFCAD3F5),

          outline: const Color(0xFF6E738D),
          outlineVariant: const Color(0xFF5B6078),
        );

      case CustomTheme.catppuccinMocha:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF89B4FA),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF89B4FA),
          secondary: const Color(0xFFCBA6F7),

          surface: const Color(0xFF1E1E2E),

          surfaceContainerLowest: const Color(0xFF1E1E2E),
          surfaceContainerLow: const Color(0xFF313244),
          surfaceContainer: const Color(0xFF45475A),
          surfaceContainerHigh: const Color(0xFF585B70),
          surfaceContainerHighest: const Color(0xFF6C7086),

          onSurface: const Color(0xFFCDD6F4),

          outline: const Color(0xFF6C7086),
          outlineVariant: const Color(0xFF585B70),
        );
    }
  }
}
