import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'bottom_nav.dart';
import '../../data/all.dart';

/// A reusable base layout widget that provides the standard screen structure
/// used throughout the application.
///
/// [ScreenBase] establishes a consistent foundation for application screens
/// by providing:
/// * A [Scaffold] using the active theme's surface color.
/// * [SafeArea] handling to keep content clear of system UI.
/// * Consistent screen padding controlled by [noSpacing].
/// * An optional [AppHeader] displayed above the screen content.
/// * An optional [BottomNav] displayed below the content.
/// * Automatic hiding of the bottom navigation when the keyboard is visible.
///
/// Use [ScreenBase] as the root widget of a screen when that screen should
/// follow the application's standard layout conventions.
///
/// Example:
/// ```dart
/// ScreenBase(
///   header: AppHeader(title: 'Settings'),
///   bottomNavDestination: 'settings',
///   child: SettingsContent(),
/// )
/// ```
class ScreenBase extends StatefulWidget {
  const ScreenBase({super.key, required this.child, this.noSpacing = false, this.bottomNavDestination = '', this.header});

  final Widget child;
  final bool noSpacing;
  final String bottomNavDestination;
  final AppHeader? header;

  @override
  State<ScreenBase> createState() => _ScreenBaseState();
}

/// State implementation for [ScreenBase].
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
            ? Padding(padding: (widget.noSpacing) ? EdgeInsets.zero : AppSpacing.screen, child: widget.child)
            : Column(
                children: [
                  ?widget.header,
                  Expanded(
                    child: Padding(padding: (widget.noSpacing) ? EdgeInsets.zero : AppSpacing.screen, child: widget.child),
                  ),
                  if (widget.bottomNavDestination != '' && !keyboardVisible)
                    Hero(
                      tag: 'nav',
                      curve: AppMotion.easeInOut,
                      flightShuttleBuilder: (context, animation, direction, from, to) {
                        return Material(type: MaterialType.transparency, child: direction == HeroFlightDirection.push ? to.widget : from.widget);
                      },
                      child: BottomNav(active: widget.bottomNavDestination),
                    ),
                ],
              ),
      ),
    );
  }
}

/// A reusable surface container for grouping related content.
///
/// [AppCard] provides the application's standard card styling, including:
/// * Theme-aware background and border colors.
/// * Consistent rounded corners.
/// * Configurable internal padding.
/// * Optional external margin.
/// * Optional solid background color.
/// * Optional gradient background.
///
/// When [gradient] is provided, it takes precedence over [color].
/// If neither [gradient] nor [color] is supplied, the card uses the theme's
/// [ColorScheme.surfaceContainer] color.
///
/// Use this widget for grouped forms, lists, settings sections, and other
/// content that should appear as a visually distinct surface.
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

/// Defines the semantic visual variants available to [PrimaryButton].
///
/// The values describe the intended meaning of an action rather than a
/// specific color. The actual colors are resolved from the active
/// [ColorScheme].
///
/// * [primary] is intended for the main action on a screen.
/// * [secondary] is intended for an alternative or supporting action.
/// * [tertiary] is intended for less prominent supporting actions.
/// * [warning] is intended for destructive, dangerous, or otherwise risky
///   actions.
/// * [muted] is intended for neutral or low-emphasis actions.
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

