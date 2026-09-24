import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:still_alive/services/native/method_channel.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

/// Handles loading and retrieving localized strings for the application.
///
/// This class implements a JSON-based localization system where translation
/// files can contain nested objects. These nested structures are flattened
/// into a single map using a **Depth-First Search (DFS) traversal algorithm
/// with prefix accumulation**.
///
/// ## Flattening Algorithm Context (DFS)
///
/// The localization JSON is treated as a tree:
///
/// ```json
/// {
///   "home": {
///     "title": "Home"
///   }
/// }
/// ```
///
/// This structure is recursively traversed using DFS:
///
/// * Each node is visited once (O(n))
/// * A prefix string tracks the hierarchical path
/// * Nested keys are concatenated using dot notation (e.g., `home.title`)
///
/// This results in a flat key-value map optimized for O(1) lookup.
///
/// ### Example output:
/// ```
/// {
///   "home.title": "Home"
/// }
/// ```
class AppLocalizations {
  final Locale locale;

  /// Flattened key-value map of translation strings.
  /// Keys use dot notation (e.g. `home.title`).
  late Map<String, String> _strings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Loads and parses the JSON localization file for the current locale.
  ///
  /// This method:
  /// 1. Reads the JSON file from assets
  /// 2. Decodes it into a Map
  /// 3. Flattens nested structures using **DFS** traversal
  /// 4. Stores results in [_strings] for fast lookup
  ///
  /// Returns `true` when loading is complete.
  Future<bool> load() async {
    final jsonString = await rootBundle.loadString('lib/assets/lang/${locale.languageCode}.json');

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    _strings = {};

    /// DFS algorithm logic
    final path = <String>[];
    void flatten(Map<String, dynamic> map) {
      void dfs(dynamic node) {
        if (node is Map<String, dynamic>) {
          for (final entry in node.entries) {
            path.add(entry.key);
            dfs(entry.value);
            path.removeLast();
          }
        } else if (node is List) {
          for (var i = 0; i < node.length; i++) {
            path.add(i.toString());
            dfs(node[i]);
            path.removeLast();
          }
        } else {
          _strings[path.join('.')] = node.toString();
        }
      }

      dfs(map);
    }

    flatten(jsonMap);

    return true;
  }

  /// Retrieves a localized string by its key.
  ///
  /// The key must follow dot notation if nested JSON is used:
  /// Example:
  /// * `home.title`
  /// * `settings.language`
  ///
  /// If the key is not found, the key itself is returned as fallback.
  String translate(String key) {
    return _strings[key] ?? key;
  }
}

/// A language config model.
///
/// Stores a Locale object and its corresponding name in said locale.
class AppLanguage {
  final Locale locale;
  final String label;

  const AppLanguage(this.locale, this.label);
}

/// A [LocalizationsDelegate] implementation that integrates
/// [AppLocalizations] with Flutter's localization system.
///
/// This delegate:
/// * Declares supported locales
/// * Loads localization data per locale
/// * Prevents unnecessary reloads
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  /// List of supported locales in the application.
  static const List<AppLanguage> supportedLocales = [AppLanguage(Locale('en'), "English"), AppLanguage(Locale('pt'), "Português")];

  @override
  bool isSupported(Locale locale) {
    return supportedLocales
        .map((lang) {
          return lang.locale;
        })
        .contains(locale);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  /// Determines whether the delegate should reload when dependencies change.
  ///
  /// Since localization data is static per locale,
  /// this returns `false` to avoid unnecessary rebuilds.
  @override
  bool shouldReload(covariant LocalizationsDelegate old) => false;
}

/// Manages the application's current locale and persists user selection.
///
/// This class is responsible for:
/// * Storing the active locale
/// * Loading saved locale from persistent storage
/// * Updating locale dynamically at runtime
/// * Notifying listeners when changes occur
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  /// Returns the currently active locale.
  Locale get locale => _locale;

  /// Loads the previously saved language from persistent storage.
  Future<void> loadSavedLocale() async {
    final code = await selectOne(sql: "SELECT value FROM settings WHERE key = 'lang'");

    if (AppLocalizationsDelegate.supportedLocales.any((l) => l.locale.languageCode == code)) {
      _locale = Locale(code);
    }

    notifyListeners();
  }

  /// Updates the application's locale and persists the selection.
  ///
  /// The locale must be supported by [AppLocalizationsDelegate].
  Future<void> setLocale(Locale locale) async {
    if (!AppLocalizationsDelegate().isSupported(locale)) return;

    _locale = locale;
    await executeSql(sql: "UPDATE settings SET value = '${locale.languageCode}' WHERE key = 'lang'");

    await AppMethodChannel.instance.invokeMethod('setLocale', {'languageCode': locale.languageCode});

    notifyListeners();
  }
}
