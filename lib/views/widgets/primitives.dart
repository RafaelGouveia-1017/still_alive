import 'package:flutter/material.dart';
import '../../data/app_design.dart';

/// A reusable rounded container used as the base surface for grouped content.
///
/// This widget is intended for layouts such as lists, forms and
/// grouped UI sections.
///
/// It supports:
/// * Custom padding via spacing tokens
/// * Optional solid background color (defaults to theme surface)
/// * Optional gradient background (overrides solid color)
/// * Optional border override
///
/// All styling is derived from the active [Theme].
/// No raw color values should be used externally.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.color,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surfaceContainer) : null,
        gradient: gradient,
        borderRadius: AppRadius.card,
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Defines semantic color variants for [PrimaryButton].
///
/// Used to express intent rather than raw color values.
enum ButtonColor {
  /// Main CTA
  primary,

  /// Alternative action
  secondary,

  /// Supporting action
  tertiary,

  /// Destructive or risky action
  warning,

  /// Neutral / Low-emphasis action
  muted,
}

/// The primary action button used throughout the application.
///
/// This button is designed to represent the most important user actions
/// on a screen (e.g. submit, continue, confirm).
///
/// Features:
/// * Full-width tappable InkWell surface
/// * Multiple semantic color variants via [ButtonColor]
/// * Optional leading icon
/// * Design system-driven typography, spacing, shadows, and radius
///
/// Behavior:
/// * Uses Material ripple feedback
/// * Applies elevation via theme-aware shadows
/// * Supports disabled state when [onPressed] is null
///
/// Must be used instead of raw [ElevatedButton] for consistency.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.color = ButtonColor.primary,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final ButtonColor color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    List<BoxShadow> shadow = const [];
    Border? border;
    ColorScheme scheme = Theme.of(context).colorScheme;

    switch (color) {
      case ButtonColor.primary:
        bg = scheme.primary;
        fg = scheme.onPrimary;
        shadow = AppShadows.buttonShadow(scheme.primary);
        break;
      case ButtonColor.secondary:
        bg = scheme.secondary;
        fg = scheme.onSecondary;
        shadow = AppShadows.buttonShadow(scheme.secondary);
        break;
      case ButtonColor.tertiary:
        bg = scheme.tertiary;
        fg = scheme.onTertiary;
        shadow = AppShadows.buttonShadow(scheme.tertiary);
        break;
      case ButtonColor.warning:
        bg = scheme.error;
        fg = scheme.onError;
        shadow = AppShadows.buttonShadow(scheme.error);
        break;
      case ButtonColor.muted:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        border = Border.all(color: scheme.outline);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.button,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.button,
            boxShadow: shadow,
            border: border,
          ),
          child: Container(
            width: double.infinity,
            padding: AppSpacing.primaryButton,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(label, style: AppText.body(scheme).copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact uppercase label chip used for statuses, tags, or metadata.
///
/// The pill is intentionally minimal and is designed to:
/// * Emphasize short categorical labels
/// * Use semantic color tinting (not solid fills)
/// * Support an optional leading widget (e.g. icon or avatar)
///
/// All text is automatically transformed to uppercase for visual consistency.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.leading,
  });

  final String label;
  final Color color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label.toUpperCase(),
            style: AppText.pillLabel.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// A flexible row layout used for list items, settings rows, and menu entries.
///
/// Structure:
/// * Optional leading icon container
/// * Title (required)
/// * Optional subtitle
/// * Optional trailing widget (switch, chevron, button, etc.)
///
/// The [danger] flag visually highlights destructive or sensitive actions
/// by tinting the leading icon background and icon color with the error
/// color from the theme.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.danger = false,
    this.colorScheme,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool danger;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger
                    ? scheme.error.withAlpha(31)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 18,
                color: danger ? scheme.error : scheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body(scheme),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppText.caption(scheme),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A section header label used to separate content groups.
///
/// Typically used above lists or grouped UI sections.
///
/// Features:
/// * Uppercase tracking style for visual hierarchy
/// * Optional trailing action widget (e.g. “See all” button)
/// * Theme-aware typography
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.action, this.colorScheme});

  final String label;
  final Widget? action;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 20, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: AppText.sectionLabel(scheme)),
          ?action,
        ],
      ),
    );
  }
}

/// A lightweight visual toggle switch.
///
/// This widget is a purely UI-driven representation of a boolean state.
/// It does not manage state internally; instead it relies on [onChanged]
/// callback for external state management.
///
/// Behavior:
/// * Animated thumb transition
/// * Tap toggles state if [onChanged] is provided
/// * Uses theme colors for active/inactive states
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.on,
    this.onChanged,
    this.colorScheme,
  });

  final bool on;
  final ValueChanged<bool>? onChanged;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!on),
      child: AnimatedContainer(
        duration: AppMotion.medium,
        width: 40,
        height: 24,
        padding: const EdgeInsets.all(2),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: on ? scheme.tertiary : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.chip,
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: scheme.onSurface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// A centered screen header with optional left and right action slots.
///
/// Commonly used at the top of screens to display:
/// * Page title (required)
/// * Optional subtitle
/// * Navigation or action buttons (left/right)
///
/// Layout:
/// * Left slot: fixed width (typically back button)
/// * Center: title + subtitle
/// * Right slot: contextual actions
///
/// Ensures consistent alignment across all screens.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.left,
    this.right,
    this.colorScheme,
  });

  final String title;
  final String? subtitle;
  final Widget? left;
  final Widget? right;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          SizedBox(width: 36, child: left),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: AppText.title(scheme),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null)
                  Text(subtitle!, style: AppText.micro(scheme)),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: Align(alignment: Alignment.centerRight, child: right),
          ),
        ],
      ),
    );
  }
}

/// A pagination indicator used primarily in onboarding flows.
///
/// Displays a row of dots where the active step is visually expanded.
///
/// Behavior:
/// * Active dot expands in width
/// * Inactive dots remain small and subtle
/// * Fully theme-aware
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.active,
    this.count = 3,
    this.colorScheme,
  });

  final int active;
  final int count;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: on ? 24 : 6,
          height: 4,
          decoration: BoxDecoration(
            color: on ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: AppRadius.chip,
          ),
        );
      }),
    );
  }
}

/// A compact circular icon button used in headers and toolbars.
///
/// Designed for:
/// * Back buttons
/// * Close buttons
/// * Quick actions in constrained spaces
///
/// Features:
/// * Circular touch target
/// * Theme-aware background and foreground colors
/// * Gesture-based tap handling
///
/// Does not include built-in ripple; uses GestureDetector for minimal UI.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.background,
    this.foreground,
    this.colorScheme,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (background ?? scheme.surfaceContainer),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: (foreground ?? scheme.onSurface)),
      ),
    );
  }
}
