import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../src/rust/api/data/db.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays the privacy section of the settings screen.
///
/// Allows users to manage privacy-related features, including location,
/// route tracking, and microphone access. The section also reflects the
/// current permission state and provides actions for requesting any
/// required permissions.
class PrivacySection extends StatefulWidget {
  final ColorScheme scheme;
  final AppLocalizations local;
  final bool locationFeature;
  final bool routeFeature;
  final bool microphoneFeature;
  final PermissionStatus locationWhenInUsePermissionStatus;
  final PermissionStatus locationAlwaysPermissionStatus;
  final PermissionStatus microphonePermissionStatus;
  final Function(Permission) onRequestPermission;
  final Function(bool) onLocationUpdate;
  final Function(bool) onRouteUpdate;
  final Function(bool) onMicrophoneUpdate;

  const PrivacySection({
    super.key,
    required this.scheme,
    required this.local,
    required this.locationFeature,
    required this.routeFeature,
    required this.microphoneFeature,
    required this.locationWhenInUsePermissionStatus,
    required this.locationAlwaysPermissionStatus,
    required this.microphonePermissionStatus,
    required this.onRequestPermission,
    required this.onLocationUpdate,
    required this.onRouteUpdate,
    required this.onMicrophoneUpdate,
  });

  @override
  State<PrivacySection> createState() => _PrivacySectionState();
}

/// State implementation for [PrivacySection].
class _PrivacySectionState extends State<PrivacySection> {
  Widget permissionState(Permission p, PermissionStatus status) {
    return status.isGranted
        ? switch (p) {
            Permission.locationWhenInUse => AppToggle(on: widget.locationFeature),
            Permission.locationAlways => AppToggle(on: widget.routeFeature),
            _ => AppToggle(on: widget.microphoneFeature),
          }
        : Icon(LucideIcons.chevronRight, size: 18, color: widget.scheme.onSurfaceVariant);
  }

  void showDisclosure(BuildContext context, Permission permission, PermissionStatus status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: widget.scheme.surface,

              title: switch (permission) {
                Permission.locationWhenInUse => Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 24, color: widget.scheme.onSurface),
                    SizedBox(width: AppSpacing.md),
                    Text(widget.local.translate("permissions.optional.items.0.name"), style: AppText.h2(widget.scheme)),
                  ],
                ),
                Permission.locationAlways => Row(
                  children: [
                    Icon(LucideIcons.route, size: 24, color: widget.scheme.onSurface),
                    SizedBox(width: AppSpacing.md),
                    Text(widget.local.translate("permissions.optional.items.1.name"), style: AppText.h2(widget.scheme)),
                  ],
                ),
                _ => Row(
                  children: [
                    Icon(LucideIcons.mic, size: 24, color: widget.scheme.onSurface),
                    SizedBox(width: AppSpacing.md),
                    Text(widget.local.translate("permissions.optional.items.2.name"), style: AppText.h2(widget.scheme)),
                  ],
                ),
              },

              content: switch (permission) {
                Permission.locationWhenInUse => Text(
                  widget.local.translate("permissions.optional.items.0.description"),
                  style: AppText.body(widget.scheme),
                ),
                Permission.locationAlways => Text(
                  widget.local.translate("permissions.optional.items.1.description"),
                  style: AppText.body(widget.scheme),
                ),
                _ => Text(widget.local.translate("permissions.optional.items.2.description"), style: AppText.body(widget.scheme)),
              },

              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),

              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(backgroundColor: widget.scheme.surfaceContainer),
                      child: Icon(LucideIcons.arrowLeft, size: 18, color: widget.scheme.onSurface),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.onRequestPermission(permission);
                          Navigator.pop(context);
                        },
                        child: Text(switch (status) {
                          PermissionStatus.denied => widget.local.translate("permissions.allow"),
                          _ => widget.local.translate("settings.title"),
                        }, style: AppText.bodySm(widget.scheme)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionTitle(widget.local.translate("settings.sections.privacy.title")),
        AppCard(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxs),
          margin: EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (!widget.locationWhenInUsePermissionStatus.isGranted) {
                    showDisclosure(context, Permission.locationWhenInUse, widget.locationWhenInUsePermissionStatus);
                  } else {
                    await executeSql(sql: "UPDATE settings SET value = '${!widget.locationFeature}' WHERE key = 'location'");
                    widget.onLocationUpdate(!widget.locationFeature);
                  }
                },
                child: AppRow(
                  icon: (widget.locationWhenInUsePermissionStatus.isGranted && widget.locationFeature) ? LucideIcons.mapPin : LucideIcons.mapPinOff,
                  title: widget.local.translate("settings.sections.privacy.labels.0"),
                  subtitle: widget.local.translate("settings.sections.privacy.labels.1"),
                  trailing: permissionState(Permission.locationWhenInUse, widget.locationWhenInUsePermissionStatus),
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              Stack(
                children: [
                  AbsorbPointer(
                    absorbing: !widget.locationWhenInUsePermissionStatus.isGranted,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (!widget.locationAlwaysPermissionStatus.isGranted) {
                          showDisclosure(context, Permission.locationAlways, widget.locationAlwaysPermissionStatus);
                        } else {
                          await executeSql(sql: "UPDATE settings SET value = '${!widget.routeFeature}' WHERE key = 'route'");
                          widget.onRouteUpdate(!widget.routeFeature);
                        }
                      },
                      child: AppRow(
                        icon: (widget.locationAlwaysPermissionStatus.isGranted && widget.routeFeature) ? LucideIcons.route : LucideIcons.routeOff,
                        title: widget.local.translate("settings.sections.privacy.labels.2"),
                        subtitle: widget.local.translate("settings.sections.privacy.labels.3"),
                        trailing: permissionState(Permission.locationAlways, widget.locationAlwaysPermissionStatus),
                      ),
                    ),
                  ),
                  if (widget.locationWhenInUsePermissionStatus.isGranted == false)
                    Positioned.fill(
                      child: DecoratedBox(decoration: BoxDecoration(color: widget.scheme.surfaceBright.withAlpha(155))),
                    ),
                ],
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (!widget.microphonePermissionStatus.isGranted) {
                    showDisclosure(context, Permission.microphone, widget.microphonePermissionStatus);
                  } else {
                    await executeSql(sql: "UPDATE settings SET value = '${!widget.microphoneFeature}' WHERE key = 'microphone'");
                    widget.onMicrophoneUpdate(!widget.microphoneFeature);
                  }
                },
                child: AppRow(
                  icon: (widget.microphonePermissionStatus.isGranted && widget.microphoneFeature) ? LucideIcons.mic : LucideIcons.micOff,
                  title: widget.local.translate("settings.sections.privacy.labels.4"),
                  subtitle: widget.local.translate("settings.sections.privacy.labels.5"),
                  trailing: permissionState(Permission.microphone, widget.microphonePermissionStatus),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
