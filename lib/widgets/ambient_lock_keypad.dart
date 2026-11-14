import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/m3_motion.dart';
import 'm3_spring_button.dart';

/// Material 3 Expressive PIN keypad displayed in Ambient Lock mode.
class AmbientLockKeypad extends StatefulWidget {
  const AmbientLockKeypad({
    super.key,
    required this.accent,
    required this.expectedPin,
    required this.onUnlocked,
    this.onCancel,
    this.isVisible = true,
  });

  final Color accent;
  final String expectedPin;
  final VoidCallback onUnlocked;
  final VoidCallback? onCancel;
  final bool isVisible;

  @override
  State<AmbientLockKeypad> createState() => _AmbientLockKeypadState();
}

class _AmbientLockKeypadState extends State<AmbientLockKeypad>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void didUpdateWidget(covariant AmbientLockKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible && _entered.isNotEmpty) {
      setState(() => _entered = '');
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_entered.length >= 8) return;
    HapticFeedback.lightImpact();
    setState(() => _entered += digit);
  }

  void _onBackspace() {
    if (_entered.isEmpty) {
      widget.onCancel?.call();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
    });
  }

  void _onSubmit() {
    if (_entered == widget.expectedPin) {
      HapticFeedback.mediumImpact();
      setState(() => _entered = '');
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() => _entered = '');
    }
  }

  Widget _buildPinShape(int index) {
    final shapeType = index % 4;
    return TweenAnimationBuilder<double>(
      key: ValueKey('pin-shape-$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: M3Motion.fastSpatial.duration,
      curve: M3Motion.fastSpatial,
      builder: (context, t, child) => Transform.scale(
        scale: t.clamp(0.0, 1.3),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(
            painter: _PinShapePainter(
              shapeType: shapeType,
              color: widget.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitKey(String digit, Color surface, BorderRadius radius) {
    return Expanded(
      child: M3SpringButton(
        onTap: () => _onDigit(digit),
        pressedScale: 0.90,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: GoogleFonts.plusJakartaSans(
              color: widget.accent,
              fontSize: 27,
              fontWeight: FontWeight.w400,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.14),
      const Color(0xFF0A120D),
    );
    final headerSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.16),
      const Color(0xFF0B150F),
    );

    const innerRadius = Radius.circular(10);
    const outerRadius = Radius.circular(18);

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = math.sin(_shakeController.value * math.pi * 4) *
            10.0 *
            (1.0 - _shakeController.value);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 308),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PIN indicator header pill
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: headerSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                  bottom: Radius.circular(10),
                ),
              ),
              alignment: Alignment.center,
              child: _entered.isEmpty
                  ? Text(
                      'Enter PIN',
                      style: GoogleFonts.plusJakartaSans(
                        color: widget.accent.withValues(alpha: 0.45),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _entered.length; i++)
                          _buildPinShape(i),
                      ],
                    ),
            ),
            const SizedBox(height: 4),

            // Row 1: 1 2 3
            Row(
              children: [
                _buildDigitKey(
                  '1',
                  surface,
                  const BorderRadius.only(
                    topLeft: innerRadius,
                    topRight: innerRadius,
                    bottomLeft: innerRadius,
                    bottomRight: innerRadius,
                  ),
                ),
                const SizedBox(width: 4.5),
                _buildDigitKey('2', surface, BorderRadius.all(innerRadius)),
                const SizedBox(width: 4.5),
                _buildDigitKey('3', surface, BorderRadius.all(innerRadius)),
              ],
            ),
            const SizedBox(height: 4.5),

            // Row 2: 4 5 6
            Row(
              children: [
                _buildDigitKey('4', surface, BorderRadius.all(innerRadius)),
                const SizedBox(width: 4.5),
                _buildDigitKey('5', surface, BorderRadius.all(innerRadius)),
                const SizedBox(width: 4.5),
                _buildDigitKey('6', surface, BorderRadius.all(innerRadius)),
              ],
            ),
            const SizedBox(height: 4.5),

            // Row 3: 7 8 9
            Row(
              children: [
                _buildDigitKey(
                  '7',
                  surface,
                  const BorderRadius.only(
                    topLeft: innerRadius,
                    topRight: innerRadius,
                    bottomLeft: outerRadius,
                    bottomRight: innerRadius,
                  ),
                ),
                const SizedBox(width: 4.5),
                _buildDigitKey('8', surface, BorderRadius.all(innerRadius)),
                const SizedBox(width: 4.5),
                _buildDigitKey(
                  '9',
                  surface,
                  const BorderRadius.only(
                    topLeft: innerRadius,
                    topRight: innerRadius,
                    bottomLeft: innerRadius,
                    bottomRight: outerRadius,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.5),

            // Row 4: Backspace, 0, Confirm
            Row(
              children: [
                Expanded(
                  child: M3SpringButton(
                    onTap: _onBackspace,
                    pressedScale: 0.88,
                    child: SizedBox(
                      height: 60,
                      child: Center(
                        child: Icon(
                          Icons.backspace_outlined,
                          color: widget.accent.withValues(alpha: 0.72),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4.5),
                _buildDigitKey(
                  '0',
                  surface,
                  const BorderRadius.only(
                    topLeft: innerRadius,
                    topRight: innerRadius,
                    bottomLeft: outerRadius,
                    bottomRight: outerRadius,
                  ),
                ),
                const SizedBox(width: 4.5),
                Expanded(
                  child: M3SpringButton(
                    onTap: _onSubmit,
                    pressedScale: 0.88,
                    child: SizedBox(
                      height: 60,
                      child: Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: widget.accent,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinShapePainter extends CustomPainter {
  _PinShapePainter({
    required this.shapeType,
    required this.color,
  });

  final int shapeType;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (shapeType) {
      case 0:
        // Circle
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, paint);
      case 1:
        // Rounded square
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84),
            const Radius.circular(4),
          ),
          paint,
        );
      case 2:
        // Triangle
        final path = Path()
          ..moveTo(w * 0.5, h * 0.08)
          ..lineTo(w * 0.94, h * 0.88)
          ..lineTo(w * 0.06, h * 0.88)
          ..close();
        canvas.drawPath(path, paint);
      default:
        // D-shape / arch
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.78, h * 0.84),
            topLeft: const Radius.circular(3),
            bottomLeft: const Radius.circular(3),
            topRight: Radius.circular(w * 0.45),
            bottomRight: Radius.circular(w * 0.45),
          ),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PinShapePainter oldDelegate) =>
      oldDelegate.shapeType != shapeType || oldDelegate.color != color;
}
