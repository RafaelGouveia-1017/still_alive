import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

/// A radial gradient whose shape can be independently scaled horizontally
/// and vertically to produce an elliptical gradient.
///
/// Unlike [RadialGradient], which produces a circular gradient unless its
/// rendering bounds are otherwise transformed, this gradient explicitly
/// applies separate horizontal and vertical scale factors. This makes it
/// possible to create effects such as soft elliptical highlights, glows,
/// shadows, or background lighting effects.
///
/// The gradient's center is specified using coordinates relative to the
/// widget's bounds rather than Flutter's [Alignment] coordinate system.
/// For example:
///
/// ```dart
/// ellipseRelativeCenter: Offset(0.5, 0.5)
/// ```
///
/// places the center in the middle of the widget, while:
///
/// ```dart
/// ellipseRelativeCenter: Offset(0.0, 0.0)
/// ```
///
/// places it at the top-left corner.
///
/// Values outside the `[0, 1]` range are supported, allowing the gradient's
/// center to be positioned outside the widget's bounds.
///
/// [backgroundColor] is composited underneath each gradient color using
/// [Color.alphaBlend] before the shader is created. This allows the gradient
/// to produce colors that visually blend with the intended background.
///
/// The [ellipseScale] controls the horizontal and vertical dimensions of the
/// gradient. A value of `1.0` represents the unscaled dimension, while values
/// greater than or less than `1.0` expand or contract the corresponding axis.
///
/// Example:
///
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     gradient: EllipticalGradient(
///       colors: [
///         Colors.white,
///         Colors.transparent,
///       ],
///       backgroundColor: Colors.blue,
///       ellipseRelativeCenter: Offset(0.5, 0.25),
///       ellipseScale: Scale(
///         widthFactor: 2.0,
///         heightFactor: 0.75,
///       ),
///     ),
///   ),
/// )
/// ```
class EllipticalGradient extends Gradient {
  /// The color underneath the gradient.
  ///
  /// Each gradient color is alpha-blended with this color before being passed
  /// to the underlying radial gradient shader.
  final Color backgroundColor;

  /// The center of the ellipse relative to the gradient's bounds.
  ///
  /// Coordinates are expressed as fractions of the widget's width and height:
  ///
  /// - `Offset(0, 0)` is the top-left corner.
  /// - `Offset(0.5, 0.5)` is the center.
  /// - `Offset(1, 1)` is the bottom-right corner.
  ///
  /// Values outside the `[0, 1]` range are allowed. For example,
  /// `Offset(1.5, 0.5)` places the center halfway down the widget but beyond
  /// its right edge.
  final Offset ellipseRelativeCenter;

  /// The horizontal and vertical scale factors applied to the gradient.
  ///
  /// [Scale.widthFactor] controls the horizontal extent of the ellipse, while
  /// [Scale.heightFactor] controls its vertical extent.
  final Scale ellipseScale;

  /// Creates an elliptical radial gradient.
  ///
  /// [colors] defines the colors used by the gradient and is inherited from
  /// [Gradient]. [backgroundColor] is used to alpha-blend those colors before
  /// rendering.
  ///
  /// [ellipseRelativeCenter] specifies the gradient center relative to the
  /// rendering bounds, and [ellipseScale] controls the ellipse's dimensions.
  ///
  /// [stops], when provided, specifies the normalized positions of the
  /// corresponding [colors].
  const EllipticalGradient({
    required super.colors,
    required this.backgroundColor,
    required this.ellipseRelativeCenter,
    required this.ellipseScale,
    super.stops,
  });

  /// Creates the shader used to render the elliptical gradient.
  ///
  /// The implementation delegates color interpolation to a
  /// [RadialGradient], while [_EllipseTransform] independently scales the
  /// shader along the horizontal and vertical axes.
  ///
  /// The relative center supplied by [ellipseRelativeCenter] is converted
  /// from the `[0, 1]` coordinate system into Flutter's `[-1, 1]`
  /// [Alignment] coordinate system.
  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    return RadialGradient(
      center: Alignment(ellipseRelativeCenter.dx * 2 - 1, ellipseRelativeCenter.dy * 2 - 1),
      colors: colors.map((color) => Color.alphaBlend(color, backgroundColor)).toList(),
      radius: 1,
      stops: stops,
      transform: _EllipseTransform(ellipseRelativeCenter: ellipseRelativeCenter, ellipseScale: ellipseScale),
    ).createShader(rect, textDirection: textDirection);
  }

  /// Returns a copy of this gradient scaled by [factor].
  ///
  /// Both the gradient colors and the ellipse dimensions are scaled. The
  /// center position and background color remain unchanged.
  @override
  EllipticalGradient scale(double factor) {
    return EllipticalGradient(
      backgroundColor: backgroundColor,
      colors: colors.map<Color>((Color color) => Color.lerp(null, color, factor)!).toList(),
      ellipseRelativeCenter: ellipseRelativeCenter,
      ellipseScale: ellipseScale * factor,
    );
  }

  /// Returns a copy of this gradient with the supplied [opacity].
  ///
  /// The alpha component of every gradient color is replaced with [opacity].
  /// The background color, gradient stops, center, and ellipse scale remain
  /// unchanged.
  @override
  EllipticalGradient withOpacity(double opacity) {
    return EllipticalGradient(
      colors: <Color>[for (final Color color in colors) color.withValues(alpha: opacity)],
      stops: stops,
      backgroundColor: backgroundColor,
      ellipseRelativeCenter: ellipseRelativeCenter,
      ellipseScale: ellipseScale,
    );
  }
}

