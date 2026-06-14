use crate::api::data::db::db;

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
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CustomTheme {
    Default_,
    Dracula,
    Alucard,
    Solarized,
    Nord,
    Monokai,
    Gruvbox,
    CatppuccinLatte,
    CatppuccinFrappe,
    CatppuccinMacchiato,
    CatppuccinMocha,
}

impl CustomTheme {
    /// Human-readable theme name.
    ///
    /// Returns a stable string representation of the theme.
    pub fn label(&self) -> String {
        match self {
            CustomTheme::Default_ => "Default".to_string(),
            CustomTheme::Dracula => "Dracula".to_string(),
            CustomTheme::Alucard => "Alucard".to_string(),
            CustomTheme::Solarized => "Solarized".to_string(),
            CustomTheme::Nord => "Nord".to_string(),
            CustomTheme::Monokai => "Monokai".to_string(),
            CustomTheme::Gruvbox => "Gruvbox".to_string(),
            CustomTheme::CatppuccinLatte => "Catppuccin Latte".to_string(),
            CustomTheme::CatppuccinFrappe => "Catppuccin Frappé".to_string(),
            CustomTheme::CatppuccinMacchiato => "Catppuccin Macchiato".to_string(),
            CustomTheme::CatppuccinMocha => "Catppuccin Mocha".to_string(),
        }
    }

    /// Convert a persisted theme label into a theme variant.
    ///
    /// Unknown values fall back to `CustomTheme::DefaultDark`.
    ///
    /// # Examples
    ///
    /// ```rust
    /// let theme = Theme::from_label("Nord");
    /// assert_eq!(theme, Theme::Nord);
    /// ```
    pub fn from_label(s: &str) -> Self {
        match s {
            "Dracula" => CustomTheme::Dracula,
            "Alucard" => CustomTheme::Alucard,
            "Solarized" => CustomTheme::Solarized,
            "Nord" => CustomTheme::Nord,
            "Monokai" => CustomTheme::Monokai,
            "Gruvbox" => CustomTheme::Gruvbox,
            "Catppuccin Latte" => CustomTheme::CatppuccinLatte,
            "Catppuccin Frappé" => CustomTheme::CatppuccinFrappe,
            "Catppuccin Macchiato" => CustomTheme::CatppuccinMacchiato,
            "Catppuccin Mocha" => CustomTheme::CatppuccinMocha,
            _ => CustomTheme::Default_,
        }
    }

    ///Get the current theme label from database
    ///
    /// Load the currently selected theme from the application database.
    ///
    /// The value is read from the `settings` table using the
    /// `theme` setting key.
    ///
    /// # Panics
    ///
    /// Panics if:
    /// - The database cannot be opened.
    /// - The query fails.
    /// - The setting does not exist.
    pub fn load() -> String {
        let db = db();
        db.query_one(
            "SELECT value FROM settings WHERE key = ?",
            ["theme"],
            |row| row.get::<_, String>(0),
        )
        .unwrap()
        .unwrap()
    }

    /// Persist the selected theme to the application database.
    ///
    /// The theme label is stored in the `settings` table under
    /// the `theme` setting key.
    ///
    /// # Panics
    ///
    /// Panics if:
    /// - The database cannot be opened.
    /// - The update operation fails.
    pub fn save(label: &str) {
        let db = db();
        db.execute(
            "UPDATE settings SET value = ? WHERE key = ?",
            [label, "theme"],
        )
        .unwrap();
    }
}
