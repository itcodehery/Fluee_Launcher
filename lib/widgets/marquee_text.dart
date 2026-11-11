import 'package:flutter/material.dart';

/// Single-line text that scrolls horizontally in a loop when it does not fit.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 32.0,
    this.velocity = 28.0,
    this.pause = const Duration(seconds: 1),
  });

  final String text;
  final TextStyle style;
  final double gap;
  final double velocity; // logical px per second
  final Duration pause;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  double _cycle = 0;
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loop() async {
    if (_running) return;
    _running = true;
    while (mounted && _cycle > 0) {
      await Future<void>.delayed(widget.pause);
      if (!mounted || _cycle <= 0) break;
      final ms = (_cycle / widget.velocity * 1000).round();
      _controller.duration = Duration(milliseconds: ms);
      await _controller.forward(from: 0).orCancel.catchError((_) {});
    }
    _running = false;
  }

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _controller.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final textW = painter.width;
      final maxW = constraints.maxWidth;
      final height = painter.height;

      if (textW <= maxW) {
        _cycle = 0;
        return SizedBox(
          height: height,
          child: Text(widget.text, maxLines: 1, style: widget.style),
        );
      }

      _cycle = textW + widget.gap;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loop();
      });

      return SizedBox(
        height: height,
        width: maxW,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-_controller.value * _cycle, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.text,
                          maxLines: 1, softWrap: false, style: widget.style),
                      SizedBox(width: widget.gap),
                      Text(widget.text,
                          maxLines: 1, softWrap: false, style: widget.style),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
