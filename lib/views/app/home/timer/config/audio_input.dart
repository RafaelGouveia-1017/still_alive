import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A configuration row for enabling or disabling microphone audio input.
///
/// The audio input can only be enabled when microphone permission has been
/// granted. When permission is unavailable, the row is displayed with a
/// disabled overlay indicating that permission has not been granted.
class AudioInput extends StatefulWidget {
  const AudioInput({super.key, required this.enabled, required this.onChanged});

  final bool? enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<AudioInput> createState() => _AudioInputState();
}

/// State implementation for [AudioInput].
class _AudioInputState extends State<AudioInput> {
  bool _isLoading = true;
  late bool _enabled;
  late bool _permissionGranted;

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  void loadStatus() async {
    bool granted = await Permission.microphone.isGranted;

    bool enabled;
    if (widget.enabled == null) {
      String value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'microphone'");

      enabled = (value == "true");

      widget.onChanged(enabled);
    } else {
      enabled = widget.enabled!;
    }

    setState(() {
      _enabled = enabled;
      _permissionGranted = granted;
      _isLoading = false;
    });
  }

  void _setEnabled(bool value) {
    if (_enabled == value) return;

    setState(() {
      _enabled = value;
    });

    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: (_isLoading)
          ? SizedBox(
              width: 40,
              height: 40,
              child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
            )
          : Stack(
              children: [
                IgnorePointer(
                  ignoring: !_permissionGranted,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _setEnabled(!_enabled);
                    },
                    child: AppRow(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs, horizontal: AppSpacing.sm),
                      title: local.translate("timer_configuration.security.audio.title"),
                      subtitle: _enabled
                          ? local.translate("timer_configuration.security.audio.enabled.on")
                          : local.translate("timer_configuration.security.audio.enabled.off"),
                      icon: (_permissionGranted && _enabled) ? LucideIcons.mic : LucideIcons.micOff,
                      iconColor: scheme.secondary,
                      trailing: AppToggle(on: _enabled),
                    ),
                  ),
                ),

                if (!_permissionGranted)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Center(
                        child: Text(
                          local.translate("timer_configuration.security.permission"),
                          style: AppText.body(scheme).copyWith(color: scheme.onSurface, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
