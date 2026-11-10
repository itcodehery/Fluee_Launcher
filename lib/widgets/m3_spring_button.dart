import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Interactive button wrapper with Material 3 standard spring physics.
/// Applies an expressive scale down + spring rebound bounce on release.
class M3SpringButton extends StatefulWidget {
  const M3SpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.hapticOnPress = true,
    this.pressedScale = 0.92,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool hapticOnPress;
  final double pressedScale;

  @override
  State<M3SpringButton> createState() => _M3SpringButtonState();
}

class _M3SpringButtonState extends State<M3SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Material 3 Spring specification:
  // Damping ratio ~0.7-0.8 (snappy, subtle bounce without excessive oscillation)
  static const _springDesc = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 24.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _scaleAnimation = _controller.drive(
      Tween<double>(begin: 1.0, end: widget.pressedScale),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.hapticOnPress) {
      HapticFeedback.selectionClick();
    }
    // Animate quickly to pressed state
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  void _onTapUp(TapUpDetails details) {
    _runSpringRebound();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _runSpringRebound();
  }

  void _onLongPress() {
    _runSpringRebound();
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  void _runSpringRebound() {
    final simulation = SpringSimulation(
      _springDesc,
      _controller.value,
      0.0,
      -_controller.velocity,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress != null ? _onLongPress : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
