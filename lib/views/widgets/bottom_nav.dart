import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A single bottom navigation destination.
///
/// Represents one tab in the bottom navigation bar, including its
/// unique identifier, display label, icon and the route it navigates to.
class NavDestination {
  const NavDestination(this.id, this.label, this.icon, this.route);

  /// Unique identifier for the destination (used for active state matching).
  final String id;

  /// Human-readable label shown under the icon.
  final String label;

  /// Icon displayed in the navigation bar.
  final IconData icon;

  /// Application route associated with this destination.
  final String route;
}

/// The fixed list of bottom navigation destinations used by [BottomNav].
///
/// This defines the 5-tab structure of the app's primary navigation.
const List<NavDestination> kNavDestinations = [
  NavDestination('home', 'Home', LucideIcons.timer, '/screen/home'),
  NavDestination('history', 'History', LucideIcons.history, '/screen/history'),
  NavDestination('contacts', 'Contacts', LucideIcons.users, '/screen/contacts'),
  NavDestination(
    'integrations',
    'Plug-ins',
    LucideIcons.blocks,
    '/screen/integrations',
  ),
  NavDestination(
    'settings',
    'Settings',
    LucideIcons.slidersHorizontal,
    '/screen/settings',
  ),
];

/// A bottom navigation bar widget with 5 fixed destinations.
///
/// Displays icons, labels, and an active indicator dot for the currently
/// selected destination. The widget is stateless; selection is controlled
/// externally via [active] and [onSelect].
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.active,
    this.onSelect,
    this.colorScheme,
  });

  /// The currently active destination ID.
  final String active;

  /// Callback triggered when a destination is tapped.
  ///
  /// If null, navigation interaction is disabled.
  final ValueChanged<NavDestination>? onSelect;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: kNavDestinations.map((d) {
          final isActive = d.id == active;
          final color = isActive ? scheme.primary : scheme.onSurfaceVariant;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelect == null ? null : () => onSelect!(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d.icon, size: 20, color: color),
                    const SizedBox(height: 4),
                    Text(
                      d.label,
                      style: const TextStyle(
                        fontSize: 10,
                      ).copyWith(color: color),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive ? scheme.primary : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
