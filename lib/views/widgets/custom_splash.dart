import 'package:flutter/material.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Displays the application's splash screen UI.
///
/// The splash screen shows the app logo and title centered on the screen.
/// Optionally, a loading indicator can be displayed at the bottom with a
/// fade-in/fade-out animation.
class CustomSplash {
  /// Builds the splash screen widget.
  ///
  ///
  /// The [scheme] parameter provides the active [ColorScheme] used to style
  /// the splash screen text according to the application's theme.
  ///
  /// Returns a widget containing the splash screen layout.
  Widget splash(ColorScheme scheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          50,
          AppSpacing.xxxl,
          50,
          AppSpacing.xxxl,
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing app mark.
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [scheme.primary, scheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                    ),
                    child: Icon(
                      LucideIcons.shield,
                      size: 48,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text('StillAlive', style: AppText.h1(scheme)),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: 1.0,
              duration: AppMotion.medium,
              curve: AppMotion.easeIn,
              child: const LinearProgressIndicator(minHeight: 3),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}
