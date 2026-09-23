import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../src/rust/api/data/db.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays the alerts section of the settings screen.
///
/// Allows users to configure the emergency alert message, notification volume,
/// and device lock behavior.
class AlertsSection extends StatefulWidget {
  final ColorScheme scheme;
  final AppLocalizations local;
  final String messageFeature;
  final int volumeFeature;
  final bool lockFeature;
  final Function(String) onMessageUpdate;
  final Function(int) onVolumeUpdate;
  final Function(bool) onLockUpdate;

  const AlertsSection({
    super.key,
    required this.scheme,
    required this.local,
    required this.messageFeature,
    required this.volumeFeature,
    required this.lockFeature,
    required this.onMessageUpdate,
    required this.onVolumeUpdate,
    required this.onLockUpdate,
  });

  @override
  State<AlertsSection> createState() => _AlertsSectionState();
}

/// State implementation for [AlertsSection].
class _AlertsSectionState extends State<AlertsSection> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chevron = Icon(LucideIcons.chevronRight, size: 18, color: widget.scheme.onSurfaceVariant);

    return Column(
      children: [
        SectionTitle(widget.local.translate("settings.sections.alerts.title")),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxs),
          margin: EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            children: [
              Pressable(
                onTap: () {
                  _messageController.text = widget.messageFeature;
                  showBlurredBottomSheet(
                    scheme: widget.scheme,
                    context: context,
                    marginHorizontal: 15,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.local.translate("settings.sections.alerts.labels.2"),
                          style: AppText.micro(widget.scheme).copyWith(color: widget.scheme.onSurface),
                          textAlign: TextAlign.center,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: TextFormField(
                            controller: _messageController,
                            style: AppText.caption(widget.scheme).copyWith(color: widget.scheme.onSurface),
                            cursorColor: widget.scheme.primary,
                            scrollPadding: const EdgeInsets.all(0),
                            maxLines: 15,
                            maxLength: 800,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxs, vertical: AppSpacing.xxxs),
                              border: OutlineInputBorder(),
                              filled: false,
                              fillColor: Colors.transparent,
                              hintText: widget.local.translate("settings.sections.alerts.labels.3"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).then((res) async {
                    final tempMessage = _messageController.text;
                    if (tempMessage == widget.messageFeature) return;

                    await updateMessage(message: tempMessage);

                    widget.onMessageUpdate(tempMessage);

                    showToast(
                      scheme: widget.scheme,
                      toast: Text(
                        widget.local.translate("settings.sections.alerts.labels.4"),
                        style: AppText.bodySm(widget.scheme),
                        textAlign: TextAlign.center,
                      ),
                      gravity: ToastGravity.BOTTOM,
                      position: (context, child, gravity) {
                        return Positioned(bottom: 170, left: 60, right: 60, child: child);
                      },
                      secs: 5,
                    );
                  });
                },
                child: AppRow(
                  icon: LucideIcons.messageSquare,
                  title: widget.local.translate("settings.sections.alerts.labels.0"),
                  subtitle: widget.local.translate("settings.sections.alerts.labels.1"),
                  trailing: chevron,
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              Pressable(
                onTap: () {
                  int tempVolume = widget.volumeFeature;
                  showBlurredBottomSheet(
                    scheme: widget.scheme,
                    context: context,
                    marginHorizontal: 25,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: AppSpacing.xxl),
                            Slider(
                              // ignore: deprecated_member_use
                              year2023: true,
                              activeColor: widget.scheme.primary,
                              inactiveColor: widget.scheme.surfaceContainerLow,
                              secondaryActiveColor: widget.scheme.primary.withAlpha(155),
                              thumbColor: widget.scheme.onSurface,
                              value: tempVolume.toDouble(),
                              secondaryTrackValue: widget.volumeFeature.toDouble(),
                              max: 100,
                              divisions: 10,
                              label: switch (tempVolume) {
                                100 => widget.local.translate("settings.sections.alerts.labels.6"),
                                0 => widget.local.translate("settings.sections.alerts.labels.7"),
                                _ => "$tempVolume%",
                              },
                              onChanged: (double value) {
                                setState(() {
                                  tempVolume = value.round();
                                });
                              },
                              showValueIndicator: ShowValueIndicator.alwaysVisible,
                            ),
                            SizedBox(height: AppSpacing.xxl),
                          ],
                        );
                      },
                    ),
                  ).then((res) async {
                    await executeSql(sql: "UPDATE settings SET value = '$tempVolume' WHERE key = 'volume'");
                    widget.onVolumeUpdate(tempVolume);
                  });
                },
                child: AppRow(
                  icon: (widget.volumeFeature > 0)
                      ? (widget.volumeFeature > 50)
                            ? LucideIcons.volume2
                            : LucideIcons.volume1
                      : LucideIcons.volumeX,
                  title: widget.local.translate("settings.sections.alerts.labels.5"),
                  subtitle: switch (widget.volumeFeature) {
                    100 => widget.local.translate("settings.sections.alerts.labels.6"),
                    0 => widget.local.translate("settings.sections.alerts.labels.7"),
                    _ => "${widget.volumeFeature}%",
                  },
                  trailing: chevron,
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await executeSql(sql: "UPDATE settings SET value = '${!widget.lockFeature}' WHERE key = 'lock'");
                  widget.onLockUpdate(!widget.lockFeature);
                },
                child: AppRow(
                  icon: widget.lockFeature ? LucideIcons.lock : LucideIcons.lockOpen,
                  title: widget.local.translate("settings.sections.alerts.labels.8"),
                  subtitle: widget.local.translate("settings.sections.alerts.labels.9"),
                  trailing: AppToggle(on: widget.lockFeature),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
