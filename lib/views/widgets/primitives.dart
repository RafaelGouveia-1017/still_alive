import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'bottom_nav.dart';
import '../../data/all.dart';

/// A reusable base screen widget that defines the common layout structure
/// for all screens in the application.
///
/// `ScreenBase` ensures a consistent visual and behavioral foundation by:
/// * Wrapping content in a [SafeArea] to avoid system intrusions
/// * Providing a [Scaffold] with theme-based background styling
/// * Applying consistent padding around screen content
/// * Configuring system UI appearance (status bar, navigation bar, etc)
///
/// This widget is intended to be used as the root layout for individual screens
/// to enforce design consistency across the app.
///
/// Example:
/// ```dart
/// ScreenBase(
///   child: Center(
///     child: Text('Hello World'),
///   ),
/// )
/// ```
class ScreenBase extends StatefulWidget {
  const ScreenBase({
    super.key,
    required this.child,
    this.bottomNavDestination = '',
    this.header,
  });

  final Widget child;
  final String bottomNavDestination;
  final AppHeader? header;

  @override
  State<ScreenBase> createState() => _ScreenBaseState();
}

/// State class for [ScreenBase].
class _ScreenBaseState extends State<ScreenBase> {
  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: (widget.bottomNavDestination == '' && widget.header == null)
            ? Padding(padding: AppSpacing.screen, child: widget.child)
            : Column(
                children: [
                  ?widget.header,
                  Expanded(
                    child: Padding(
                      padding: AppSpacing.screen,
                      child: widget.child,
                    ),
                  ),
                  if (widget.bottomNavDestination != '' && !keyboardVisible)
                    Hero(
                      tag: 'nav',
                      curve: AppMotion.easeInOut,
                      flightShuttleBuilder:
                          (context, animation, direction, from, to) {
                            return Material(
                              type: MaterialType.transparency,
                              child: direction == HeroFlightDirection.push
                                  ? to.widget
                                  : from.widget,
                            );
                          },
                      child: BottomNav(active: widget.bottomNavDestination),
                    ),
                ],
              ),
      ),
    );
  }
}

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
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      margin: margin,
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
    this.label,
    this.icon,
    this.color = ButtonColor.primary,
    this.width = double.infinity,
    this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final ButtonColor color;
  final double width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    List<BoxShadow> shadow = const [];
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
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.button,
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.button,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.button,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.button,
            ),
            child: Container(
              width: width,
              padding: AppSpacing.primaryButton,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    if (label != null) const SizedBox(width: AppSpacing.sm),
                  ],
                  if (label != null)
                    Text(
                      label!,
                      style: AppText.body(scheme).copyWith(color: fg),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A widget that provides a subtle press animation for its [child] when
/// interacted with.
///
/// [Pressable] scales its child down while pressed, creating lightweight
/// visual feedback similar to a button press. It supports tap, long press,
/// and double tap gestures through the corresponding callback properties.
///
/// Unlike [InkWell], this widget does not display a Material ripple effect.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = AppRadius.card,
    this.factory = NoSplash.splashFactory,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final InteractiveInkFeatureFactory factory;

  @override
  State<Pressable> createState() => _PressableState();
}

