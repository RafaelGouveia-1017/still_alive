import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/views/app/home/timer/config/grace_input.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A widget that configures location and route tracking for a timer.
///
/// [LocationInputs] allows the user to:
///
/// - Enable or disable location access while the app is in use.
/// - Enable or disable continuous route/location access.
/// - Configure the interval at which location data is collected.
///
/// The widget also reflects the current location permissions and prevents
/// location-related options from being changed when the required permissions
/// have not been granted.
///
/// The collection interval is constrained by [timerDuration], with a maximum
/// interval equal to one quarter of the configured timer duration, subject to
/// a minimum of three seconds.
class LocationInputs extends StatefulWidget {
  const LocationInputs({
    super.key,
    required this.locationEnabled,
    required this.routeEnabled,
    required this.collectionInterval,
    required this.timerDuration,
    required this.onLocationChanged,
    required this.onRouteChanged,
    required this.onCollectionIntervalChanged,
  });

  final bool? locationEnabled;
  final bool? routeEnabled;
  final int? collectionInterval;
  final ValueListenable<Duration> timerDuration;
  final ValueChanged<bool> onLocationChanged;
  final ValueChanged<bool> onRouteChanged;
  final ValueChanged<int?> onCollectionIntervalChanged;

  @override
  State<LocationInputs> createState() => _LocationInputsState();
}

/// State implementation for [LocationInputs].
///
/// This class manages the local state of the location configuration UI,
/// including permission status, enabled states, and the collection interval.
///
/// The state listens to changes in [LocationInputs.timerDuration] so that the
/// collection interval can be automatically reduced when the timer duration
/// changes and the current interval exceeds the newly calculated maximum.
class _LocationInputsState extends State<LocationInputs> {
  bool _isLoading = true;

  late bool _locationEnabled;
  late bool _routeEnabled;
  late bool _locationGranted;
  late bool _routeGranted;

  late Duration _collectionInterval;
  int get _maxCollectionIntervalSeconds => (widget.timerDuration.value.inSeconds ~/ 4).clamp(3, 0x7fffffff);
  int get _recommendedCollectionIntervalSeconds => (_maxCollectionIntervalSeconds ~/ 3).clamp(3, 0x7fffffff);

  bool _intervalDrawerOpen = false;

  @override
  void initState() {
    super.initState();

    widget.timerDuration.addListener(_onTimerDurationChanged);

    loadStatus();
  }

  void loadStatus() async {
    bool whenInUseGranted = await Permission.locationWhenInUse.isGranted;
    bool alwaysGranted = await Permission.locationAlways.isGranted;

    bool locationEnabled;
    if (widget.locationEnabled == null) {
      String value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'location'");
      locationEnabled = (value == "true") && whenInUseGranted;
      widget.onLocationChanged(locationEnabled);
    } else {
      locationEnabled = widget.locationEnabled!;
    }

    bool routeEnabled;
    if (widget.routeEnabled == null) {
      String value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'route'");
      routeEnabled = (value == "true") && alwaysGranted;
      widget.onRouteChanged(routeEnabled);
    } else {
      routeEnabled = widget.routeEnabled!;
    }

    Duration collectionInterval;
    if (widget.collectionInterval == null) {
      collectionInterval = Duration(seconds: _recommendedCollectionIntervalSeconds);
    } else {
      collectionInterval = Duration(seconds: widget.collectionInterval!);
    }

    setState(() {
      _locationEnabled = locationEnabled;
      _routeEnabled = routeEnabled;
      _locationGranted = whenInUseGranted;
      _routeGranted = (whenInUseGranted && alwaysGranted);
      _intervalDrawerOpen = ((whenInUseGranted && alwaysGranted) && routeEnabled);
      _collectionInterval = collectionInterval;
      _isLoading = false;
    });
  }

  void _setLocationEnabled(bool value) {
    if (_locationEnabled == value) return;
    setState(() {
      _locationEnabled = value;
      if (!value) {
        _routeEnabled = value;
        _intervalDrawerOpen = value;
        _collectionInterval = Duration(seconds: _maxCollectionIntervalSeconds);
      }
    });
    widget.onLocationChanged(value);
    if (!value) {
      widget.onRouteChanged(value);
      widget.onCollectionIntervalChanged(null);
    }
  }

  void _setRouteEnabled(bool value) {
    if (_routeEnabled == value) return;
    setState(() {
      _routeEnabled = value;
      _intervalDrawerOpen = value;
      if (!value) {
        _collectionInterval = Duration(seconds: _recommendedCollectionIntervalSeconds);
      }
    });
    widget.onRouteChanged(value);
    if (!value) {
      widget.onCollectionIntervalChanged(null);
    } else {
      widget.onCollectionIntervalChanged(_recommendedCollectionIntervalSeconds);
    }
  }

