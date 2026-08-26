import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:still_alive/views/app/contacts/emergency_contacts.dart';

import '../integrations/integrations.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays a summary of the device's current status.
///
/// The widget monitors battery level, charging state, network connectivity,
/// and internet availability in real time. It also displays the number of
/// configured emergency contacts and integrations.
class PhoneStatus extends StatefulWidget {
  const PhoneStatus({super.key, this.contacts = 0, this.integrations = 0});

  final int contacts;
  final int integrations;

  @override
  State<PhoneStatus> createState() => _PhoneStatusState();
}

/// State implementation for [PhoneStatus].
class _PhoneStatusState extends State<PhoneStatus> {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  int _batteryLevel = 0;
  BatteryState? _batteryState;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  ConnectivityResult _connectionType = ConnectivityResult.none;
  bool _hasInternet = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;

  @override
  void initState() {
    super.initState();

    _battery.batteryLevel.then(_updateBatteryLevel);
    _battery.batteryState.then(_updateBatteryState);
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
      _updateBatteryState,
    );

    _initializeConnectivity();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectivity,
    );

    _internetSubscription = InternetConnection().onStatusChange.listen((
      status,
    ) {
      final connected = status == InternetStatus.connected;

      if (_hasInternet != connected) {
        setState(() {
          _hasInternet = connected;
        });
      }
    });
  }

  void _updateBatteryState(BatteryState state) {
    _battery.batteryLevel.then(_updateBatteryLevel);
    if (_batteryState == state) return;
    setState(() {
      _batteryState = state;
    });
  }

  void _updateBatteryLevel(int level) {
    if (_batteryLevel == level) return;
    setState(() {
      _batteryLevel = level;
    });
  }

  void _initializeConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectivity(result);

    final internet = await InternetConnection().hasInternetAccess;

    if (mounted) {
      setState(() {
        _hasInternet = internet;
      });
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final type = results.isEmpty ? ConnectivityResult.none : results.first;

    if (_connectionType == type) return;

    setState(() {
      _connectionType = type;
    });
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _internetSubscription?.cancel();
    super.dispose();
  }

  IconData get _batteryIcon {
    if (_batteryState == BatteryState.charging) {
      return LucideIcons.batteryCharging;
    } else {
      if (_batteryLevel <= 10) {
        return LucideIcons.batteryWarning;
      } else if (_batteryLevel <= 35) {
        return LucideIcons.batteryLow;
      } else if (_batteryLevel <= 75) {
        return LucideIcons.batteryMedium;
      } else {
        return LucideIcons.batteryFull;
      }
    }
  }

  IconData get _connectionIcon {
    if (!_hasInternet) {
      return LucideIcons.globeOff;
    }

    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return LucideIcons.wifi;

      case ConnectivityResult.mobile:
        return LucideIcons.cardSim;

      case ConnectivityResult.ethernet:
        return LucideIcons.ethernetPort;

      case ConnectivityResult.bluetooth:
        return LucideIcons.bluetooth;

      case ConnectivityResult.vpn:
        return LucideIcons.keyRound;

      case ConnectivityResult.none:
        return LucideIcons.globeOff;

      default:
        return LucideIcons.globe;
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: _connectionIcon,
            label: (!_hasInternet)
                ? local.translate('home.offline')
                : local.translate('home.online'),
            color: scheme.tertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: _batteryIcon,
            label: '$_batteryLevel%',
            color: scheme.tertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).push(
              AppRoute(
                page: EmergencyContactsScreen(),
                transition: AppRouteTransitionType.slideLeft,
              ),
            ),
            child: _StatCard(
              icon: LucideIcons.userStar,
              label: '${widget.contacts} ${local.translate('home.contacts')}',
              color: scheme.secondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).push(
              AppRoute(
                page: IntegrationsScreen(),
                transition: AppRouteTransitionType.slideRight,
              ),
            ),
            child: _StatCard(
              icon: LucideIcons.plug,
              rotateAngle: math.pi / 4,
              label:
                  '${widget.integrations} ${local.translate('home.plugins')}',
              color: scheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact card displaying a single device status.
///
/// Consists of an icon and label, with an optional icon rotation, and is
/// used by [PhoneStatus] to present battery, connectivity, contacts,
/// and integrations information.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    this.rotateAngle = 0,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final double rotateAngle;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
      child: Column(
        children: [
          Transform.rotate(
            angle: rotateAngle,
            child: Icon(icon, size: AppSpacing.lg, color: color),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: AppText.micro(scheme)),
        ],
      ),
    );
  }
}