/// A reusable primary action button that follows the application's design
/// system.
///
/// [PrimaryButton] provides a consistent full-width or constrained action
/// surface with theme-aware colors, typography, spacing, rounded corners,
/// shadows, and optional iconography.
///
/// The visual appearance is controlled by [color], which maps semantic
/// button intent to the application's [ColorScheme].
///
/// The button can contain:
/// * An optional [label].
/// * An optional leading [icon].
/// * A configurable [width].
/// * An optional [onPressed] callback.
///
/// When [onPressed] is `null`, the button does not respond to taps. Use this
/// state when an action is temporarily unavailable or disabled.
///
/// [PrimaryButton] should generally be preferred over raw Material buttons
/// when implementing primary application actions so that screens remain
/// visually consistent.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, this.label, this.icon, this.color = ButtonColor.primary, this.width = double.infinity, this.onPressed});

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
      decoration: BoxDecoration(borderRadius: AppRadius.button, boxShadow: shadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.button,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.button,
          child: Ink(
            decoration: BoxDecoration(color: bg, borderRadius: AppRadius.button),
            child: Container(
              width: width,
              padding: AppSpacing.primaryButton,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: fg), if (label != null) const SizedBox(width: AppSpacing.sm)],
                  if (label != null)
                    Flexible(
                      child: Text(label!, style: AppText.body(scheme).copyWith(color: fg), softWrap: true),
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

/// A lightweight interactive wrapper that provides animated press feedback.
///
/// [Pressable] scales and slightly translates its [child] while the user is
/// pressing it, creating a subtle tactile response without displaying the
/// default Material ripple effect.
///
/// The widget supports the standard tap lifecycle through [onTap] and
/// internally handles press, release, and cancellation states.
///
/// The [borderRadius] is applied to the underlying Material interaction
/// surface, while [factory] controls the Material ink feature used by the
/// widget. By default, [NoSplash.splashFactory] is used so the interaction
/// remains visually minimal.
///
/// Use [Pressable] for cards, tiles, icon buttons, list items, and other
/// custom controls that need consistent press feedback without a ripple.

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child, this.borderRadius = AppRadius.card, this.factory = NoSplash.splashFactory});

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
          child: AnimatedScale(scale: _pressed ? 0.96 : 1.0, duration: AppMotion.fastest, curve: Curves.easeOut, child: widget.child),
        ),
      ),
    );
  }
}

/// A compact pill-shaped label used to display statuses, categories, tags,
/// and other short pieces of metadata.
///
/// [Pill] uses a tinted version of [backColor] for its background and the same
/// semantic color for its label, creating a lightweight visual treatment
/// rather than a solid-filled badge.
///
/// The supplied [label] is automatically converted to uppercase to maintain
/// consistent visual hierarchy throughout the application.
///
/// An optional [leading] widget can be displayed before the label, making the
/// component suitable for small icons, avatars, indicators, or other
/// contextual visuals.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.backColor, this.leading});

  final String label;
  final Color backColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.ms, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: backColor.withAlpha(38), borderRadius: AppRadius.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.xs)],
          Text(label.toUpperCase(), style: AppText.pillLabel.copyWith(color: backColor)),
        ],
      ),
    );
  }
}

/// A flexible horizontal row component for common application list layouts.
///
/// [AppRow] provides a consistent structure for settings rows, menu entries,
/// list items, and other two-column content:
/// * An optional leading icon inside a themed container.
/// * A required title.
/// * An optional subtitle below the title.
/// * An optional trailing widget such as a switch, button, or chevron.
///
/// The leading icon can be customized through its size, rotation, foreground
/// color, and background color. The [colorScheme] parameter can be supplied
/// when the row needs to use a color scheme different from the surrounding
/// [BuildContext].
///
/// The title area expands to consume the available horizontal space, while
/// the trailing widget remains constrained to its intrinsic size.
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
              decoration: BoxDecoration(color: iconBackground ?? scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Transform.rotate(
                angle: iconRotateAngle,
                child: Icon(icon, size: iconSize, color: iconColor ?? scheme.onSurface),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(scheme)),
                if (subtitle != null) Text(subtitle!, style: AppText.caption(scheme)),
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

/// A section heading used to visually separate related groups of content.
///
/// [SectionTitle] displays an uppercase label using the application's
/// section-label typography and can optionally display an [action] widget on
/// the trailing side.
///
/// Typical actions include buttons such as "See all", "Edit", or other
/// contextual controls.
///
/// The optional [colorScheme] allows the section to be rendered using a
/// specific theme color scheme rather than the one inherited from the
/// current context.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.action, this.colorScheme});

  final String label;
  final Widget? action;
  final ColorScheme? colorScheme;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = colorScheme ?? Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs, right: AppSpacing.xxs, top: 0, bottom: AppSpacing.sm),
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