  void _setCollectionInterval(Duration value) {
    if (_collectionInterval == value) return;
    setState(() {
      _collectionInterval = value;
    });
    widget.onCollectionIntervalChanged(value.inSeconds);
  }

  void _onTimerDurationChanged() {
    if (_isLoading) return;

    if (_collectionInterval.inSeconds <= _recommendedCollectionIntervalSeconds) {
      setState(() {});
      return;
    }

    final Duration value = Duration(seconds: _recommendedCollectionIntervalSeconds);

    setState(() {
      _collectionInterval = value;
    });

    widget.onCollectionIntervalChanged(value.inSeconds);
  }

  @override
  void didUpdateWidget(covariant LocationInputs oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.timerDuration != widget.timerDuration) {
      oldWidget.timerDuration.removeListener(_onTimerDurationChanged);
      widget.timerDuration.addListener(_onTimerDurationChanged);

      _onTimerDurationChanged();
    }
  }

  @override
  void dispose() {
    widget.timerDuration.removeListener(_onTimerDurationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final int maxSeconds = _maxCollectionIntervalSeconds;

    return AppCard(
      padding: EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, (_intervalDrawerOpen) ? 0 : AppSpacing.sm),
      child: (_isLoading)
          ? SizedBox(
              width: 40,
              height: 40,
              child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
            )
          : Column(
              children: [
                Stack(
                  children: [
                    IgnorePointer(
                      ignoring: !_locationGranted,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _setLocationEnabled(!_locationEnabled);
                        },
                        child: AppRow(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs, horizontal: AppSpacing.sm),
                          title: local.translate("timer_configuration.security.location.when_in_use.title"),
                          subtitle: _locationEnabled
                              ? local.translate("timer_configuration.security.location.when_in_use.enabled.on")
                              : local.translate("timer_configuration.security.location.when_in_use.enabled.off"),
                          icon: (_locationGranted && _locationEnabled) ? LucideIcons.mapPin : LucideIcons.mapPinOff,
                          iconColor: scheme.secondary,
                          trailing: AppToggle(on: _locationEnabled),
                        ),
                      ),
                    ),
                    if (!_locationGranted) ...[
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
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.ms),
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                Stack(
                  children: [
                    IgnorePointer(
                      ignoring: !_routeGranted,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _setRouteEnabled(!_routeEnabled);
                        },
                        child: AppRow(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs, horizontal: AppSpacing.sm),
                          title: local.translate("timer_configuration.security.location.always.title"),
                          subtitle: _routeEnabled
                              ? local.translate("timer_configuration.security.location.always.enabled.on")
                              : local.translate("timer_configuration.security.location.always.enabled.off"),
                          icon: (_routeGranted && _routeEnabled) ? LucideIcons.route : LucideIcons.routeOff,
                          iconColor: scheme.secondary,
                          trailing: AppToggle(on: _routeEnabled),
                        ),
                      ),
                    ),
                    if (!_routeGranted || !_locationEnabled) ...[
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
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                ClipRect(
                  child: AnimatedSize(
                    duration: AppMotion.fasterer,
                    curve: AppMotion.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _intervalDrawerOpen
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs, bottom: AppSpacing.xxs),
                            child: AppCard(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.ms, AppSpacing.lg, 0),
                              borderColor: scheme.surfaceContainer,
                              child: Column(
                                children: [
                                  AppRow(
                                    padding: EdgeInsets.zero,
                                    title: local.translate("timer_configuration.security.location.collection_interval.title"),
                                    subtitle: local.translate("timer_configuration.security.location.collection_interval.description"),
                                    trailing: Pill(label: _formatDuration(_collectionInterval), backColor: scheme.secondary),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (maxSeconds > 3)
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,

                                        trackShape: MajorTickSliderTrackShape(),

                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppRadius.sm),
                                        tickMarkShape: SliderTickMarkShape.noTickMark,
                                      ),
                                      child: Slider(
                                        // ignore: deprecated_member_use
                                        year2023: true,
                                        activeColor: scheme.primary,
                                        inactiveColor: scheme.surfaceContainerLow,
                                        secondaryActiveColor: scheme.primary.withAlpha(155),
                                        thumbColor: scheme.onSurface,
                                        value: _collectionInterval.inSeconds.clamp(1, maxSeconds).toDouble(),
                                        min: 3,
                                        max: maxSeconds.toDouble(),
                                        divisions: maxSeconds - 1,
                                        onChanged: (value) {
                                          _setCollectionInterval(Duration(seconds: value.round()));
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDuration(Duration duration) {
    final parts = <String>[];

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      parts.add('${hours.toString()}h');
    }

    if (minutes > 0) {
      parts.add('${minutes.toString()}m');
    }

    if (seconds > 0) {
      parts.add('${seconds.toString()}s');
    }

    if (parts.isEmpty) {
      return '0s';
    }

    return parts.join(' ');
  }
}
