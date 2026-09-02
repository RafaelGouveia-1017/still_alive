import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/app_design.dart';

/// A circular countdown indicator with an animated progress ring and centered
/// label stack.
///
/// [CountdownRing] visually represents time or progress using a circular arc
/// that either fills toward a target value or depletes over time (when
/// [depleteOver] is provided).
///
/// The widget also supports optional caption text, custom colors, and tap
/// interaction.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.time,
    required this.label,
    this.color,
    this.progress = 1.0,
    this.caption,
    this.diameter = 300,
    this.strokeWidth = 14,
    this.timeStyle,
    // When set, the arc depletes from full to empty over [depleteOver]
    // instead of revealing to [progress].
    this.depleteOver,
    this.onTap,
    this.colorScheme,
  });

  final String time;
  final String label;
  final Color? color;
  final double progress;
  final String? caption;
  final double diameter;
  final double strokeWidth;
  final TextStyle? timeStyle;
  final Duration? depleteOver;
  final VoidCallback? onTap;
  final ColorScheme? colorScheme;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

/// Internal state for [CountdownRing] responsible for driving animations.
///
/// This state manages an [AnimationController] and an animated sweep value
/// that determines how much of the circular arc is drawn. It supports two
/// modes:
/// * Progressive reveal (0 → [CountdownRing.progress]) for normal usage
/// * Linear depletion (1 → 0) when [CountdownRing.depleteOver] is set
class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Tween<double> _tween;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    if (widget.depleteOver != null) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.depleteOver,
      );
      _tween = Tween<double>(begin: 1.0, end: 0.0);
      _sweep = _tween.animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.linear),
      );
    } else {
      // Reveal to target progress
      _controller = AnimationController(vsync: this, duration: AppMotion.ring);
      _tween = Tween<double>(begin: 0.0, end: widget.progress);
      _sweep = _tween.animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.emphasized),
      );
    }
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.depleteOver == null) {
      _tween
        ..begin = _sweep.value
        ..end = widget.progress;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = widget.colorScheme ?? Theme.of(context).colorScheme;
    final content = SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.diameter),
              painter: _RingPainter(
                progress: _sweep.value,
                color: widget.color ?? scheme.primary,
                trackColor: scheme.surfaceContainerHigh,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: AppText.sectionLabel(
                    scheme,
                  ).copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.time,
                  style: widget.timeStyle ?? AppText.display(scheme),
                ),
                if (widget.caption != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(widget.caption!, style: AppText.caption(scheme)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.onTap == null) return content;
    return GestureDetector(onTap: widget.onTap, child: content);
  }
}

/// Custom painter responsible for rendering the circular countdown ring.
///
/// [_RingPainter] draws:
/// * A static background track circle
/// * A foreground progress arc representing [CountdownRing.progress]
///
/// The arc is rendered with rounded caps and a subtle blur to create a glow
/// effect, enhancing visual emphasis during animation.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        4,
      ); // glow approximation

    const start = -math.pi / 2; // 12 o'clock
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