/// State implementation for [Pressable].
class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: widget.borderRadius,
      child: InkWell(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) async {
          await Future.delayed(AppMotion.fastest);
          _setPressed(false);
        },
        onTapCancel: () async {
          await Future.delayed(AppMotion.fastest);
          _setPressed(false);
        },
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 150));
          widget.onTap?.call();
        },
        highlightColor: Colors.transparent,
        splashFactory: widget.factory,
        child: AnimatedSlide(
          offset: _pressed ? const Offset(0, 0.015) : Offset.zero,
          duration: AppMotion.fastest,
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: AppMotion.fastest,
            curve: Curves.easeOut,
            child: widget.child,
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
    required this.backColor,
    this.leading,
  });

  final String label;
  final Color backColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.ms,
        vertical: AppSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        color: backColor.withAlpha(38),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label.toUpperCase(),
            style: AppText.pillLabel.copyWith(color: backColor),
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
/// * Icon container settings (background, foreground)
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
    this.iconSize = 18,
    this.iconRotateAngle = 0,
    this.iconColor,
    this.iconBackground,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.md),
    this.colorScheme,
  });

  final IconData? icon;
  final double iconSize;
  final double iconRotateAngle;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground ?? scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Transform.rotate(
                angle: iconRotateAngle,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(scheme)),
                if (subtitle != null)
                  Text(subtitle!, style: AppText.caption(scheme)),
              ],
            ),
          ),
          if (trailing != null)
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.ms),
              child: trailing,
            ),
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
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        right: AppSpacing.xxs,
        top: 0,
        bottom: AppSpacing.sm,
      ),
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
        duration: AppMotion.fastest,
        curve: AppMotion.easeInOut,
        width: 40,
        height: 24,
        padding: const EdgeInsets.all(AppSpacing.xxxs),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: on ? scheme.tertiary : scheme.surfaceContainerHighest,
          border: BoxBorder.all(
            color: on ? scheme.tertiary : scheme.onSurfaceVariant,
            width: 1.2,
            style: BorderStyle.solid,
          ),
          borderRadius: AppRadius.chip,
        ),
        child: AnimatedScale(
          duration: AppMotion.fastest,
          scale: on ? 1.0 : 0.75,
          curve: Curves.easeInOut,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: on ? scheme.onSurface : scheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A screen header with a centered title and optional navigation,
/// actions, search, and filtering.
///
/// Commonly used at the top of screens to display:
/// * Page title (required)
/// * Optional subtitle
/// * Navigation or action buttons (left/right)
/// * Optional search bar
/// * Optional filter bar
///
/// Layout:
/// * Left slot: fixed width (typically a back button)
/// * Center: title and optional subtitle
/// * Right slot: contextual actions
///
/// Uses Hero animations to smoothly transition the title, subtitle,
/// and action slots between routes.
///
/// An optional bottom divider can be displayed to separate the header
/// from the page content.
///
/// Ensures consistent alignment across all screens.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.left,
    this.right,
    this.searchBar,
    this.filterBar,
    this.colorScheme,
    this.bottomLine = true,
  });

  final String title;
  final String? subtitle;
  final Widget? left;
  final Widget? right;
  final AppSearchBar? searchBar;
  final AppFilterBar? filterBar;
  final ColorScheme? colorScheme;
  final bool bottomLine;

  static Widget flight(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final fadeOut = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.4, curve: AppMotion.easeOut),
    );

    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.6, 1.0, curve: AppMotion.easeIn),
    );

    final isPush = direction == HeroFlightDirection.push;

    final fromWidget = isPush ? from.widget : to.widget;
    final toWidget = isPush ? to.widget : from.widget;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          return Stack(
            fit: StackFit.loose,
            children: [
              Opacity(opacity: 1.0 - fadeOut.value, child: fromWidget),
              Opacity(opacity: fadeIn.value, child: toWidget),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;

    return Container(
      decoration: (bottomLine)
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant, width: 1),
              ),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.ms,
              0,
              AppSpacing.ms,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xl),
                  child: SizedBox(
                    height: 45,
                    width: 45,
                    child: Hero(
                      tag: 'header-left',
                      flightShuttleBuilder:
                          (context, animation, direction, from, to) =>
                              flight(context, animation, direction, from, to),
                      child: Material(
                        type: MaterialType.transparency,
                        child: left ?? ColoredBox(color: scheme.surface),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final titlePainter = TextPainter(
                        text: TextSpan(
                          text: title,
                          style: AppText.title(scheme),
                        ),
                        maxLines: 1,
                        textDirection: Directionality.of(context),
                      )..layout();

                      final titleWidth = titlePainter.width;
                      final availableWidth = constraints.maxWidth;
                      final isOverflowing = titleWidth > availableWidth;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: 'header-title',
                            flightShuttleBuilder:
                                (context, animation, direction, from, to) =>
                                    flight(
                                      context,
                                      animation,
                                      direction,
                                      from,
                                      to,
                                    ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                title,
                                maxLines: 1,
                                softWrap: false,
                                overflow: (isOverflowing)
                                    ? TextOverflow.ellipsis
                                    : TextOverflow.visible,
                                style: AppText.title(scheme),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Hero(
                            tag: 'header-subtitle',
                            flightShuttleBuilder:
                                (context, animation, direction, from, to) =>
                                    flight(
                                      context,
                                      animation,
                                      direction,
                                      from,
                                      to,
                                    ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: subtitle == null
                                  ? const SizedBox(height: 0)
                                  : Text(
                                      subtitle!,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      style: AppText.micro(scheme),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xl),
                  child: SizedBox(
                    width: 45,
                    height: 45,
                    child: Hero(
                      tag: 'header-right',
                      flightShuttleBuilder:
                          (context, animation, direction, from, to) =>
                              flight(context, animation, direction, from, to),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: right ?? ColoredBox(color: scheme.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (searchBar != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl,
                0,
                AppSpacing.xxxl,
                AppSpacing.ms,
              ),
              child: Hero(
                tag: 'header-search',
                flightShuttleBuilder:
                    (context, animation, direction, from, to) =>
                        flight(context, animation, direction, from, to),
                child: Material(
                  type: MaterialType.transparency,
                  child: searchBar!,
                ),
              ),
            ),
          if (filterBar != null)
            Hero(
              tag: 'header-filter',
              flightShuttleBuilder: (context, animation, direction, from, to) =>
                  flight(context, animation, direction, from, to),
              child: Material(
                type: MaterialType.transparency,
                child: filterBar!,
              ),
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
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxs),
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

    final container = Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 24, color: (foreground ?? scheme.onSurface)),
    );

    return onTap == null
        ? container
        : Pressable(onTap: onTap, child: container);
  }
}

/// Displays a custom modal bottom sheet with a blurred background.
///
/// This bottom sheet appears from the bottom of the screen and applies a
/// blur effect to the background. Tapping outside the sheet dismisses it.
///
/// The sheet content is fully customizable via the [child] widget and is
/// styled using the provided [scheme] and horizontal margin.
///
/// The background interaction area is blurred and partially tinted using
/// the surface color from the given [scheme].
///
/// Type parameter [T] is the return type of the bottom sheet result.
///
/// Returns a [Future] that completes with the value passed to
/// `Navigator.pop(context, result)`, or `null` if dismissed.
///
/// Example:
/// ```dart
/// final result = await showBlurredBottomSheet<String>(
///   context: context,
///   scheme: Theme.of(context).colorScheme,
///   marginHorizontal: 16,
///   child: Text("Hello"),
/// );
/// ```
///
/// Parameters:
/// - [context]: The build context used to display the bottom sheet.
/// - [scheme]: The [ColorScheme] used for styling the sheet and backdrop.
/// - [marginHorizontal]: Horizontal margin applied to the sheet container.
/// - [child]: The widget displayed inside the bottom sheet.
Future<T?> showBlurredBottomSheet<T>({
  required BuildContext context,
  required ColorScheme scheme,
  double marginHorizontal = 10,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (context) {
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      return SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.1, sigmaY: 1.1),
                child: Container(color: scheme.surface.withAlpha(25)),
              ),
            ),

            AnimatedPadding(
              duration: AppMotion.fastest,
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: marginHorizontal,
                  ).add(EdgeInsetsGeometry.only(top: 110)),
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      side: BorderSide(color: Colors.transparent),
                    ),
                    child: Padding(padding: AppSpacing.card, child: child),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Displays a custom toast using the `fluttertoast` package.
///
/// The toast is shown using an [FToast] instance attached to the current
/// navigator context. Any currently visible toast and any queued toasts are
/// removed before displaying the new one, ensuring that only a single toast is
/// shown at a time.
///
/// The toast content is wrapped in a full-width container using the provided
/// [scheme] for its background color and the application's default card border
/// radius.
///
/// Parameters:
/// * [scheme]: The [ColorScheme] used to style the toast container.
/// * [toast]: The widget displayed as the toast content.
/// * [gravity]: Controls where the toast appears on the screen. Defaults to
///   [ToastGravity.TOP].
/// * [position]: An optional custom builder for positioning the toast. When
///   provided, it overrides the default positioning behavior.
/// * [secs]: The duration, in seconds, that the toast remains visible.
///   Defaults to `2`.
///
/// Throws if no valid navigator context is available from
/// `PermissionManager.instance.navigatorKey.currentContext`.

/// shown toast using the fluttertoast package
void showToast({
  required ColorScheme scheme,
  required Widget toast,
  ToastGravity gravity = ToastGravity.TOP,
  Widget Function(BuildContext, Widget, ToastGravity?)? position,
  int secs = 3,
}) {
  FToast fToast = FToast();
  fToast.init(PermissionManager.instance.navigatorKey.currentContext!);

  fToast.removeCustomToast();
  fToast.removeQueuedCustomToasts();

  fToast.showToast(
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.card,
      ),
      child: toast,
    ),
    toastDuration: Duration(seconds: secs),
    fadeDuration: AppMotion.fasterer,
    gravity: gravity,
    positionedToastBuilder: position,
  );
}

/// Displays a custom generic error toast.
///
/// Mainly used to inform the user that something went wrong.
///
/// [bottom] is the distance that the toast's bottom edge is inset from the
/// bottom of the screen.
void showGenericErrorMessage(BuildContext context, double? bottom) {
  bottom ??= 170;
  ColorScheme scheme = Theme.of(context).colorScheme;
  AppLocalizations local = AppLocalizations.of(context)!;
  showToast(
    scheme: scheme,
    toast: Text(
      local.translate("generic_error"),
      style: AppText.bodySm(scheme),
      textAlign: TextAlign.center,
    ),
    gravity: ToastGravity.BOTTOM,
    position: (context, child, gravity) {
      return Positioned(bottom: bottom, left: 100, right: 100, child: child);
    },
  );
}

/// A reusable search bar widget with a styled input field.
///
/// The [AppSearchBar] provides a consistent search input UI across the app,
/// including an icon, hint text, input formatting, and focus handling.
///
/// The entire search bar container is tappable and will request focus for the
/// underlying text field, opening the keyboard.
///
/// The [hint] text is displayed when the search field is empty.
/// The optional [onChanged] callback is called whenever the input changes.
///
/// Example:
/// ```dart
/// AppSearchBar(
///   hint: 'Search products',
///   onChanged: (query) {
///     // Perform search
///   },
/// )
/// ```
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({super.key, required this.hint, this.onChanged});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

/// State implementation for [AppSearchBar].
class _AppSearchBarState extends State<AppSearchBar> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Container(
        padding: AppSpacing.searchBar,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadius.card,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                focusNode: _focusNode,
                autofocus: false,
                onChanged: widget.onChanged,
                onTapOutside: (_) {
                  _focusNode.unfocus();
                },
                style: AppText.bodySm(scheme),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.hint,
                  hintStyle: AppText.bodySm(
                    scheme,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\p{L}\p{N} ]', unicode: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents a single filter option displayed by an [AppFilterBar].
///
/// Each option consists of a text [label], an [active] state that determines
/// whether the filter is visually highlighted, and an optional [onPressed]
/// callback that is invoked when the filter is selected.
class AppFilterBarOption {
  const AppFilterBarOption({
    required this.id,
    required this.label,
    required this.active,
    this.onPressed,
  });

  final String id;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  AppFilterBarOption copyWith({
    String? id,
    String? label,
    bool? active,
    VoidCallback? onPressed,
  }) {
    return AppFilterBarOption(
      id: id ?? this.id,
      label: label ?? this.label,
      active: active ?? this.active,
      onPressed: onPressed ?? this.onPressed,
    );
  }
}

/// A horizontally scrollable filter bar.
///
/// Displays a collection of [AppFilterBarOption] chips that indicate the
/// available filters and their active states.
///
/// When [searchBarAbove] is `true`, the filter bar is rendered immediately
/// below an external search bar. Otherwise, additional top spacing is applied.
class AppFilterBar extends StatefulWidget {
  const AppFilterBar({
    super.key,
    required this.filters,
    this.searchBarAbove = true,
  });

  final List<AppFilterBarOption> filters;
  final bool searchBarAbove;

  @override
  State<AppFilterBar> createState() => _AppFilterBarState();
}

/// State implementation for [AppFilterBar].
class _AppFilterBarState extends State<AppFilterBar> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        (widget.searchBarAbove) ? 0 : AppSpacing.md,
        0,
        AppSpacing.md,
      ),
      child: SizedBox(
        height: 32,
        child: Center(
          child: ListView.separated(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: widget.filters.length + 2,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              if (i == 0 || i == widget.filters.length + 1) {
                return const SizedBox(width: AppSpacing.xl);
              }

              final filter = widget.filters[i - 1];

              return Pressable(
                onTap: filter.onPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (filter.active)
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    borderRadius: AppRadius.chip,
                  ),
                  child: Text(
                    filter.label,
                    style: AppText.caption(scheme).copyWith(
                      color: (filter.active)
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A controller widget that manages a group of expandable sections.
///
/// This widget provides accordion behavior by ensuring that at most one
/// expandable item is open at any given time.
///
/// Tapping an already expanded item collapses it, while tapping another
/// item automatically closes the previously expanded one before opening
/// the selected item.
///
/// Expandable sections are provided through [AppExpandableItem]
/// implementations.
class AppExpandableGroup extends StatefulWidget {
  const AppExpandableGroup({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
  });

  final List<AppExpandableItem> children;
  final double spacing;

  @override
  State<AppExpandableGroup> createState() => _AppExpandableGroupState();
}

/// State implementation for [AppExpandableGroup].
///
/// Stores the index of the currently expanded item and rebuilds expandable
/// children with the updated expansion state.
class _AppExpandableGroupState extends State<AppExpandableGroup> {
  int? expandedIndex;

  void _toggle(int index) {
    setState(() {
      expandedIndex = expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < widget.children.length; i++) ...[
          widget.children[i].build(
            expanded: expandedIndex == i,
            onPressed: () => _toggle(i),
          ),
          if (i != widget.children.length - 1) SizedBox(height: widget.spacing),
        ],
      ],
    );
  }
}

/// Defines a section that can be managed by [AppExpandableGroup].
///
/// Implementations are responsible for creating their own expandable UI
/// while receiving the current expansion state and interaction callback
/// from the parent group.
///
/// This allows multiple expandable widget types to coexist in the same
/// group while keeping expansion logic centralized.
sealed class AppExpandableItem {
  const AppExpandableItem();

  /// Builds the expandable widget.
  ///
  /// The [expanded] value is controlled by [AppExpandableGroup].
  /// The [onPressed] callback should be attached to the widget's trigger
  /// element to notify the group when expansion changes.
  Widget build({required bool expanded, required VoidCallback onPressed});
}

/// A reusable expandable card that behaves like a dropdown section.
///
/// The widget displays a tappable header and reveals its child with a
/// smooth animated expansion.
///
/// Features:
/// * Smooth height animation
/// * Fade animation for expanded content
/// * Rotating chevron indicating expanded/collapsed state
/// * Supports optional leading icon and subtitle
/// * Uses [AppCard] styling for visual consistency
///
/// This widget is intended to be used inside [AppExpandableGroup], where
/// expansion state is controlled externally.
class AppExpandableCard extends AppExpandableItem {
  const AppExpandableCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.cardPadding = AppSpacing.card,
    this.cardMargin = EdgeInsets.zero,
    this.cardColor,
    this.cardBorderColor,
    this.cardGradient,
    this.iconHeroID,
    this.icon,
    this.iconWidget,
    this.iconSize = 26,
    this.iconRotateAngle = 0,
    this.iconColor,
    this.iconBackground,
    this.iconGradient,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry cardPadding;
  final EdgeInsetsGeometry cardMargin;
  final Color? cardColor;
  final Color? cardBorderColor;
  final Gradient? cardGradient;
  final String? iconHeroID;
  final IconData? icon;
  final Widget? iconWidget;
  final double iconSize;
  final double iconRotateAngle;
  final Color? iconColor;
  final Color? iconBackground;
  final List<Color>? iconGradient;
  final Widget? trailing;

  @override
  Widget build({required bool expanded, required VoidCallback onPressed}) {
    return _AppExpandableCardView(
      title: title,
      subtitle: subtitle,
      expanded: expanded,
      onPressed: onPressed,
      cardPadding: cardPadding,
      cardMargin: cardMargin,
      cardColor: cardColor,
      cardBorderColor: cardBorderColor,
      cardGradient: cardGradient,
      iconHeroID: iconHeroID,
      icon: icon,
      iconWidget: iconWidget,
      iconSize: iconSize,
      iconRotateAngle: iconRotateAngle,
      iconColor: iconColor,
      iconBackground: iconBackground,
      iconGradient: iconGradient,
      trailing: trailing,
      child: child,
    );
  }
}

/// Internal stateful implementation of [AppExpandableCard].
///
/// This widget is responsible for rendering the expandable card UI and
/// managing the animation lifecycle required for expanding and collapsing
/// the content section.
///
/// The parent [AppExpandableCard] provides the current expansion state and
/// rebuilds this widget whenever the state changes. This separation allows
/// [AppExpandableCard] to remain a lightweight configuration object while
/// keeping animation state inside a stateful widget.
class _AppExpandableCardView extends StatefulWidget {
  const _AppExpandableCardView({
    required this.title,
    required this.child,
    required this.expanded,
    required this.onPressed,
    this.subtitle,
    this.cardPadding = AppSpacing.card,
    this.cardMargin = EdgeInsets.zero,
    this.cardColor,
    this.cardBorderColor,
    this.cardGradient,
    this.iconHeroID,
    this.icon,
    this.iconWidget,
    this.iconSize = 26,
    this.iconRotateAngle = 0,
    this.iconColor,
    this.iconBackground,
    this.iconGradient,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool expanded;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry cardPadding;
  final EdgeInsetsGeometry cardMargin;
  final Color? cardColor;
  final Color? cardBorderColor;
  final Gradient? cardGradient;
  final String? iconHeroID;
  final IconData? icon;
  final Widget? iconWidget;
  final double iconSize;
  final double iconRotateAngle;
  final Color? iconColor;
  final Color? iconBackground;
  final List<Color>? iconGradient;
  final Widget? trailing;

  @override
  State<_AppExpandableCardView> createState() => _AppExpandableCardViewState();
}

/// State implementation for [_AppExpandableCardView].
///
/// Controls the expand/collapse animations using a shared
/// [AnimationController].
///
/// The controller drives both:
/// * A [SizeTransition] animation for the expandable content height.
/// * A [FadeTransition] animation for the content visibility.
///
/// The animation direction is updated whenever the parent's [expanded]
/// value changes.
class _AppExpandableCardViewState extends State<_AppExpandableCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _size;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.faster,
      value: widget.expanded ? 1 : 0,
    );

    _size = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 1, curve: AppMotion.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _AppExpandableCardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.expanded != oldWidget.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget? iconContainer = (widget.icon != null || widget.iconWidget != null)
        ? Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color:
                  widget.iconBackground ??
                  ((widget.iconGradient == null)
                      ? scheme.surfaceContainerHigh
                      : null),
              gradient: (widget.iconGradient != null)
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.iconGradient!,
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: widget.iconRotateAngle,
              child: (widget.icon != null)
                  ? Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color:
                          widget.iconColor ??
                          ((widget.iconGradient == null)
                              ? scheme.onSurface
                              : Colors.white),
                    )
                  : widget.iconWidget,
            ),
          )
        : null;

    return AppCard(
      padding: EdgeInsets.zero,
      margin: widget.cardMargin,
      color: widget.cardColor,
      borderColor: widget.cardBorderColor,
      gradient: widget.cardGradient,
      child: Column(
        children: [
          InkWell(
            borderRadius: AppRadius.card,
            onTap: widget.onPressed,
            child: Padding(
              padding: widget.cardPadding,
              child: Row(
                children: [
                  if (iconContainer != null) ...[
                    if (widget.iconHeroID != null) ...[
                      Hero(
                        tag: widget.iconHeroID!,
                        flightShuttleBuilder:
                            (context, animation, direction, from, to) =>
                                AppHeader.flight(
                                  context,
                                  animation,
                                  direction,
                                  from,
                                  to,
                                ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: iconContainer,
                        ),
                      ),
                    ] else
                      iconContainer,
                    const SizedBox(width: AppSpacing.md),
                  ],

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: AppText.body(scheme)),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: AppText.caption(scheme),
                          ),
                      ],
                    ),
                  ),

                  if (widget.trailing != null)
                    Container(
                      margin: const EdgeInsets.only(left: AppSpacing.ms),
                      child: widget.trailing,
                    ),

                  Container(
                    margin: const EdgeInsets.only(left: AppSpacing.ms),
                    child: AnimatedRotation(
                      turns: widget.expanded ? 0.5 : 0,
                      duration: AppMotion.fasterer,
                      curve: AppMotion.easeInOut,
                      child: const Icon(LucideIcons.chevronDown, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          ClipRect(
            child: SizeTransition(
              sizeFactor: _size,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _fade,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: AppSpacing.card.vertical / 2,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