/// A lightweight, externally controlled boolean toggle.
///
/// [AppToggle] represents an on/off state without maintaining that state
/// internally. The current value is supplied through [on], while [onChanged]
/// is responsible for updating the state in the parent widget.
///
/// The toggle provides animated thumb movement and theme-aware active and
/// inactive colors.
///
/// When [onChanged] is `null`, the toggle does not respond to user input and
/// effectively behaves as a non-interactive visual indicator.
///
/// This widget is useful when an application's design requires a custom
/// toggle appearance instead of the platform-standard [Switch].
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.on, this.onChanged, this.colorScheme});

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
          border: BoxBorder.all(color: on ? scheme.tertiary : scheme.onSurfaceVariant, width: 1.2, style: BorderStyle.solid),
          borderRadius: AppRadius.chip,
        ),
        child: AnimatedScale(
          duration: AppMotion.fastest,
          scale: on ? 1.0 : 0.75,
          curve: Curves.easeInOut,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: on ? scheme.onSurface : scheme.onSurfaceVariant, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// A reusable screen header with support for navigation, actions, search,
/// filtering, and animated route transitions.
///
/// [AppHeader] provides a consistent top-level header structure consisting of:
/// * A centered [title].
/// * An optional [subtitle].
/// * An optional [left] navigation or action widget.
/// * An optional [right] action widget.
/// * An optional [searchBar].
/// * An optional [filterBar].
/// * An optional bottom divider controlled by [bottomLine].
///
/// The left and right areas reserve fixed-width slots so that the centered
/// title remains visually aligned regardless of the presence or size of
/// surrounding actions.
///
/// Header elements use [Hero] transitions to provide smooth visual movement
/// between routes. The static [flight] method defines the shared cross-fade
/// behavior used during these transitions.
///
/// When [searchBar] or [filterBar] is provided, those elements are rendered
/// below the main header row while remaining part of the header structure.
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

  static Widget flight(BuildContext context, Animation<double> animation, HeroFlightDirection direction, BuildContext from, BuildContext to) {
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
              border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 1)),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, AppSpacing.ms, 0, AppSpacing.ms),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xl),
                  child: SizedBox(
                    height: 45,
                    width: 45,
                    child: Hero(
                      tag: 'header-left',
                      flightShuttleBuilder: (context, animation, direction, from, to) => flight(context, animation, direction, from, to),
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
                        text: TextSpan(text: title, style: AppText.title(scheme)),
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
                            flightShuttleBuilder: (context, animation, direction, from, to) => flight(context, animation, direction, from, to),
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                title,
                                maxLines: 1,
                                softWrap: false,
                                overflow: (isOverflowing) ? TextOverflow.ellipsis : TextOverflow.visible,
                                style: AppText.title(scheme),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Hero(
                            tag: 'header-subtitle',
                            flightShuttleBuilder: (context, animation, direction, from, to) => flight(context, animation, direction, from, to),
                            child: Material(
                              type: MaterialType.transparency,
                              child: subtitle == null
                                  ? const SizedBox(height: 0)
                                  : Text(subtitle!, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: AppText.micro(scheme)),
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
                      flightShuttleBuilder: (context, animation, direction, from, to) => flight(context, animation, direction, from, to),
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxxl, 0, AppSpacing.xxxl, AppSpacing.ms),
              child: Hero(
                tag: 'header-search',
                flightShuttleBuilder: (context, animation, direction, from, to) => flight(context, animation, direction, from, to),
                child: Material(type: MaterialType.transparency, child: searchBar!),
              ),
            ),
          if (filterBar != null)
            Hero(
              tag: 'header-filter',
              flightShuttleBuilder: (context, animation, direction, from, to) => flight(context, animation, direction, from, to),
              child: Material(type: MaterialType.transparency, child: filterBar!),
            ),
        ],
      ),
    );
  }
}

