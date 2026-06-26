import 'package:still_alive/src/rust/api/data/db.dart';

/// Application theme selection.
///
/// This enum represents the currently selected UI theme.
///
/// Responsibilities:
/// - Define available themes.
/// - Convert database values to enum variants.
/// - Persist and load the selected theme.
///
/// Non-responsibilities:
/// - Theme colors.
/// - Material Design configuration.
/// - Flutter UI styling.
///
/// Color palettes are defined in Dart, where each theme is mapped
/// to a Material 3 `ColorScheme`.
enum CustomTheme {
  smartBell,
  dracula,
  alucard,
  nord,
  monokai,
  colbalt2,
  solarizedDark,
  solarizedLight,
  gruvboxDark,
  gruvboxLight,
  catppuccinLatte,
  catppuccinFrappe,
  catppuccinMacchiato,
  catppuccinMocha;

  /// Human-readable theme name.
  ///
  /// Returns a stable string representation of the theme.
  String label() {
    switch (this) {
      case CustomTheme.dracula:
        return "Dracula";
      case CustomTheme.alucard:
        return "Alucard";
      case CustomTheme.colbalt2:
        return "Colbalt2";
      case CustomTheme.solarizedDark:
        return "Solarized Dark";
      case CustomTheme.solarizedLight:
        return "Solarized Light";
      case CustomTheme.nord:
        return "Nord";
      case CustomTheme.monokai:
        return "Monokai";
      case CustomTheme.gruvboxDark:
        return "Gruvbox Dark";
      case CustomTheme.gruvboxLight:
        return "Gruvbox Light";
      case CustomTheme.catppuccinLatte:
        return "Catppuccin Latte";
      case CustomTheme.catppuccinFrappe:
        return "Catppuccin Frappé";
      case CustomTheme.catppuccinMacchiato:
        return "Catppuccin Macchiato";
      case CustomTheme.catppuccinMocha:
        return "Catppuccin Mocha";
      default:
        return "SmartBell";
    }
  }

  /// Convert a persisted theme label into a theme variant.
  ///
  /// Unknown values fall back to `CustomTheme.smartbell`.
  static CustomTheme fromLabel(String s) {
    switch (s) {
      case "Dracula":
        return CustomTheme.dracula;
      case "Alucard":
        return CustomTheme.alucard;
      case "Solarized Dark":
        return CustomTheme.solarizedDark;
      case "Solarized Light":
        return CustomTheme.solarizedLight;
      case "Nord":
        return CustomTheme.nord;
      case "Monokai":
        return CustomTheme.monokai;
      case "Gruvbox Dark":
        return CustomTheme.gruvboxDark;
      case "Gruvbox Light":
        return CustomTheme.gruvboxLight;
      case "Catppuccin Latte":
        return CustomTheme.catppuccinLatte;
      case "Catppuccin Frappé":
        return CustomTheme.catppuccinFrappe;
      case "Catppuccin Macchiato":
        return CustomTheme.catppuccinMacchiato;
      case "Catppuccin Mocha":
        return CustomTheme.catppuccinMocha;
      default:
        return CustomTheme.smartBell;
    }
  }

  /// Get the current theme label from database
  ///
  /// Load the currently selected theme from the application database.
  static Future<String> load() async {
    return await selectOne(
      sql: "SELECT value FROM settings WHERE key = 'theme'",
    );
  }

  /// Persist the selected theme to the application database.
  static Future<void> save(String label) async {
    await executeSql(
      sql: "UPDATE settings SET value = '$label' WHERE key = 'theme'",
    );
  }
}
