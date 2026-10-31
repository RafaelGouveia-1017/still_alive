import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:still_alive/data/all.dart';
import 'package:still_alive/views/widgets/primitives.dart';

/// Callback invoked when the user requests a permission.
typedef DisclosurePermissionCallback = Future<void> Function(Permission permission);

/// Callback invoked when the user changes a feature's enabled state.
typedef DisclosureToggleCallback = Future<void> Function(bool enabled);

/// Displays a prominent disclosure dialog about how StillAlive utilizes a
/// permission's accessed or collected data.
///
/// Prompted by Google Play so the app can be published to production.
class ProminentDisclosure {
  ProminentDisclosure({required this.mode, this.enabled = false, this.status = PermissionStatus.denied, this.onGrantPermission, this.onToggle});

  /// Determines the actions and behavior of the disclosure dialog.
  final DisclosureDialogActions mode;

  /// Current state of the associated feature.
  ///
  /// Used by the feature toggle to display whether the feature is enabled.
  final bool enabled;

  /// Current status of the associated permission.
  ///
  /// Used by the grant permission mode to display whether the status is
  /// app-requestable.
  final PermissionStatus status;

  /// Callback invoked when the user requests the associated permission.
  final DisclosurePermissionCallback? onGrantPermission;

  /// Callback invoked when the user changes the feature's enabled state.
  final DisclosureToggleCallback? onToggle;

  /// Whether the dialog can be dismissed by tapping outside.
  ///
  /// Acknowledgement dialogs can be dismissed this way, while permission
  /// and feature management dialogs require explicit interaction.
  bool get barrierDismissible => mode == DisclosureDialogActions.acknowledge;

  /// Displays the disclosure dialog for the requested permission.
  ///
  /// The permission determines the title, description and icon.
  Future<void> show(BuildContext context, Permission permission) async {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final int index = switch (permission) {
      Permission.locationWhenInUse => 0,
      Permission.locationAlways => 1,
      _ => 2,
    };

    final IconData icon = switch (permission) {
      Permission.locationWhenInUse => LucideIcons.mapPin,
      Permission.locationAlways => LucideIcons.route,
      _ => LucideIcons.mic,
    };

    /// Builds the back button used by permission and feature management modes.
    ///
    /// Closes the dialog without changing the current feature configuration.
    Widget backButton(BuildContext context, ColorScheme scheme) {
      return TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(backgroundColor: scheme.surfaceContainer),
        child: Icon(LucideIcons.arrowLeft, size: 18, color: scheme.onSurface),
      );
    }

    /// Builds the permission request button.
    ///
    /// Invokes [onGrantPermission] with the new permission's status and
    /// closes the dialog afterwards.
    Widget grantPermissionButton(BuildContext context, Permission permission, ColorScheme scheme, AppLocalizations local) {
      return FilledButton(
        onPressed: onGrantPermission == null
            ? null
            : () async {
                await onGrantPermission!(permission);

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
        child: Text(switch (status) {
          PermissionStatus.denied => local.translate("permissions.allow"),
          _ => local.translate("settings.title"),
        }, style: AppText.bodySm(scheme)),
      );
    }

    /// Builds the feature toggle associated with the selected permission.
    ///
    /// Invokes [onToggle] with the new enabled state when the user interacts
    /// with the toggle.
    Widget featureToggle(BuildContext context, ColorScheme scheme) {
      return SizedBox(
        width: 64,
        height: 38,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle == null
              ? null
              : () async {
                  await onToggle!(!enabled);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: AppToggle(on: enabled),
        ),
      );
    }

    final List<Widget> children = switch (mode) {
      DisclosureDialogActions.grantPermission => [
        backButton(context, scheme),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: grantPermissionButton(context, permission, scheme, local)),
      ],

      DisclosureDialogActions.enable => [backButton(context, scheme), featureToggle(context, scheme)],

      _ => [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(LucideIcons.thumbsUp, size: 18, color: scheme.onSurface),
          label: Text(local.translate("permissions.got_it"), style: AppText.bodySm(scheme)),
        ),
      ],
    };

    await showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: scheme.surface,

          title: Row(
            children: [
              Icon(icon, size: 24, color: scheme.onSurface),
              SizedBox(width: AppSpacing.md),
              Text(local.translate("permissions.optional.items.$index.name"), style: AppText.h2(scheme)),
            ],
          ),

          content: Text(local.translate("permissions.optional.items.$index.description"), style: AppText.body(scheme)),

          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),

          actions: [Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children)],
        );
      },
    );
  }
}

/// Defines the available disclosure dialog interaction modes.
enum DisclosureDialogActions {
  /// Requests permission from the user.
  ///
  /// Displays a back button and an action to grant the permission.
  grantPermission,

  /// Allows the user to enable or disable the associated feature.
  ///
  /// Displays a back button and a feature toggle.
  enable,

  /// Informs the user about data access and requests acknowledgement.
  ///
  /// Displays a single acknowledgement button.
  acknowledge,
}