/// A compact progress indicator consisting of a row of animated-style dots.
///
/// [ProgressDots] represents progress through a finite sequence, such as an
/// onboarding flow, setup wizard, or multi-step form.
///
/// The item at [active] is displayed as a wider highlighted indicator, while
/// the remaining items use a smaller, muted appearance.
///
/// [count] determines the total number of indicators and defaults to three.
/// The optional [colorScheme] allows the indicator to use a specific theme
/// instead of the surrounding context's color scheme.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.active, this.count = 3, this.colorScheme});

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
          decoration: BoxDecoration(color: on ? scheme.primary : scheme.surfaceContainerHighest, borderRadius: AppRadius.chip),
        );
      }),
    );
  }
}

/// A compact circular icon button intended for headers and toolbars.
///
/// [CircleIconButton] provides a consistent circular touch target with
/// theme-aware background and foreground colors.
///
/// It is suitable for common compact actions such as:
/// * Navigating back.
/// * Closing a screen or dialog.
/// * Opening contextual actions.
/// * Triggering other toolbar operations.
///
/// When [onTap] is `null`, the widget is rendered as a non-interactive visual
/// element. When provided, [Pressable] is used to provide the application's
/// standard press animation.
///
/// The button's colors can be overridden through [background] and
/// [foreground], while [colorScheme] can be supplied for explicit theme
/// control.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onTap, this.background, this.foreground, this.colorScheme});

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
      decoration: BoxDecoration(color: background ?? scheme.surfaceContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 24, color: (foreground ?? scheme.onSurface)),
    );

    return onTap == null ? container : Pressable(onTap: onTap, child: container);
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
                  margin: EdgeInsets.symmetric(horizontal: marginHorizontal).add(EdgeInsetsGeometry.only(top: 110)),
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
  required Widget toast,
  ColorScheme? scheme,
  ToastGravity gravity = ToastGravity.TOP,
  Widget Function(BuildContext, Widget, ToastGravity?)? position,
  int secs = 3,
}) {
  final context = PermissionManager.instance.navigatorKey.currentContext!;
  final colorScheme = scheme ?? Theme.of(context).colorScheme;

  FToast fToast = FToast();
  fToast.init(context);

  fToast.removeCustomToast();
  fToast.removeQueuedCustomToasts();

  fToast.showToast(
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: AppRadius.card),
      child: toast,
    ),
    toastDuration: Duration(seconds: secs),
    fadeDuration: AppMotion.fasterer,
    gravity: gravity,
    positionedToastBuilder: position,
  );
}

/// Displays a standard application-level error message as a toast.
///
/// [showGenericErrorMessage] is intended for non-specific failures where the
/// application cannot or should not expose the underlying error details to
/// the user.
///
/// The message is localized through [AppLocalizations] using the
/// `generic_error` translation key and is styled according to the active
/// theme.
///
/// [bottom] optionally controls the distance between the bottom of the toast
/// and the bottom edge of the screen. When omitted, a default inset is used.
///
/// This helper provides a consistent presentation for generic errors across
/// screens and avoids duplicating toast configuration at individual call
/// sites.
void showGenericErrorMessage(BuildContext context, double? bottom) {
  bottom ??= 170;
  ColorScheme scheme = Theme.of(context).colorScheme;
  AppLocalizations local = AppLocalizations.of(context)!;
  showToast(
    scheme: scheme,
    toast: Text(local.translate("generic_error"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
    gravity: ToastGravity.BOTTOM,
    position: (context, child, gravity) {
      return Positioned(bottom: bottom, left: 100, right: 100, child: child);
    },
  );
}

/// A reusable search input styled according to the application's design
/// system.
///
/// [AppSearchBar] combines a search icon and a [TextField] inside a custom
/// themed container. Tapping anywhere on the search bar requests focus for
/// the underlying text field and opens the keyboard.
///
/// The widget supports:
/// * A required [hint] displayed when the field is empty.
/// * An optional [onChanged] callback for reacting to query changes.
/// * Automatic focus management.
/// * Theme-aware typography and colors.
/// * Input filtering that permits letters, numbers, and spaces.
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
                cursorColor: scheme.primary,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.hint,
                  hintStyle: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                ),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\p{L}\p{N} ]', unicode: true))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Describes a single selectable filter option displayed by [AppFilterBar].
