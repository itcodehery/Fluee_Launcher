import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Material 3 Expressive motion.
///
/// Spring tokens mirror `ExpressiveMotionTokens` from `androidx.compose.material3`:
///  * fast spatial:    damping ratio 0.6, stiffness 800 (bouncy, small bounds changes)
///  * default spatial: damping ratio 0.8, stiffness 380
///  * default effects: damping ratio 1.0, stiffness 1600 (alpha/color, no overshoot)
///
/// Flutter describes springs with a damping coefficient instead of a ratio:
/// `damping = 2 * ratio * sqrt(mass * stiffness)`.
class M3Motion {
  M3Motion._();

  static const SpringDescription fastSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 800.0,
    damping: 33.94, // 2 * 0.6 * sqrt(800)
  );

  static const SpringDescription defaultSpatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 31.19, // 2 * 0.8 * sqrt(380)
  );

  static const SpringDescription defaultEffectsSpring = SpringDescription(
    mass: 1.0,
    stiffness: 1600.0,
    damping: 80.0, // 2 * 1.0 * sqrt(1600)
  );

  static final SpringCurve fastSpatial = SpringCurve(fastSpatialSpring);
  static final SpringCurve defaultSpatial = SpringCurve(defaultSpatialSpring);
  static final SpringCurve defaultEffects = SpringCurve(defaultEffectsSpring);
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
