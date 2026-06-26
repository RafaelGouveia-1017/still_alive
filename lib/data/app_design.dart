import 'package:flutter/material.dart';

/// Defines all Material 3 component theming used by the application.
///
/// Theme customizations should only be defined here to ensure a single
/// source of truth for visual styling.
class AppDesign {
  /// Builds a Material 3 [ThemeData] from a theme selection.
  ///
  /// The resulting theme is intended to be used with root
  /// application theme:
  ///
  /// ```dart
  /// MaterialApp(
  ///   theme: AppDesign.getDesign(AppThemes.getTheme(theme)),
  /// )
  /// ```
  ///
  /// The returned theme applies design-system styling for:
  /// * Buttons
  /// * Form inputs
  /// * Switches
  /// * Bottom navigation bars
  /// * Dividers
  /// * Typography
  static ThemeData getDesign(ThemeData themeData) {
    ColorScheme scheme = themeData.colorScheme;

    return themeData.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: AppText.body(scheme),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.onSurface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.tertiary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      textTheme: TextTheme(
        displayLarge: AppText.display(scheme),
        headlineLarge: AppText.h1(scheme),
        headlineMedium: AppText.h2(scheme),
        titleMedium: AppText.title(scheme),
        bodyLarge: AppText.body(scheme),
        bodyMedium: AppText.bodySm(scheme),
        bodySmall: AppText.caption(scheme),
        labelSmall: AppText.micro(scheme),
      ),
    );
  }
}

/// Typography definitions used throughout the application.
///
/// Provides a centralized collection of text styles that align with the
/// design system and Material 3 theme. All styles derive their colors from
/// the active [ColorScheme].
class AppText {
  /// Font features used for displaying tabular numerals.
  ///
  /// Ensures all digits occupy equal width, making countdown timers,
  /// clocks, and other numeric displays visually stable.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Largest display text style.
  ///
  /// Intended for hero content, countdown timers, and other prominent
  /// numeric or headline elements.
  static TextStyle display(ColorScheme scheme) => TextStyle(
    fontSize: 56,
    height: 1.0,
    letterSpacing: -0.5,
    color: scheme.onSurface,
    fontFeatures: tabular,
  );

  /// Primary heading style.
  ///
  /// Typically used for page titles and major section headers.
  static TextStyle h1(ColorScheme scheme) => TextStyle(
    fontSize: 34,
    height: 1.15,
    letterSpacing: -0.4,
    color: scheme.onSurface,
  );

  /// Secondary heading style.
  ///
  /// Suitable for subsection titles and supporting headings.
  static TextStyle h2(ColorScheme scheme) => TextStyle(
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.3,
    color: scheme.onSurface,
  );

  /// Medium-emphasis title style.
  ///
  /// Commonly used for card titles and list section headings.
  static TextStyle title(ColorScheme scheme) =>
      TextStyle(fontSize: 17, letterSpacing: -0.2, color: scheme.onSurface);

  /// Standard body text style.
  ///
  /// Intended for primary content and readable paragraph text.
  static TextStyle body(ColorScheme scheme) =>
      TextStyle(fontSize: 15, height: 1.4, color: scheme.onSurface);

  /// Compact body text style.
  ///
  /// Used when slightly reduced text size is required while maintaining
  /// readability.
  static TextStyle bodySm(ColorScheme scheme) =>
      TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface);

  /// Caption text style.
  ///
  /// Intended for supporting information, hints, timestamps, and metadata.
  static TextStyle caption(ColorScheme scheme) =>
      TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant);

  /// Smallest text style available in the design system.
  ///
  /// Suitable for microcopy and low-emphasis labels.
  static TextStyle micro(ColorScheme scheme) =>
      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);

  /// Uppercase tracked label style.
  ///
  /// Commonly used for section dividers, category labels,
  /// and navigation group headings.
  static TextStyle sectionLabel(ColorScheme scheme) => TextStyle(
    fontSize: 11,
    letterSpacing: 1.3,
    color: scheme.onSurfaceVariant,
  );

  /// Compact pill label style.
  ///
  /// Color is intentionally omitted and should be supplied by the widget
  /// using the style.
  // Pill labels — uppercase tracked, color set per-instance
  static const TextStyle pillLabel = TextStyle(
    fontSize: 11,
    letterSpacing: 1.0,
  );
}

/// Design-system spacing tokens based on a 4-point grid.
///
/// These values should be used instead of hardcoded spacing to ensure
/// consistent layouts throughout the application.
class AppSpacing {
  /// Extra-small spacing (4px).
  static const double xs = 4;

  /// Small spacing (8px).
  static const double sm = 8;

  /// Medium spacing (12px).
  static const double md = 12;

  /// Large spacing (16px).
  static const double lg = 16;

  /// Extra-large spacing (20px).
  static const double xl = 20;

  /// Double extra-large spacing (24px).
  static const double xxl = 24;

  /// Triple extra-large spacing (32px).
  static const double xxxl = 32;

  /// Standard horizontal padding applied to application screens.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 28);

