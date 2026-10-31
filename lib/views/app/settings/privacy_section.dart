import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:still_alive/views/app/prominent_disclosure.dart';
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
  Future<void> showDisclosure(BuildContext context, Permission permission, PermissionStatus status) async {
    if (status.isGranted) {
      await ProminentDisclosure(
        mode: DisclosureDialogActions.enable,
        enabled: switch (permission) {
          Permission.locationWhenInUse => widget.locationFeature,
          Permission.locationAlways => widget.routeFeature,
          _ => widget.microphoneFeature,
        },
        onToggle: (_) async {
          switch (permission) {
            case Permission.locationWhenInUse:
              await executeSql(sql: "UPDATE settings SET value = '${!widget.locationFeature}' WHERE key = 'location'");
              if (!widget.locationFeature == false) {
                await executeSql(sql: "UPDATE settings SET value = 'false' WHERE key = 'route'");
                widget.onRouteUpdate(false);
              }
              widget.onLocationUpdate(!widget.locationFeature);
              break;
            case Permission.locationAlways:
              await executeSql(sql: "UPDATE settings SET value = '${!widget.routeFeature}' WHERE key = 'route'");
              if (widget.locationFeature == false && !widget.routeFeature == true) {
                await executeSql(sql: "UPDATE settings SET value = 'true' WHERE key = 'location'");
                widget.onLocationUpdate(true);
              }
              widget.onRouteUpdate(!widget.routeFeature);
              break;
            default:
              await executeSql(sql: "UPDATE settings SET value = '${!widget.microphoneFeature}' WHERE key = 'microphone'");
              widget.onMicrophoneUpdate(!widget.microphoneFeature);
              break;
          }
        },
      ).show(context, permission);
    } else {
      await ProminentDisclosure(
        mode: DisclosureDialogActions.grantPermission,
        status: switch (permission) {
          Permission.locationWhenInUse => widget.locationWhenInUsePermissionStatus,
          Permission.locationAlways => widget.locationAlwaysPermissionStatus,
          _ => widget.microphonePermissionStatus,
        },
        onGrantPermission: (permission) async {
          await widget.onRequestPermission(permission);
        },
      ).show(context, permission);
    }
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
                onTap: () => showDisclosure(context, Permission.locationWhenInUse, widget.locationWhenInUsePermissionStatus),
                child: AppRow(
                  icon: (widget.locationWhenInUsePermissionStatus.isGranted && widget.locationFeature) ? LucideIcons.mapPin : LucideIcons.mapPinOff,
                  title: widget.local.translate("settings.sections.privacy.labels.0"),
                  subtitle: widget.local.translate("settings.sections.privacy.labels.1"),
                  trailing: Icon(LucideIcons.chevronRight, size: 18, color: widget.scheme.onSurfaceVariant),
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              Stack(
                children: [
                  AbsorbPointer(
                    absorbing: !widget.locationWhenInUsePermissionStatus.isGranted,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showDisclosure(context, Permission.locationAlways, widget.locationAlwaysPermissionStatus),
                      child: AppRow(
                        icon: (widget.locationAlwaysPermissionStatus.isGranted && widget.routeFeature) ? LucideIcons.route : LucideIcons.routeOff,
                        title: widget.local.translate("settings.sections.privacy.labels.2"),
                        subtitle: widget.local.translate("settings.sections.privacy.labels.3"),
                        trailing: Icon(LucideIcons.chevronRight, size: 18, color: widget.scheme.onSurfaceVariant),
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
                onTap: () => showDisclosure(context, Permission.microphone, widget.microphonePermissionStatus),
                child: AppRow(
                  icon: (widget.microphonePermissionStatus.isGranted && widget.microphoneFeature) ? LucideIcons.mic : LucideIcons.micOff,
                  title: widget.local.translate("settings.sections.privacy.labels.4"),
                  subtitle: widget.local.translate("settings.sections.privacy.labels.5"),
                  trailing: Icon(LucideIcons.chevronRight, size: 18, color: widget.scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
