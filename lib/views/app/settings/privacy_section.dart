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
            Permission.locationWhenInUse => AppToggle(
              on: widget.locationFeature,
            ),
            Permission.locationAlways => AppToggle(on: widget.routeFeature),
            _ => AppToggle(on: widget.microphoneFeature),
          }
        : Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: widget.scheme.primary,
              borderRadius: AppRadius.chip,
            ),
            child: Text(
              switch (status) {
                PermissionStatus.denied => widget.local.translate(
                  "permissions.allow",
                ),
                _ => widget.local.translate("settings.title"),
              },
              style: AppText.caption(
                widget.scheme,
              ).copyWith(color: widget.scheme.onPrimary),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionTitle(widget.local.translate("settings.sections.privacy.title")),
        AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxs,
          ),
          margin: EdgeInsets.only(bottom: AppRadius.xl),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (!widget.locationWhenInUsePermissionStatus.isGranted) {
                    widget.onRequestPermission(Permission.locationWhenInUse);
                  } else {
                    await executeSql(
                      sql:
                          "UPDATE settings SET value = '${!widget.locationFeature}' WHERE key = 'location'",
                    );
                    widget.onLocationUpdate(!widget.locationFeature);
                  }
                },
                child: AppRow(
                  icon:
                      (widget.locationWhenInUsePermissionStatus.isGranted &&
                          widget.locationFeature)
                      ? LucideIcons.mapPin
                      : LucideIcons.mapPinOff,
                  title: widget.local.translate(
                    "settings.sections.privacy.labels.0",
                  ),
                  subtitle: widget.local.translate(
                    "settings.sections.privacy.labels.1",
                  ),
                  trailing: permissionState(
                    Permission.locationWhenInUse,
                    widget.locationWhenInUsePermissionStatus,
                  ),
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              Stack(
                children: [
                  AbsorbPointer(
                    absorbing:
                        !widget.locationWhenInUsePermissionStatus.isGranted,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (!widget.locationAlwaysPermissionStatus.isGranted) {
                          widget.onRequestPermission(Permission.locationAlways);
                        } else {
                          await executeSql(
                            sql:
                                "UPDATE settings SET value = '${!widget.routeFeature}' WHERE key = 'route'",
                          );
                          widget.onRouteUpdate(!widget.routeFeature);
                        }
                      },
                      child: AppRow(
                        icon:
                            (widget.locationAlwaysPermissionStatus.isGranted &&
                                widget.routeFeature)
                            ? LucideIcons.route
                            : LucideIcons.routeOff,
                        title: widget.local.translate(
                          "settings.sections.privacy.labels.2",
                        ),
                        subtitle: widget.local.translate(
                          "settings.sections.privacy.labels.3",
                        ),
                        trailing: permissionState(
                          Permission.locationAlways,
                          widget.locationAlwaysPermissionStatus,
                        ),
                      ),
                    ),
                  ),
                  if (widget.locationWhenInUsePermissionStatus.isGranted ==
                      false)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.scheme.surfaceBright.withAlpha(155),
                        ),
                      ),
                    ),
                ],
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (!widget.microphonePermissionStatus.isGranted) {
                    widget.onRequestPermission(Permission.microphone);
                  } else {
                    await executeSql(
                      sql:
                          "UPDATE settings SET value = '${!widget.microphoneFeature}' WHERE key = 'microphone'",
                    );
                    widget.onMicrophoneUpdate(!widget.microphoneFeature);
                  }
                },
                child: AppRow(
                  icon:
                      (widget.microphonePermissionStatus.isGranted &&
                          widget.microphoneFeature)
                      ? LucideIcons.mic
                      : LucideIcons.micOff,
                  title: widget.local.translate(
                    "settings.sections.privacy.labels.4",
                  ),
                  subtitle: widget.local.translate(
                    "settings.sections.privacy.labels.5",
                  ),
                  trailing: permissionState(
                    Permission.microphone,
                    widget.microphonePermissionStatus,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
