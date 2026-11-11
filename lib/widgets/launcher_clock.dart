import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'marquee_text.dart';
import 'package:google_fonts/google_fonts.dart';
import 'm3_spring_button.dart';

class LauncherClock extends StatefulWidget {
  const LauncherClock({
    super.key,
    required this.accent,
    required this.onTap,
    required this.onSettingsTap,
    this.onWeatherTap,
    this.onDateTap,
    this.leadingValue,
    this.leadingIcon,
    this.onLeadingTap,
    this.isIdle = false,
    this.mediaTitle,
    this.mediaArtist,
    this.onMediaTap,
    this.customAmbientText,
    this.dashboard,
  });

  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onWeatherTap;
  final VoidCallback? onDateTap;
  final String? leadingValue;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;
  final bool isIdle;
  final String? mediaTitle;
  final String? mediaArtist;
  final VoidCallback? onMediaTap;
  final String? customAmbientText;
  final Widget? dashboard;

  @override
  State<LauncherClock> createState() => _LauncherClockState();
}

class _LauncherClockState extends State<LauncherClock> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    final now = DateTime.now();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleNextTick();
    });
  }

  @override
  void didUpdateWidget(LauncherClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isIdle && _expanded) _expanded = false;
  }

  void _onPillTap() {
    if (widget.dashboard == null) {
      widget.onTap();
      return;
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }


  String _formatTime(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final hour = use24h
        ? _now.hour
        : (_now.hour % 12 == 0 ? 12 : _now.hour % 12);
    final minute = _now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int get _day => _now.day;
  String get _monthName {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[_now.month - 1];
  }

  String get _ambientFullDate {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayOfWeek = days[_now.weekday - 1];
    final month = months[_now.month - 1];
    return '$dayOfWeek, ${_now.day} $month';
  }

  Widget _buildAmbientClockView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(context),
          style: GoogleFonts.plusJakartaSans(
            color: widget.accent,
            fontSize: 58,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _ambientFullDate,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.90),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        if (widget.customAmbientText != null &&
            widget.customAmbientText!.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            widget.customAmbientText!.trim(),
            style: GoogleFonts.plusJakartaSans(
              color: widget.accent.withValues(alpha: 0.90),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Flat dark surface tone with zero borders
    final pillSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.08),
      const Color(0xFF222222),
    );

    final String displayDay;
    final String displayMonth;
    if (widget.leadingValue != null && widget.leadingValue!.contains(' ')) {
      final parts = widget.leadingValue!.split(' ');
      displayDay = parts[0];
      displayMonth = parts[1];
    } else if (widget.leadingValue != null) {
      displayDay = widget.leadingValue!;
      displayMonth = _monthName;
    } else {
      displayDay = '$_day';
      displayMonth = _monthName;
    }

    final hasMedia = widget.mediaTitle != null && widget.mediaTitle!.isNotEmpty;

    final hideSides = widget.isIdle || _expanded;
    final slow = widget.isIdle;
    final sizeDur = Duration(milliseconds: slow ? 1000 : 380);
    final scaleDur = Duration(milliseconds: slow ? 800 : 240);
    final fadeDur = Duration(milliseconds: slow ? 700 : 200);
    final morphDur = Duration(milliseconds: slow ? 1000 : 380);

    return AnimatedSize(
      duration: sizeDur,
      curve: Curves.easeInOutCubic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading Weather Circle Complication (32° with cloud icon & 270° arc gauge, exactly on left as in watch reference)
              AnimatedScale(
                scale: hideSides ? 0.0 : 1.0,
                duration: scaleDur,
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: hideSides ? 0.0 : 1.0,
                  duration: fadeDur,
                  child: hideSides
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: M3SpringButton(
                            onTap: widget.onWeatherTap ?? widget.onTap,
                            pressedScale: 0.88,
                            child: WeatherCircleComplication(
                              accent: widget.accent,
                              surface: pillSurface,
                              border: const Color(0xFF333333),
                              temperature: '32',
                              icon: Icons.wb_cloudy_rounded,
                            ),
                          ),
                        ),
                ),
              ),

              // Center clock pill; expands in place into the dashboard card
              M3SpringButton(
                onTap: _onPillTap,
                pressedScale: _expanded ? 0.99 : 0.94,
                child: AnimatedContainer(
                  duration: _expanded
                      ? const Duration(milliseconds: 480)
                      : morphDur,
                  curve: Curves.easeInOutCubicEmphasized,
                  padding: EdgeInsets.symmetric(
                    horizontal: _expanded ? 20 : (widget.isIdle ? 20 : 22),
                    vertical: _expanded ? 14 : (widget.isIdle ? 0 : 10),
                  ),
                  decoration: BoxDecoration(
                    color: widget.isIdle ? Colors.transparent : pillSurface,
                    borderRadius: BorderRadius.circular(
                      _expanded ? 36 : (widget.isIdle ? 24 : 30),
                    ),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 480),
                    curve: Curves.easeInOutCubicEmphasized,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_expanded && widget.isIdle)
                          _buildAmbientClockView()
                        else
                          AnimatedDefaultTextStyle(
                            duration: morphDur,
                            curve: Curves.easeInOutCubic,
                            style: GoogleFonts.plusJakartaSans(
                              color: widget.accent,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              height: 1.0,
                            ),
                            child: Text(_formatTime(context)),
                          ),
                        if (_expanded && widget.dashboard != null)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOut,
                            builder: (context, t, child) =>
                                Opacity(opacity: t, child: child),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: widget.dashboard!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Trailing Date Circle Complication (Day & Month stacked, exactly on right as in watch reference)
              AnimatedScale(
                scale: hideSides ? 0.0 : 1.0,
                duration: scaleDur,
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: hideSides ? 0.0 : 1.0,
                  duration: fadeDur,
                  child: hideSides
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: M3SpringButton(
                            onTap: widget.onDateTap ??
                                widget.onLeadingTap ??
                                widget.onSettingsTap,
                            pressedScale: 0.88,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: pillSurface,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    displayDay,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: widget.accent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      height: 1.05,
                                    ),
                                  ),
                                  Text(
                                    displayMonth,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.1,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Now Playing Pill below the clock
          if (hasMedia && !widget.isIdle) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: widget.isIdle ? 0.0 : 1.0,
              child: M3SpringButton(
                onTap: widget.onMediaTap ?? () {},
                pressedScale: 0.94,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: pillSurface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        color: widget.accent,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: MarqueeText(
                          text: widget.mediaArtist != null &&
                                  widget.mediaArtist!.isNotEmpty
                              ? '${widget.mediaTitle} • ${widget.mediaArtist}'
                              : widget.mediaTitle!,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular complication matching the Pixel Watch gauge complication with a 290° arc.
class CircleComplication extends StatelessWidget {
  const CircleComplication({
    super.key,
    required this.accent,
    required this.surface,
    required this.border,
    required this.value,
    required this.icon,
    this.progress = 0.72,
    this.size = 52.0,
  });

  final Color accent;
  final Color surface;
  final Color border;
  final String value;
  final IconData icon;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
          ),
          // Circular Arc Gauge Painter with tip pip
          Positioned.fill(
            child: CustomPaint(
              painter: _WeatherArcPainter(
                accent: accent,
                trackColor: border,
                progress: progress,
              ),
            ),
          ),
          // Inner Value and Icon
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Icon(icon, color: accent, size: 13),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular complication matching the Pixel Watch weather dial with a 270° arc gauge.
class WeatherCircleComplication extends StatelessWidget {
  const WeatherCircleComplication({
    super.key,
    required this.accent,
    required this.surface,
    required this.border,
    this.temperature = '32',
    this.icon = Icons.wb_cloudy_rounded,
    this.size = 52.0,
  });

  final Color accent;
  final Color surface;
  final Color border;
  final String temperature;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleComplication(
      accent: accent,
      surface: surface,
      border: border,
      value: temperature,
      icon: icon,
      progress: 0.72,
      size: size,
    );
  }
}

class _WeatherArcPainter extends CustomPainter {
  _WeatherArcPainter({
    required this.accent,
    required this.trackColor,
    required this.progress,
  });

  final Color accent;
  final Color trackColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 3.2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2 - 2.5;

    // The arc starts from ~125° and sweeps 290° clockwise, leaving a bottom gap for the icon
    final startAngle = 125 * math.pi / 180;
    final totalSweep = 290 * math.pi / 180;

    // Track arc
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Active progress arc
    final sweep = totalSweep * progress.clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      progressPaint,
    );

    // End indicator pip at the tip of the active arc
    final tipAngle = startAngle + sweep;
    final pipCenter = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );

    final pipPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pipCenter, strokeWidth * 0.9, pipPaint);
  }

  @override
  bool shouldRepaint(covariant _WeatherArcPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progress != progress;
}
