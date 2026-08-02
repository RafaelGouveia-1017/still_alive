import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/views/widgets/primitives.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/all.dart';
import 'package:restart_app/restart_app.dart';

/// Represents the different stages of the global unexpected error dialog.
///
/// The dialog starts in the [initial] state, transitions to [saving] while
/// a diagnostic log is being generated, and finally reaches [saved] once
/// the log has been successfully written.
enum GlobalErrorDialogState {
  /// The initial state, allowing the user to save a diagnostic log,
  /// restart the application, or exit the dialog.
  initial,

  /// Indicates that a diagnostic log is currently being generated.
  ///
  /// During this state, the dialog displays a loading indicator and
  /// user interaction is temporarily disabled.
  saving,

  /// Indicates that the diagnostic log has been successfully saved.
  ///
  /// The dialog allows the user to restart the application or exit,
  /// and provides a link to the project's issue tracker.
  saved,
}

/// Displays a modal dialog when the application encounters an unrecoverable
/// error.
///
/// The dialog guides the user through exporting a diagnostic log before
/// restarting or closing the application. It also provides a link to the
/// project's issue tracker so the generated log can be attached to a bug
/// report.
///
/// The dialog manages its own state internally through
/// [GlobalErrorDialogState].
class GlobalErrorDialog {
  /// Indicates whether an error occurred before the application UI was ready
  /// to display the error dialog.
  ///
  /// If an error happens before the [Navigator] context becomes available,
  /// this flag is set to `true` so the dialog can be displayed once the
  /// application has finished initializing.
  static bool _pendingError = false;

  /// Returns whether there is a pending error dialog waiting to be displayed.
  ///
  /// This is used after application startup to determine if an error occurred
  /// before the widget tree was available.
  static bool get hasPendingError => _pendingError;

  /// Indicates whether the global error dialog is currently visible.
  ///
  /// This prevents multiple error dialogs from being displayed simultaneously
  /// when the same failure triggers multiple error handlers.
  static bool _visible = false;

  /// Displays the global error dialog.
  ///
  /// Before showing the dialog, the current navigation stack is popped back
  /// to the root route to ensure the dialog is presented from a consistent
  /// application state.
  ///
  /// The dialog cannot be dismissed by tapping outside of it. Depending on
  /// the current [state], it allows the user to:
  ///
  /// - Save a diagnostic log.
  /// - Restart the application.
  /// - Exit the dialog.
  ///
  /// If log generation succeeds, the dialog transitions to the
  /// [GlobalErrorDialogState.saved] state.
  static void show() {
    if (_visible) return;
    _visible = true;

    final context = PermissionManager.instance.navigatorKey.currentContext;
    if (context == null) {
      _pendingError = true;
      return;
    }

    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    Navigator.of(context).popUntil((route) => false);

    GlobalErrorDialogState state = GlobalErrorDialogState.initial;

    AppLogger.log.info("Opening global error dialog...");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: scheme.surface,

              title: Row(
                children: [
                  Icon(LucideIcons.bug, size: 24, color: scheme.onSurface),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    local.translate("unexpected_error.title"),
                    style: AppText.h2(scheme),
                  ),
                ],
              ),

              content: switch (state) {
                GlobalErrorDialogState.initial => Text(
                  local.translate("unexpected_error.description"),
                  style: AppText.body(scheme),
                ),

                GlobalErrorDialogState.saving => SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.tertiary),
                  ),
                ),

                GlobalErrorDialogState.saved => Row(
                  children: [
                    Expanded(
                      child: Text(
                        local.translate("unexpected_error.saved"),
                        style: AppText.body(scheme),
                      ),
                    ),
                    Pressable(
                      onTap: () => launchUrl(
                        Uri.parse(
                          "https://github.com/RafaelGouveia-1017/still_alive/issues",
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          LucideIcons.externalLink,
                          size: 24,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              },
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppRadius.lg,
              ),

              actions: switch (state) {
                GlobalErrorDialogState.initial => [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: () => SystemNavigator.pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: scheme.surfaceContainer,
                        ),
                        child: Text(
                          local.translate("unexpected_error.exit"),
                          style: AppText.bodySm(scheme),
                        ),
                      ),
                      FilledButton(
                        onPressed: () async {
                          setState(() {
                            state = GlobalErrorDialogState.saving;
                          });

                          final destination = await AppLogger.saveLogFile();

                          if (destination == null) {
                            setState(() {
                              state = GlobalErrorDialogState.initial;
                            });
                          } else {
                            setState(() {
                              state = GlobalErrorDialogState.saved;
                            });
                          }
                        },
                        child: Text(local.translate("unexpected_error.save")),
                      ),
                      TextButton(
                        onPressed: () =>
                            Restart.restartApp(mode: RestartMode.process),
                        style: TextButton.styleFrom(
                          backgroundColor: scheme.surfaceContainer,
                        ),
                        child: Text(
                          local.translate("unexpected_error.restart"),
                          style: AppText.bodySm(scheme),
                        ),
                      ),
                    ],
                  ),
                ],

                GlobalErrorDialogState.saving => const [],

                GlobalErrorDialogState.saved => [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: () => SystemNavigator.pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: scheme.surfaceContainer,
                        ),
                        child: Text(
                          local.translate("unexpected_error.exit"),
                          style: AppText.bodySm(scheme),
                        ),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Restart.restartApp(mode: RestartMode.process),
                        child: Text(
                          local.translate("unexpected_error.restart"),
                          style: AppText.bodySm(scheme),
                        ),
                      ),
                    ],
                  ),
                ],
              },
            );
          },
        );
      },
    );
  }
}
