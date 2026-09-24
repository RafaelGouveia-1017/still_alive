import 'package:flutter/material.dart';
import 'package:still_alive/data/custom_theme.dart';

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
      case CustomTheme.smartBell:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF3D6FFF), brightness: Brightness.dark).copyWith(
          // Brand
          primary: const Color(0xFF3D6FFF),
          onPrimary: const Color(0xFFE8EAF0),
          primaryContainer: const Color(0xFF253D8F),
          onPrimaryContainer: const Color(0xFFE8EAF0),

          secondary: const Color(0xFF6C63FF),
          onSecondary: const Color(0xFFE8EAF0),
          secondaryContainer: const Color(0xFF433CB8),
          onSecondaryContainer: const Color(0xFFE8EAF0),

          tertiary: const Color(0xFF00C9A7),
          onTertiary: const Color(0xFF062019),
          tertiaryContainer: const Color(0xFF005E4E),
          onTertiaryContainer: const Color(0xFF062019),

          // Error
          error: const Color(0xFFEF5350),
          onError: const Color(0xFFE8EAF0),
          errorContainer: const Color(0xFFBA1A1A),
          onErrorContainer: const Color(0xFFE8EAF0),

          // Surfaces
          surfaceDim: const Color(0xFF0A0B10),
          surface: const Color(0xFF0E0F14),
          surfaceBright: const Color(0xFF1B1D25),
          onSurface: const Color(0xFFE8EAF0),
          onSurfaceVariant: const Color(0xFF8A8FA3),

          // Containers
          surfaceContainerLowest: const Color(0xFF08090D),
          surfaceContainerLow: const Color(0xFF12141A),
          surfaceContainer: const Color(0xFF16181F),
          surfaceContainerHigh: const Color(0xFF1B1D25),
          surfaceContainerHighest: const Color(0xFF22242D),

          // Outline
          outline: const Color(0xFF444A59),
          outlineVariant: const Color(0xFF2D313D),
        );

      case CustomTheme.dracula:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF6272A4), brightness: Brightness.dark).copyWith(
          primary: const Color(0xFF6272A4),
          onPrimary: const Color(0xFFF8F8F2),
          primaryContainer: const Color(0xFF44475A),
          onPrimaryContainer: const Color(0xFFF8F8F2),

          secondary: const Color(0xFFBD93F9),
          onSecondary: const Color(0xFF282A36),
          secondaryContainer: const Color(0xFF5B3A82),
          onSecondaryContainer: const Color(0xFFF8F8F2),

          tertiary: const Color(0xFFE2BBDC),
          onTertiary: const Color(0xFF282A36),
          tertiaryContainer: const Color(0xFF5A4057),
          onTertiaryContainer: const Color(0xFFFFD7F7),

          error: const Color(0xFFFF5555),
          onError: const Color(0xFF2A1111),
          errorContainer: const Color(0xFF7A2929),
          onErrorContainer: const Color(0xFFFFDAD6),

          surfaceDim: const Color(0xFF20212B),
          surface: const Color(0xFF282A36),
          surfaceBright: const Color(0xFF323543),
          onSurface: const Color(0xFFF8F8F2),
          onSurfaceVariant: const Color(0xFFBFC3D1),

          surfaceContainerLowest: const Color(0xFF2D2F3C),
          surfaceContainerLow: const Color(0xFF323543),
          surfaceContainer: const Color(0xFF3A3D4D),
          surfaceContainerHigh: const Color(0xFF44475A),
          surfaceContainerHighest: const Color(0xFF4D5064),

          outline: const Color(0xFF6272A4),
          outlineVariant: const Color(0xFF44475A),
        );

      case CustomTheme.alucard:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF6272A4), brightness: Brightness.light).copyWith(
          primary: const Color(0xFF6272A4),
          onPrimary: const Color(0xFFF8F8F2),
          primaryContainer: const Color(0xFFD8DCE8),
          onPrimaryContainer: const Color(0xFF282A36),

          secondary: const Color(0xFFBD93F9),
          onSecondary: const Color(0xFF282A36),
          secondaryContainer: const Color(0xFFE8D8FF),
          onSecondaryContainer: const Color(0xFF392052),

          tertiary: const Color(0xFFE2BBDC),
          onTertiary: const Color(0xFF282A36),
          tertiaryContainer: const Color(0xFFF3DDEA),
          onTertiaryContainer: const Color(0xFF392536),

          error: const Color(0xFFFF5555),
          onError: const Color(0xFFF8F8F2),
          errorContainer: const Color(0xFFFFDAD6),
          onErrorContainer: const Color(0xFF410002),

          surfaceDim: const Color(0xFFD2D2CC),
          surface: const Color(0xFFF8F8F2),
          surfaceBright: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF282A36),
          onSurfaceVariant: const Color(0xFF555867),

          surfaceContainerLowest: const Color(0xFFFFFFFF),
          surfaceContainerLow: const Color(0xFFF2F2EC),
          surfaceContainer: const Color(0xFFECECE7),
          surfaceContainerHigh: const Color(0xFFE6E6E0),
          surfaceContainerHighest: const Color(0xFFD2D2D2),

          outline: const Color(0xFF6272A4),
          outlineVariant: const Color(0xFF44475A),
        );

      case CustomTheme.colbalt2:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFFFC600), brightness: Brightness.dark).copyWith(
          primary: const Color(0xFFFFC600),
          onPrimary: const Color(0xFF122738),
          primaryContainer: const Color(0xFF0088FF),
          onPrimaryContainer: const Color(0xFFFFFFFF),

          secondary: const Color(0xFF80FCFF),
          onSecondary: const Color(0xFF122738),
          secondaryContainer: const Color(0xFF0050A4),
          onSecondaryContainer: const Color(0xFFFFFFFF),

          tertiary: const Color(0xFF3AD900),
          onTertiary: const Color(0xFF122738),
          tertiaryContainer: const Color(0xFFFB94FF),
          onTertiaryContainer: const Color(0xFF122738),

          error: const Color(0xFFFF628C),
          onError: const Color(0xFF122738),
          errorContainer: const Color(0xFF000000),
          onErrorContainer: const Color(0xFFFFFFFF),

          surfaceDim: const Color(0xFF122738),
          surface: const Color(0xFF122738),
          surfaceBright: const Color(0xFF1A3A52),
          onSurface: const Color(0xFFFFFFFF),
          onSurfaceVariant: const Color(0xFF80FCFF),

          surfaceContainerLowest: const Color(0xFF0B1824),
          surfaceContainerLow: const Color(0xFF102030),
          surfaceContainer: const Color(0xFF17324A),
          surfaceContainerHigh: const Color(0xFF1A3A52),
          surfaceContainerHighest: const Color(0xFF285A83),

          outline: const Color(0xFF0050A4),
          outlineVariant: const Color(0xFF0088FF),
        );

      case CustomTheme.solarizedDark:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFB58900), brightness: Brightness.dark).copyWith(
          primary: const Color(0xFFB58900),
          onPrimary: const Color(0xFF002B36),
          primaryContainer: const Color(0xFF268BD2),
          onPrimaryContainer: const Color(0xFFEEE8D5),

          secondary: const Color(0xFF2AA198),
          onSecondary: const Color(0xFF002B36),
          secondaryContainer: const Color(0xFF93A1A1),
          onSecondaryContainer: const Color(0xFFEEE8D5),

          tertiary: const Color(0xFF859900),
          onTertiary: const Color(0xFF002B36),
          tertiaryContainer: const Color(0xFF6C71C4),
          onTertiaryContainer: const Color(0xFFEEE8D5),

          error: const Color(0xFFDC322F),
          onError: const Color(0xFF002B36),
          errorContainer: const Color(0xFFCB4B16),
          onErrorContainer: const Color(0xFFEEE8D5),

          surfaceDim: const Color(0xFF002B36),
          surface: const Color(0xFF002B36),
          surfaceBright: const Color(0xFF073642),
          onSurface: const Color(0xFFABC9CC),
          onSurfaceVariant: const Color(0xFF88A9B3),

          surfaceContainerLowest: const Color(0xFF001F27),
          surfaceContainerLow: const Color(0xFF002B36),
          surfaceContainer: const Color(0xFF073642),
          surfaceContainerHigh: const Color(0xFF0A3A46),
          surfaceContainerHighest: const Color(0xFF0E4A57),

          outline: const Color(0xFF586E75),
          outlineVariant: const Color(0xFF073642),
        );

      case CustomTheme.solarizedLight:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF2AA198), brightness: Brightness.light).copyWith(
          primary: const Color(0xFF2AA198),
          onPrimary: const Color(0xFFFDF6E3),
          primaryContainer: const Color(0xFF268BD2),
          onPrimaryContainer: const Color(0xFF073642),

          secondary: const Color(0xFF268BD2),
          onSecondary: const Color(0xFFFDF6E3),
          secondaryContainer: const Color(0xFF93A1A1),
          onSecondaryContainer: const Color(0xFF073642),

          tertiary: const Color(0xFF859900),
          onTertiary: const Color(0xFFFDF6E3),
          tertiaryContainer: const Color(0xFFB58900),
          onTertiaryContainer: const Color(0xFF073642),

          error: const Color(0xFFDC322F),
          onError: const Color(0xFFFDF6E3),
          errorContainer: const Color(0xFFCB4B16),
          onErrorContainer: const Color(0xFFFDF6E3),

          surfaceDim: const Color(0xFFFDF6E3),
          surface: const Color(0xFFFDF6E3),
          surfaceBright: const Color(0xFFEEE8D5),
          onSurface: const Color(0xFF657B83),
          onSurfaceVariant: const Color(0xFF586E75),

          surfaceContainerLowest: const Color(0xFFFAF0D5),
          surfaceContainerLow: const Color(0xFFFDF6E3),
          surfaceContainer: const Color(0xFFF5E9C8),
          surfaceContainerHigh: const Color(0xFFE6D9B8),
          surfaceContainerHighest: const Color(0xFFD8CBA0),

          outline: const Color(0xFF586E75),
          outlineVariant: const Color(0xFF93A1A1),
        );

      case CustomTheme.nord:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF88C0D0), brightness: Brightness.dark).copyWith(
          primary: const Color(0xFF88C0D0),
          onPrimary: const Color(0xFF2E3440),
          primaryContainer: const Color(0xFF81A1C1),
          onPrimaryContainer: const Color(0xFFE5E9F0),

          secondary: const Color(0xFF8FBCBB),
          onSecondary: const Color(0xFF2E3440),
          secondaryContainer: const Color(0xFF81A1C1),
          onSecondaryContainer: const Color(0xFFE5E9F0),

          tertiary: const Color(0xFFA3BE8C),
          onTertiary: const Color(0xFF2E3440),
          tertiaryContainer: const Color(0xFFB48EAD),
          onTertiaryContainer: const Color(0xFFE5E9F0),

          error: const Color(0xFFBF616A),
          onError: const Color(0xFF2E3440),
          errorContainer: const Color(0xFF3B4252),
          onErrorContainer: const Color(0xFFECEFF4),

          surfaceDim: const Color(0xFF2E3440),
          surface: const Color(0xFF2E3440),
          surfaceBright: const Color(0xFF3B4252),
          onSurface: const Color(0xFFD8DEE9),
          onSurfaceVariant: const Color(0xFFAAB8D3),

          surfaceContainerLowest: const Color(0xFF242933),
          surfaceContainerLow: const Color(0xFF2E3440),
          surfaceContainer: const Color(0xFF343B48),
          surfaceContainerHigh: const Color(0xFF3B4252),
          surfaceContainerHighest: const Color(0xFF434C5E),

          outline: const Color(0xFF4C566A),
          outlineVariant: const Color(0xFF3B4252),
        );

      case CustomTheme.monokai:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF66D9EF), brightness: Brightness.dark).copyWith(
          // Primary
          primary: const Color(0xFF66D9EF),
          onPrimary: const Color(0xFF272822),
          primaryContainer: const Color(0xFF49483E),
          onPrimaryContainer: const Color(0xFFF8F8F2),

          // Secondary
          secondary: const Color(0xFFE6DB74),
          onSecondary: const Color(0xFF272822),
          secondaryContainer: const Color(0xFF75715E),
          onSecondaryContainer: const Color(0xFFF8F8F2),

          // Tertiary
          tertiary: const Color(0xFFA6E22E),
          onTertiary: const Color(0xFF272822),
          tertiaryContainer: const Color(0xFF49483E),
          onTertiaryContainer: const Color(0xFFF8F8F2),

          // Error
          error: const Color(0xFFF92672),
          onError: const Color(0xFF272822),
          errorContainer: const Color(0xFF49483E),
          onErrorContainer: const Color(0xFFF8F8F2),

          // Surfaces
          surface: const Color(0xFF272822),
          surfaceDim: const Color(0xFF1F201B),
          surfaceBright: const Color(0xFF35352F),

          surfaceContainerLowest: const Color(0xFF1F201B),
          surfaceContainerLow: const Color(0xFF272822),
          surfaceContainer: const Color(0xFF2E2F28),
          surfaceContainerHigh: const Color(0xFF35352F),
          surfaceContainerHighest: const Color(0xFF49483E),

          onSurface: const Color(0xFFF8F8F2),
          onSurfaceVariant: const Color(0xFFE6DB74),

          // Outline
          outline: const Color(0xFF49483E),
          outlineVariant: const Color(0xFF75715E),
        );

      case CustomTheme.gruvboxDark:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFD65D0E), brightness: Brightness.dark).copyWith(
          primary: const Color(0xFFD65D0E),
          onPrimary: const Color(0xFF282828),
          primaryContainer: const Color(0xFF458588),
          onPrimaryContainer: const Color(0xFFEBDBB2),

          secondary: const Color(0xFF689D6A),
          onSecondary: const Color(0xFF282828),
          secondaryContainer: const Color(0xFF83A598),
          onSecondaryContainer: const Color(0xFFEBDBB2),

          tertiary: const Color(0xFF8EC07C),
          onTertiary: const Color(0xFF282828),
          tertiaryContainer: const Color(0xFFB8BB26),
          onTertiaryContainer: const Color(0xFF282828),

          error: const Color(0xFFFB4934),
          onError: const Color(0xFF282828),
          errorContainer: const Color(0xFFCC241D),
          onErrorContainer: const Color(0xFFEBDBB2),

          surfaceDim: const Color(0xFF282828),
          surface: const Color(0xFF282828),
          surfaceBright: const Color(0xFF3C3836),
          onSurface: const Color(0xFFEBDBB2),
          onSurfaceVariant: const Color(0xFFA89984),

          surfaceContainerLowest: const Color(0xFF1D1D1D),
          surfaceContainerLow: const Color(0xFF222222),
          surfaceContainer: const Color(0xFF282828),
          surfaceContainerHigh: const Color(0xFF32302F),
          surfaceContainerHighest: const Color(0xFF3C3836),

          outline: const Color(0xFF928374),
          outlineVariant: const Color(0xFF504945),
        );

      case CustomTheme.gruvboxLight:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFD65D0E), brightness: Brightness.light).copyWith(
          primary: const Color(0xFFD65D0E),
          onPrimary: const Color(0xFFFBF1C7),
          primaryContainer: const Color(0xFF7C6F64),
          onPrimaryContainer: const Color(0xFF3C3836),

          secondary: const Color(0xFF689D6A),
          onSecondary: const Color(0xFFFBF1C7),
          secondaryContainer: const Color(0xFF458588),
          onSecondaryContainer: const Color(0xFF3C3836),

          tertiary: const Color(0xFF98971A),
          onTertiary: const Color(0xFFFBF1C7),
          tertiaryContainer: const Color(0xFFD79921),
          onTertiaryContainer: const Color(0xFF3C3836),

          error: const Color(0xFFCC241D),
          onError: const Color(0xFFFBF1C7),
          errorContainer: const Color(0xFF9D0006),
          onErrorContainer: const Color(0xFFFBF1C7),

          surfaceDim: const Color(0xFFFBF1C7),
          surface: const Color(0xFFFBF1C7),
          surfaceBright: const Color(0xFFEBDBB2),
          onSurface: const Color(0xFF3C3836),
          onSurfaceVariant: const Color(0xFF7C6F64),

          surfaceContainerLowest: const Color(0xFFF2E5BC),
          surfaceContainerLow: const Color(0xFFFBF1C7),
          surfaceContainer: const Color(0xFFEDE0B5),
          surfaceContainerHigh: const Color(0xFFD5C4A1),
          surfaceContainerHighest: const Color(0xFFBDAE93),

          outline: const Color(0xFF7C6F64),
          outlineVariant: const Color(0xFF928374),
        );

      case CustomTheme.catppuccinLatte:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF7287FD), brightness: Brightness.light).copyWith(
          // Brand
          primary: const Color(0xFF7287FD),
          onPrimary: const Color(0xFFEFF1F5),
          primaryContainer: const Color(0xFFBCC0CC),
          onPrimaryContainer: const Color(0xFF4C4F69),

          secondary: const Color(0xFF1E66F5),
          onSecondary: const Color(0xFFEFF1F5),
          secondaryContainer: const Color(0xFF456EFF),
          onSecondaryContainer: const Color(0xFF4C4F69),

          tertiary: const Color(0xFF179299),
          onTertiary: const Color(0xFFEFF1F5),
          tertiaryContainer: const Color(0xFF2D9FA8),
          onTertiaryContainer: const Color(0xFF4C4F69),

          // Error
          error: const Color(0xFFD20F39),
          onError: const Color(0xFFEFF1F5),
          errorContainer: const Color(0xFFDE293E),
          onErrorContainer: const Color(0xFFEFF1F5),

          // Surfaces
          surfaceDim: const Color(0xFFEFF1F5),
          surface: const Color(0xFFEFF1F5),
          surfaceBright: const Color(0xFFBCC0CC),
          onSurface: const Color(0xFF4C4F69),
          onSurfaceVariant: const Color(0xFF6C6F85),

          // Containers
          surfaceContainerLowest: const Color(0xFFE6E9EF),
          surfaceContainerLow: const Color(0xFFEFF1F5),
          surfaceContainer: const Color(0xFFDCE0E8),
          surfaceContainerHigh: const Color(0xFFCCD0DA),
          surfaceContainerHighest: const Color(0xFFBCC0CC),

          // Outline
          outline: const Color(0xFF6C6F85),
          outlineVariant: const Color(0xFFACB0BE),
        );

      case CustomTheme.catppuccinFrappe:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFBABBF1), brightness: Brightness.dark).copyWith(
          // Brand
          primary: const Color(0xFFBABBF1),
          onPrimary: const Color(0xFF303446),
          primaryContainer: const Color(0xFF51576D),
          onPrimaryContainer: const Color(0xFFE8EAF0),

          secondary: const Color(0xFF8CAAEF),
          onSecondary: const Color(0xFF303446),
          secondaryContainer: const Color(0xFF7B9EF0),
          onSecondaryContainer: const Color(0xFFE8EAF0),

          tertiary: const Color(0xFF81C8BE),
          onTertiary: const Color(0xFF062019),
          tertiaryContainer: const Color(0xFF5ABFB5),
          onTertiaryContainer: const Color(0xFF062019),

          // Error
          error: const Color(0xFFE78284),
          onError: const Color(0xFF303446),
          errorContainer: const Color(0xFFBA1A1A),
          onErrorContainer: const Color(0xFFE8EAF0),

          // Surfaces
          surfaceDim: const Color(0xFF303446),
          surface: const Color(0xFF303446),
          surfaceBright: const Color(0xFF414559),
          onSurface: const Color(0xFFC6D0F5),
          onSurfaceVariant: const Color(0xFF8A8FA3),

          // Containers
          surfaceContainerLowest: const Color(0xFF292C3C),
          surfaceContainerLow: const Color(0xFF313448),
          surfaceContainer: const Color(0xFF3A3D4F),
          surfaceContainerHigh: const Color(0xFF414559),
          surfaceContainerHighest: const Color(0xFF51576D),

          // Outline
          outline: const Color(0xFF626880),
          outlineVariant: const Color(0xFF51576D),
        );

      case CustomTheme.catppuccinMacchiato:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFB7BDF8), brightness: Brightness.dark).copyWith(
          // Brand
          primary: const Color(0xFFB7BDF8),
          onPrimary: const Color(0xFF24273A),
          primaryContainer: const Color(0xFF494D64),
          onPrimaryContainer: const Color(0xFFCAD3F5),

          secondary: const Color(0xFF8AADF4),
          onSecondary: const Color(0xFF24273A),
          secondaryContainer: const Color(0xFF78A1F6),
          onSecondaryContainer: const Color(0xFFCAD3F5),

          tertiary: const Color(0xFF8BD5CA),
          onTertiary: const Color(0xFF062019),
          tertiaryContainer: const Color(0xFF63CBC0),
          onTertiaryContainer: const Color(0xFF062019),

          // Error
          error: const Color(0xFFED8796),
          onError: const Color(0xFF24273A),
          errorContainer: const Color(0xFFEC7486),
          onErrorContainer: const Color(0xFFCAD3F5),

          // Surfaces
          surfaceDim: const Color(0xFF24273A),
          surface: const Color(0xFF24273A),
          surfaceBright: const Color(0xFF363A4F),
          onSurface: const Color(0xFFCAD3F5),
          onSurfaceVariant: const Color(0xFFA5ADCB),

          // Containers
          surfaceContainerLowest: const Color(0xFF1E2030),
          surfaceContainerLow: const Color(0xFF24273A),
          surfaceContainer: const Color(0xFF2B2F42),
          surfaceContainerHigh: const Color(0xFF363A4F),
          surfaceContainerHighest: const Color(0xFF494D64),

          // Outline
          outline: const Color(0xFF5B6078),
          outlineVariant: const Color(0xFF494D64),
        );

      case CustomTheme.catppuccinMocha:
        return ColorScheme.fromSeed(seedColor: const Color(0xFFB4BEFE), brightness: Brightness.dark).copyWith(
          // Brand
          primary: const Color(0xFFB4BEFE),
          onPrimary: const Color(0xFF1E1E2E),
          primaryContainer: const Color(0xFF45475A),
          onPrimaryContainer: const Color(0xFFCDD6F4),

          secondary: const Color(0xFF89B4FA),
          onSecondary: const Color(0xFF1E1E2E),
          secondaryContainer: const Color(0xFF74A8FC),
          onSecondaryContainer: const Color(0xFFCDD6F4),

          tertiary: const Color(0xFF94E2D5),
          onTertiary: const Color(0xFF062019),
          tertiaryContainer: const Color(0xFF6BD7CA),
          onTertiaryContainer: const Color(0xFF062019),

          // Error
          error: const Color(0xFFF38BA8),
          onError: const Color(0xFF1E1E2E),
          errorContainer: const Color(0xFFF37799),
          onErrorContainer: const Color(0xFFCDD6F4),

          // Surfaces
          surfaceDim: const Color(0xFF1E1E2E),
          surface: const Color(0xFF1E1E2E),
          surfaceBright: const Color(0xFF313244),
          onSurface: const Color(0xFFCDD6F4),
          onSurfaceVariant: const Color(0xFFA6ADC8),

          // Containers
          surfaceContainerLowest: const Color(0xFF181825),
          surfaceContainerLow: const Color(0xFF1E1E2E),
          surfaceContainer: const Color(0xFF242438),
          surfaceContainerHigh: const Color(0xFF313244),
          surfaceContainerHighest: const Color(0xFF45475A),

          // Outline
          outline: const Color(0xFF585B70),
          outlineVariant: const Color(0xFF45475A),
        );
    }
  }
}