/// Applies the non-uniform transformation required to turn a radial gradient
/// into an ellipse.
///
/// Flutter's [RadialGradient] is fundamentally circular. This transform
/// stretches the shader independently along the horizontal and vertical axes
/// according to a [_EllipseTransform.ellipseScale].
///
/// The transformation also compensates for the gradient center so that scaling
/// occurs around the requested [ellipseRelativeCenter] rather than around the
/// origin of the coordinate system.
///
/// This class is an implementation detail of [EllipticalGradient] and should
/// not normally be instantiated directly.
class _EllipseTransform extends GradientTransform {
  /// The center of the ellipse relative to the rendering bounds.
  final Offset ellipseRelativeCenter;

  /// The horizontal and vertical scale factors applied to the radial shader.
  final Scale ellipseScale;

  /// Creates an ellipse transformation.
  const _EllipseTransform({required this.ellipseRelativeCenter, required this.ellipseScale});

  /// Calculates the transformation matrix for the supplied gradient bounds.
  ///
  /// The axis scaling is adjusted according to the aspect ratio of [bounds].
  /// This keeps the requested ellipse proportions consistent regardless of
  /// whether the rendering area is wider or taller than it is high.
  ///
  /// The resulting matrix first scales the shader and then translates it so
  /// that the scaling is performed around [ellipseRelativeCenter].
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double widthFactor;
    final double heightFactor;
    if (bounds.width > bounds.height) {
      heightFactor = ellipseScale.heightFactor;
      widthFactor = ellipseScale.widthFactor * bounds.width / bounds.height;
    } else {
      heightFactor = ellipseScale.heightFactor * bounds.height / bounds.width;
      widthFactor = ellipseScale.widthFactor;
    }

    final transformMatrix = Matrix4.identity()..scaleByDouble(widthFactor, heightFactor, widthFactor, 1);

    final Offset originalCenterOffset = Offset(
      bounds.left + bounds.width * ellipseRelativeCenter.dx,
      bounds.top + bounds.height * ellipseRelativeCenter.dy,
    );

    final List<double> offsetLocation = transformMatrix.applyToVector3Array([originalCenterOffset.dx, originalCenterOffset.dy, 0.0]);
    final dx = originalCenterOffset.dx - offsetLocation[0];
    final dy = originalCenterOffset.dy - offsetLocation[1];

    return transformMatrix..translateByVector3(Vector3(dx / widthFactor, dy / heightFactor, 0));
  }
}

/// Defines independent horizontal and vertical scale factors.
///
/// [widthFactor] controls the horizontal size of an ellipse and
/// [heightFactor] controls its vertical size.
///
/// A value of `1.0` leaves the corresponding axis unchanged. Values greater
/// than `1.0` enlarge the axis, while values between `0.0` and `1.0` reduce
/// it.
///
/// [Scale] is immutable and can be multiplied by a scalar using the `*`
/// operator:
///
/// ```dart
/// const Scale(
///   widthFactor: 2.0,
///   heightFactor: 1.0,
/// ) * 0.5;
/// ```
///
/// This produces a scale with a width factor of `1.0` and a height factor of
/// `0.5`.
@immutable
class Scale {
  final double heightFactor;
  final double widthFactor;

  const Scale({required this.heightFactor, required this.widthFactor});

  Scale operator *(double factor) => Scale(heightFactor: heightFactor * factor, widthFactor: widthFactor * factor);
}
