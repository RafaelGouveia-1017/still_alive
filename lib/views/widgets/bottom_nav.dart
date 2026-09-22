import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/app_localization.dart';
import '../../data/app_design.dart';
import '../app/screens.dart';

/// A single bottom navigation destination.
///
/// Represents one tab in the bottom navigation bar, including its
/// unique identifier, display label, icon and the route it navigates to.
class NavDestination {
  const NavDestination(this.id, this.label, this.icon, this.screen);

  /// Unique identifier for the destination (used for active state matching).
  final String id;

  /// Human-readable label shown under the icon.
  final String label;

  /// Icon displayed in the navigation bar.
  final IconData icon;

  /// Application screen widget associated with this destination.
  final Widget screen;
}

/// A bottom navigation bar widget with 5 fixed destinations.
///
/// Displays icons, labels, and an active indicator dot for the currently
/// selected destination.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.active, this.colorScheme});

  /// The currently active destination ID.
  ///
  /// Must follow [NavDestination.id].
  final String active;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<NavDestination> navDestinations = [
      NavDestination('home', local.translate("navigation.0"), LucideIcons.timer, HomeScreen()),
      NavDestination('history', local.translate("navigation.1"), LucideIcons.history, HistoryScreen()),
      NavDestination('contacts', local.translate("navigation.2"), LucideIcons.users, ContactsScreen.showAllContacts()),
      NavDestination('integrations', local.translate("navigation.3"), LucideIcons.blocks, IntegrationsScreen()),
      NavDestination('settings', local.translate("navigation.4"), LucideIcons.slidersHorizontal, SettingsScreen()),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, 0),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: navDestinations.map((d) {
          final isActive = d.id == active;
          final color = isActive ? scheme.primary : scheme.onSurfaceVariant;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => isActive
                  ? null
                  : Navigator.of(context).pushAndRemoveUntil(
                      AppRoute(page: d.screen, transition: AppRouteTransitionType.slideRight),
                      (route) => (d.screen is HomeScreen) ? false : route.isFirst,
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d.icon, size: 20, color: color),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(d.label, style: const TextStyle(fontSize: 10).copyWith(color: color)),
                    const SizedBox(height: AppSpacing.xxs),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: isActive ? scheme.primary : Colors.transparent, shape: BoxShape.circle),
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
