import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Material 3 Expressive motion system.
///
/// Follows the M3 Motion spring physics specification
/// (https://m3.material.io/styles/motion/overview/how-it-works):
/// - **Spatial** springs animate position, size, scale, and bounds (with controlled overshoot).
/// - **Effects** springs animate opacity, color, and elevation (critically damped, ratio 1.0).
/// - **Expressive** tokens are used for hero moments (dashboard, ambient lock, dock focus);
///   **Standard** tokens are used for subtle utilitarian transitions.
///
/// Flutter describes springs with a damping coefficient instead of a ratio:
/// `damping = 2 * ratio * sqrt(mass * stiffness)`.
class M3Motion {
  M3Motion._();

  // --- Expressive Spatial Springs ---
  static const SpringDescription fastSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 800.0,
    damping: 33.94, // 2 * 0.6 * sqrt(800)
  );

  static const SpringDescription defaultSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 260.0,
    damping: 25.80, // 2 * 0.8 * sqrt(260)
  );

  static const SpringDescription slowSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 150.0,
    damping: 19.60, // 2 * 0.8 * sqrt(150)
  );

  // --- Effects Springs (critically damped, no overshoot) ---
  static const SpringDescription fastEffectsSpring = SpringDescription(
    mass: 1.0,
    stiffness: 3800.0,
    damping: 123.29, // 2 * 1.0 * sqrt(3800)
  );

  static const SpringDescription defaultEffectsSpring = SpringDescription(
    mass: 1.0,
    stiffness: 900.0,
    damping: 60.0, // 2 * 1.0 * sqrt(900)
  );

  static const SpringDescription slowEffectsSpring = SpringDescription(
    mass: 1.0,
    stiffness: 450.0,
    damping: 42.43, // 2 * 1.0 * sqrt(450)
  );

  // --- Standard Spatial Springs ---
  static const SpringDescription standardFastSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 1400.0,
    damping: 67.35, // 2 * 0.9 * sqrt(1400)
  );

  static const SpringDescription standardDefaultSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 700.0,
    damping: 47.62, // 2 * 0.9 * sqrt(700)
  );

  static const SpringDescription standardSlowSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 31.18, // 2 * 0.9 * sqrt(300)
  );

  static final SpringCurve fastSpatial = SpringCurve(fastSpatialSpring);
  static final SpringCurve defaultSpatial = SpringCurve(defaultSpatialSpring);
  static final SpringCurve slowSpatial = SpringCurve(slowSpatialSpring);

  static final SpringCurve fastEffects = SpringCurve(fastEffectsSpring);
  static final SpringCurve defaultEffects = SpringCurve(defaultEffectsSpring);
  static final SpringCurve slowEffects = SpringCurve(slowEffectsSpring);

  static final SpringCurve standardFastSpatial =
      SpringCurve(standardFastSpatialSpring);
  static final SpringCurve standardDefaultSpatial =
      SpringCurve(standardDefaultSpatialSpring);
  static final SpringCurve standardSlowSpatial =
      SpringCurve(standardSlowSpatialSpring);
}

/// A [Curve] sampled from a real spring simulation, so implicit animations
/// (which only accept a duration + curve) move with Material 3 spring physics.
///
/// The curve is normalized to the spring's settle time; [duration] is that
/// settle time. Values can exceed 1.0 mid-flight for under-damped springs,
/// producing the characteristic M3 overshoot.
class SpringCurve extends Curve {
  SpringCurve(this.spring) {
    final simulation = SpringSimulation(spring, 0, 1, 0);
    var settle = 0.0;
    const step = 1 / 240;
    while (settle < 5.0) {
      settle += step;
      final x = simulation.x(settle);
      if ((x - 1.0).abs() < 0.0005 && simulation.dx(settle).abs() < 0.005) {
        break;
      }
    }
    _settle = settle;
    _samples = List<double>.generate(_sampleCount, (i) {
      if (i == 0) return 0.0;
      if (i == _sampleCount - 1) return 1.0;
      return simulation.x(_settle * i / (_sampleCount - 1));
    });
  }

  static const int _sampleCount = 240;

  final SpringDescription spring;

  late final double _settle;
  late final List<double> _samples;

  /// Time the spring takes to come to rest.
  Duration get duration => Duration(microseconds: (_settle * 1e6).round());

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final position = t * (_sampleCount - 1);
    final index = position.floor();
    final fraction = position - index;
    final a = _samples[index];
    final b = _samples[math.min(index + 1, _sampleCount - 1)];
    return a + (b - a) * fraction;
  }
}