  /// Default internal padding for cards and card-like surfaces.
  static const EdgeInsets card = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );

  /// Default internal padding for primary buttons.
  static const EdgeInsets primaryButton = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );
}

/// Border radius tokens used throughout the application.
///
/// Centralizing corner radius values helps maintain visual consistency
/// across cards, buttons, chips, and other components.
class AppRadius {
  /// Small radius (8px).
  static const double sm = 8;

  /// Medium radius (12px).
  static const double md = 12;

  /// Large radius (16px).
  ///
  /// Used as the default radius for cards and buttons.
  static const double lg = 16;

  /// Extra-large radius (20px).
  static const double xl = 20;

  /// Double extra-large radius (24px).
  static const double xxl = 24;

  /// Fully rounded radius used for pills and badges.
  static const double pill = 999;

  /// Default card border radius.
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));

  /// Default button border radius.
  static const BorderRadius button = BorderRadius.all(Radius.circular(lg));

  /// Fully rounded border radius used for chips and pill elements.
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}

/// Shadow presets used throughout the application.
///
/// These shadows provide consistent elevation effects while matching
/// the visual style of the design system.
class AppShadows {
  /// Creates a subtle elevated shadow suitable for buttons.
  ///
  /// The provided [color] is used as the shadow tint and adjusted
  /// for transparency.
  static List<BoxShadow> buttonShadow(Color color) => [
    BoxShadow(
      color: color.withAlpha(153),
      blurRadius: 24,
      spreadRadius: -8,
      offset: Offset(0, 8),
    ),
  ];

  /// Creates a large ambient shadow for elevated containers,
  /// overlays, and highlighted surfaces.
  ///
  /// The provided [color] is used as the shadow tint and adjusted
  /// for transparency.
  static List<BoxShadow> boxShadow(Color color) => [
    BoxShadow(
      color: color.withAlpha(153),
      blurRadius: 50,
      spreadRadius: -20,
      offset: Offset(0, 20),
    ),
  ];
}

/// Motion tokens used for animations and transitions.
class AppMotion {
  /// Fastest animation duration (100ms).
  static const Duration fastest = Duration(milliseconds: 100);

  /// Very short animation duration (500ms).
  static const Duration faster = Duration(milliseconds: 500);

  /// Short animation duration (1s).
  static const Duration fast = Duration(seconds: 1);

  /// Standard animation duration (2s).
  static const Duration medium = Duration(seconds: 2);

  /// Slow animation duration (5s).
  static const Duration slow = Duration(seconds: 5);

  /// Slowest animation duration (10s).
  static const Duration slowest = Duration(seconds: 10);

  /// Route transition duration (220ms).
  ///
  /// Mirrors AnimatePresence screen transitions on the web.
  static const Duration screen = Duration(milliseconds: 220);

  /// Countdown ring reveal animation duration (1100ms).
  static const Duration ring = Duration(milliseconds: 1100);

  /// Pulse animation cycle duration (1400ms).
  static const Duration pulse = Duration(milliseconds: 1400);

  /// Duration used for pre-alert countdown depletion (30s).
  static const Duration preAlert = Duration(seconds: 30);

  /// Emphasized easing curve.
  ///
  /// Primarily used for reveal and entrance animations.
  static const Curve emphasized = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Standard easing curve.
  ///
  /// Used for route transitions and general UI animations.
  static const Curve standard = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Ease-in animation curve.
  static const Curve easeIn = Curves.easeIn;

  /// Ease-out animation curve.
  static const Curve easeOut = Curves.easeOut;

  /// Ease-in-out animation curve.
  static const Curve easeInOut = Curves.easeInOut;

  /// Linear animation curve.
  ///
  /// Intended for progress indicators and countdown depletion.
  static const Curve linear = Curves.linear;
}

/// Supported route transition animations.
///
/// Used by [AppRoute] to determine how a new page enters the screen.
enum AppRouteTransitionType {
  /// Fade with a slight horizontal slide.
  fade,

  /// Slide from right to left.
  slideLeft,

  /// Slide from left to right.
  slideRight,

  /// Slide upward from the bottom edge.
  slideUp,

  /// Slide downward from the top edge.
  slideDown,
}

/// Custom page route implementation that applies design-system
/// transition animations.
///
/// This route provides platform-consistent navigation animations.
///
/// Example:
///
/// ```dart
/// Navigator.of(context).push(
///   AppRoute(
///     page: const SettingsPage(),
///     transition: AppRouteTransitionType.slideLeft,
///   ),
/// );
/// ```
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required Widget page, required AppRouteTransitionType transition})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.standard,
          );
          switch (transition) {
            case AppRouteTransitionType.fade:
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );

            case AppRouteTransitionType.slideLeft:
              return SlideTransition(
                position: Tween(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );

            case AppRouteTransitionType.slideRight:
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );

            case AppRouteTransitionType.slideUp:
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );

            case AppRouteTransitionType.slideDown:
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, -1.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
          }
        },
        transitionDuration: AppMotion.screen,
      );
}
