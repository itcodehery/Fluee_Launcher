import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive shapes randomly (deterministically) assigned to app icons.
enum AppIconShape {
  circle,
  squircle,
  softSquare,
  cookie,
  clover,
  roundedSquare,
}

/// Deterministically selects a Material shape for an app based on its [appId]
/// using FNV-1a hashing so each app keeps a consistent shape across rebuilds.
AppIconShape appShapeForId(String appId) {
  var hash = 0x811c9dc5;
  for (final unit in appId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return AppIconShape.values[hash % AppIconShape.values.length];
}

/// Returns the [ShapeBorder] for the given [shape] and [tileSize].
ShapeBorder appShapeBorder(AppIconShape shape, double tileSize) {
  switch (shape) {
    case AppIconShape.circle:
      return const CircleBorder();
    case AppIconShape.squircle:
      return ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(tileSize * 0.38),
      );
    case AppIconShape.softSquare:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tileSize * 0.18),
      );
    case AppIconShape.cookie:
      return const WavyCircleBorder(lobes: 10, amplitude: 0.075);
    case AppIconShape.clover:
      return const WavyCircleBorder(
        lobes: 4,
        amplitude: 0.10,
        phaseOffset: math.pi / 4,
      );
    case AppIconShape.roundedSquare:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tileSize * 0.28),
      );
  }
}

/// A smooth sinusoidal scalloped/clover [ShapeBorder] inspired by Material 3 Expressive.
class WavyCircleBorder extends ShapeBorder {
  const WavyCircleBorder({
    this.lobes = 10,
    this.amplitude = 0.075,
    this.phaseOffset = 0.0,
  });

  final int lobes;
  final double amplitude;
  final double phaseOffset;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final maxRadius = math.min(rect.width, rect.height) / 2.0;
    final baseRadius = maxRadius * (1.0 - amplitude);
    final waveAmp = maxRadius * amplitude;

    const steps = 120;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2.0 * math.pi;
      final r = baseRadius + waveAmp * math.cos(lobes * (theta - phaseOffset));
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WavyCircleBorder &&
          other.lobes == lobes &&
          other.amplitude == amplitude &&
          other.phaseOffset == phaseOffset;

  @override
  int get hashCode => Object.hash(lobes, amplitude, phaseOffset);
}