///
/// Each option has a stable [id], a visible [label], and an [active] state
/// that determines its visual treatment.
///
/// [onPressed] is invoked when the option is selected. The callback is
/// optional, allowing an option to be displayed without being interactive.
///
/// [copyWith] creates a new option while preserving any values that are not
/// explicitly overridden. This is useful when constructing updated filter
/// collections without mutating the original option.
class AppFilterBarOption {
  const AppFilterBarOption({required this.id, required this.label, required this.active, this.onPressed});

  final String id;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  AppFilterBarOption copyWith({String? id, String? label, bool? active, VoidCallback? onPressed}) {
    return AppFilterBarOption(id: id ?? this.id, label: label ?? this.label, active: active ?? this.active, onPressed: onPressed ?? this.onPressed);
  }
}

/// A horizontally scrollable collection of filter controls.
///
/// [AppFilterBar] displays [AppFilterBarOption] instances as compact
/// selectable chips. Active filters use the theme's primary color, while
/// inactive filters use a neutral surface color.
///
/// The filter list is horizontally scrollable when its contents exceed the
/// available width. Additional horizontal spacing is included at both ends
/// of the list to align the filters with surrounding screen content.
///
/// When [searchBarAbove] is `true`, the bar assumes it is positioned directly
/// below a search bar and removes additional top spacing. Otherwise, it adds
/// vertical spacing above the filter controls.
class AppFilterBar extends StatefulWidget {
  const AppFilterBar({super.key, required this.filters, this.searchBarAbove = true});

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
      padding: EdgeInsets.fromLTRB(0, (widget.searchBarAbove) ? 0 : AppSpacing.md, 0, AppSpacing.md),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: (filter.active) ? scheme.primary : scheme.surfaceContainerHigh, borderRadius: AppRadius.chip),
                  child: Text(
                    filter.label,
                    style: AppText.caption(scheme).copyWith(color: (filter.active) ? scheme.onSurface : scheme.onSurfaceVariant),
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

/// A controller widget that provides accordion behavior for expandable
/// sections.
///
/// [AppExpandableGroup] manages the expansion state of a collection of
/// [AppExpandableItem] instances and ensures that no more than one item is
/// expanded at the same time.
///
/// Tapping the currently expanded item collapses it. Tapping a different
/// item collapses the previous item and expands the selected item.
///
/// The group itself owns the expansion state, while individual expandable
/// items remain responsible for rendering their visual representation.
///
/// [spacing] controls the vertical gap inserted between consecutive
/// expandable items.
class AppExpandableGroup extends StatefulWidget {
  const AppExpandableGroup({super.key, required this.children, this.spacing = AppSpacing.md});

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
          widget.children[i].build(expanded: expandedIndex == i, onPressed: () => _toggle(i)),
          if (i != widget.children.length - 1) SizedBox(height: widget.spacing),
        ],
      ],
    );
  }
}

/// Defines the contract for an item that can be controlled by an
/// [AppExpandableGroup].
///
/// [AppExpandableItem] separates expansion-state management from the visual
/// implementation of an expandable component. Implementations receive:
/// * [expanded], indicating whether the item should currently be open.
/// * [onPressed], which should be invoked by the item's trigger when the user
///   requests an expansion-state change.
///
/// This abstraction allows different expandable components to participate in
/// the same accordion group while retaining complete control over their own
/// layout and animations.
sealed class AppExpandableItem {
  const AppExpandableItem();

  /// Builds the expandable widget.
  ///
  /// The [expanded] value is controlled by [AppExpandableGroup].
  /// The [onPressed] callback should be attached to the widget's trigger
  /// element to notify the group when expansion changes.
  Widget build({required bool expanded, required VoidCallback onPressed});
}

