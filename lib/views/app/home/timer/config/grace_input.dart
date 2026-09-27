import 'package:flutter/material.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A slider for configuring the grace period of a timer.
///
/// The grace period determines how long the timer waits after reaching its
/// duration before the configured warning or alert is triggered.
///
/// The slider supports values from `0` to [maxSeconds] seconds in one-second
/// increments. Several major points are visually marked on the slider to make
/// commonly useful durations easier to identify.
///
/// A `null` [gracePeriod] defaults to 10 seconds.
///
/// The selected duration is reported through [onChanged] whenever the slider
/// value changes.
class GraceInput extends StatefulWidget {
  /// Creates a grace period input.
  ///
  /// [gracePeriod] is the initial grace period. A `null` value defaults to
  /// 10 seconds.
  ///
  /// [onChanged] is called whenever the selected grace period changes.
  const GraceInput({super.key, required this.isNew, required this.gracePeriod, required this.onChanged});

  final bool isNew;

  /// The initial grace period.
  ///
  /// A `null` value causes the input to start at 10 seconds.
  final Duration? gracePeriod;

  /// Called whenever the selected grace period changes.
  final ValueChanged<Duration> onChanged;

  @override
  State<GraceInput> createState() => _GraceInputState();
}

/// State implementation for [GraceInput].
///
/// Maintains the currently selected grace period in seconds and updates the
/// parent widget whenever the slider value changes.
class _GraceInputState extends State<GraceInput> {
  static const double maxSeconds = 300;
  late double _seconds;

  @override
  void initState() {
    super.initState();

    Duration seconds = widget.gracePeriod ?? Duration(seconds: (widget.isNew) ? 10 : 0);
    _seconds = seconds.inSeconds.clamp(0, maxSeconds).toDouble();

    widget.onChanged(seconds);
  }

  void _onChanged(double value) {
    setState(() {
      _seconds = value;
    });

    widget.onChanged(Duration(seconds: value.round()));
  }

  String _formatDuration(double value) {
    final Duration duration = Duration(seconds: value.round());

    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (minutes == 0 && seconds <= 59) {
      return '${seconds}s';
    } else if (minutes != 0 && seconds == 0) {
      return '${minutes}m';
    }

    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.ms),
      child: Column(
        children: [
          AppRow(
            padding: EdgeInsets.zero,
            title: local.translate("timer_configuration.grace_period.warning"),
            subtitle: (_seconds == 0)
                ? local.translate("timer_configuration.grace_period.false")
                : '${local.translate("timer_configuration.grace_period.buzzer.0")}'
                      ' ${_formatDuration(_seconds)} '
                      '${local.translate("timer_configuration.grace_period.buzzer.1")}',
            trailing: Pill(label: _formatDuration(_seconds), backColor: scheme.secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              trackShape: const MajorTickSliderTrackShape(),

              // The thumb.
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppRadius.sm),

              // Hide Flutter's normal tick marks because
              // we're drawing our own.
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              // ignore: deprecated_member_use
              year2023: true,
              activeColor: scheme.primary,
              inactiveColor: scheme.surfaceContainerLow,
              secondaryActiveColor: scheme.primary.withAlpha(155),
              thumbColor: scheme.onSurface,

              value: _seconds,
              min: 0,
              max: maxSeconds,

              // 1-second increments.
              divisions: 300,

              onChanged: _onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom slider track that displays major duration markers.
///
/// The track renders the active and inactive portions of the slider and
/// places visual markers at the durations defined by [majorPoints].
///
/// This track shape is intended to be used with [SliderThemeData.trackShape]
/// on a [Slider].
class MajorTickSliderTrackShape extends SliderTrackShape {
  const MajorTickSliderTrackShape();

  /// The durations, in seconds, represented by major visual markers.
  ///
  /// The current values represent:
  ///
  /// - 10 seconds
  /// - 30 seconds
  /// - 1 minute
  /// - 5 minutes
  static const List<double> majorPoints = [10, 30, 60, 300];

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;

    return Rect.fromLTWH(0.0, trackTop, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final canvas = context.canvas;

    final trackRect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);

    final activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.blue;

    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.grey;

    // Draw inactive track.
    canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(2)), inactivePaint);

    // Draw active track.
    final activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx.clamp(trackRect.left, trackRect.right), trackRect.bottom);

    canvas.drawRRect(RRect.fromRectAndRadius(activeRect, const Radius.circular(2)), activePaint);

    // Draw major points.
    final tickPaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue
      ..style = PaintingStyle.fill;

    for (final seconds in majorPoints) {
      final position = trackRect.left + (seconds / 300) * trackRect.width;

      canvas.drawCircle(Offset(position, trackRect.center.dy), 6, tickPaint);
    }
  }
}