/// A configurable expandable card designed for use with
/// [AppExpandableGroup].
///
/// [AppExpandableCard] displays a themed card with a tappable header and
/// animated content that can be expanded or collapsed.
///
/// The header supports:
/// * A required [title].
/// * An optional [subtitle].
/// * An optional leading icon or custom widget.
/// * An optional Hero animation identifier.
/// * An optional trailing widget.
/// * Custom icon size, rotation, colors, background, and gradient.
///
/// The card content is supplied through [child] and is revealed using a
/// height transition combined with a fade animation.
///
/// [AppExpandableCard] itself stores only the configuration for the item;
/// the internal [_AppExpandableCardView] handles the stateful animation
/// lifecycle required to render expansion and collapse transitions.
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

/// Internal stateful view responsible for rendering and animating an
/// [AppExpandableCard].
///
/// This widget separates the visual and animation implementation from the
/// configuration object represented by [AppExpandableCard].
///
/// [_AppExpandableCardView] maintains an [AnimationController] that drives
/// both the content [SizeTransition] and [FadeTransition]. Whenever the
/// externally supplied [expanded] value changes, the controller animates
/// forward or backward accordingly.
///
/// This class is intentionally private because callers should configure
/// expandable cards through [AppExpandableCard] rather than constructing the
/// internal view directly.
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
///
/// The controller and its derived animations are disposed when the widget is
/// removed from the widget tree.
class _AppExpandableCardViewState extends State<_AppExpandableCardView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _size;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: AppMotion.faster, value: widget.expanded ? 1 : 0);

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
              color: widget.iconBackground ?? ((widget.iconGradient == null) ? scheme.surfaceContainerHigh : null),
              gradient: (widget.iconGradient != null)
                  ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.iconGradient!)
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
                      color: widget.iconColor ?? ((widget.iconGradient == null) ? scheme.onSurface : Colors.white),
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
                        flightShuttleBuilder: (context, animation, direction, from, to) => AppHeader.flight(context, animation, direction, from, to),
                        child: Material(type: MaterialType.transparency, child: iconContainer),
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
                        if (widget.subtitle != null) Text(widget.subtitle!, style: AppText.caption(scheme)),
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
                  padding: EdgeInsets.only(bottom: AppSpacing.card.vertical / 2),
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

/// A compact action tile with a frosted-glass visual treatment.
///
/// [BlurActionTile] displays an optional [icon] and/or [label] inside a
/// rounded, translucent surface. A [BackdropFilter] applies a blur to the
/// content visible behind the tile, creating a lightweight glass-like
/// appearance.
///
/// The tile's appearance is controlled by:
/// * [background], which defines the translucent surface color.
/// * [border], which defines the translucent border color.
/// * [foreground], which controls icon and text colors.
/// * [icon] and [label], which define the displayed content.
///
/// When [onTap] is provided, the tile becomes interactive and uses
/// [Pressable] for consistent application-wide touch feedback. If [onTap] is
/// `null`, it remains visually present but does not respond to taps.
///
/// This widget is useful for compact actions such as toolbar commands,
/// contextual actions, shortcuts, and overlay controls.
///
/// Example:
/// ```dart
/// BlurActionTile(
///   icon: Icons.add,
///   label: 'Add item',
///   background: Colors.white,
///   border: Colors.white,
///   foreground: Colors.black,
///   onTap: _handleAddItem,
/// )
/// ```
class BlurActionTile extends StatelessWidget {
  /// Creates a [BlurActionTile].
  const BlurActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
    this.onTap,
  });

  /// The icon displayed at the start of the tile's content.
  final IconData? icon;

  /// The text displayed next to [icon].
  final String? label;

  /// The base color of the tile's translucent background.
  ///
  /// The color is rendered with reduced opacity to preserve the frosted-glass
  /// appearance.
  final Color background;

  /// The color used for the tile's border.
  ///
  /// The border is rendered with reduced opacity.
  final Color border;

  /// The color applied to both the icon and label.
  final Color foreground;

  /// Called when the tile is tapped.
  ///
  /// If `null`, the tile does not have a tap callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return Pressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: background.withAlpha(160),
              borderRadius: AppRadius.card,
              border: Border.all(color: border.withAlpha(100)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 16, color: foreground),
                  if (label != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(label!, style: AppText.bodySm(scheme).copyWith(color: foreground), softWrap: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
