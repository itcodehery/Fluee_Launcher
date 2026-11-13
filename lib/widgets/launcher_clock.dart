import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'marquee_text.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/m3_motion.dart';
import 'm3_spring_button.dart';

/// Controls the [LauncherClock] expansion state from outside the clock widget,
/// e.g. so the dashboard's own collapse button can close the card.
class LauncherClockController {
  _LauncherClockState? _state;

  bool get isExpanded => _state?._expanded ?? false;

  void collapse() => _state?._collapse();

  void toggle() => _state?._onPillTap();
}

class LauncherClock extends StatefulWidget {
  const LauncherClock({
    super.key,
    required this.accent,
    required this.onTap,
    required this.onSettingsTap,
    this.onWeatherTap,
    this.onBatteryTap,
    this.onDateTap,
    this.batteryLevel,
    this.isCharging = false,
    this.leadingValue,
    this.leadingIcon,
    this.onLeadingTap,
    this.isIdle = false,
    this.mediaTitle,
    this.mediaArtist,
    this.mediaIsPlaying = true,
    this.onMediaTap,
    this.customAmbientText,
    this.dashboard,
    this.controller,
  });

  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onWeatherTap;
  final VoidCallback? onBatteryTap;
  final VoidCallback? onDateTap;
  final int? batteryLevel;
  final bool isCharging;
  final String? leadingValue;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;
  final bool isIdle;
  final String? mediaTitle;
  final String? mediaArtist;
  final bool mediaIsPlaying;
  final VoidCallback? onMediaTap;
  final String? customAmbientText;
  final Widget? dashboard;
  final LauncherClockController? controller;

  @override
  State<LauncherClock> createState() => _LauncherClockState();
}

class _LauncherClockState extends State<LauncherClock> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  Timer? _morphTimer;
  bool _expanded = false;

  /// While collapsing, the dashboard stays mounted as an overlay so it can fade/scale
  /// out on top of the spring-shrinking card instead of vanishing instantly.
  Widget? _outgoingDashboard;
  bool _collapsing = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
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
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this)
        oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (widget.isIdle && _expanded) {
      _expanded = false;
      _collapsing = false;
      _outgoingDashboard = null;
      _morphTimer?.cancel();
    }
  }

  void _onPillTap() {
    if (widget.dashboard == null) {
      widget.onTap();
      return;
    }
    _setExpanded(!_expanded);
  }

  void _setExpanded(bool value) {
    if (!mounted || value == _expanded) return;
    _morphTimer?.cancel();
    if (value) {
      setState(() {
        _expanded = true;
        _collapsing = false;
        _outgoingDashboard = null;
      });
      return;
    }

    final outgoing = widget.dashboard;
    setState(() {
      _expanded = false;
      _collapsing = true;
      _outgoingDashboard = outgoing;
    });
    _morphTimer = Timer(
      M3Motion.fastSpatial.duration + const Duration(milliseconds: 40),
      () {
        if (!mounted || _expanded) return;
        setState(() {
          _collapsing = false;
          _outgoingDashboard = null;
        });
      },
    );
  }

  void _collapse() => _setExpanded(false);

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _timer?.cancel();
    _morphTimer?.cancel();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[_now.month - 1];
  }

  String get _ambientFullDate {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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

    final idle = widget.isIdle;
    final hideSides = idle || _expanded;
    // Material 3 Expressive springs: the bouncy "fast spatial" spring (damping 0.6,
    // stiffness 800) opens the card, while the gentler "default spatial" spring
    // (damping 0.8, stiffness 380) closes it so a 54px pill does not squash past itself.
    final springCurve = idle
        ? Curves.easeInOutCubic
        : (_expanded ? M3Motion.fastSpatial : M3Motion.defaultSpatial);
    final sizeDur = idle
        ? const Duration(milliseconds: 900)
        : (_expanded
              ? M3Motion.fastSpatial.duration
              : M3Motion.defaultSpatial.duration);
    final scaleDur = idle ? const Duration(milliseconds: 800) : sizeDur;
    final fadeDur = idle
        ? const Duration(milliseconds: 700)
        : const Duration(milliseconds: 180);
    final morphDur = sizeDur;

    // Leading battery complication (hidden entirely once the card is expanded so the card
    // always fits the screen instead of overflowing).
    final leadingSide = AnimatedScale(
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
                  onTap:
                      widget.onBatteryTap ??
                      widget.onWeatherTap ??
                      widget.onTap,
                  pressedScale: 0.88,
                  child: BatteryCircleComplication(
                    accent: widget.accent,
                    surface: pillSurface,
                    border: const Color(0xFF333333),
                    level: widget.batteryLevel,
                    isCharging: widget.isCharging,
                  ),
                ),
              ),
      ),
    );

    // Trailing date complication.
    final trailingSide = AnimatedScale(
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
                  onTap:
                      widget.onDateTap ??
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
    );

    return AnimatedSize(
      duration: sizeDur,
      curve: springCurve,
      alignment: Alignment.topCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;

          final dashboardMaxWidth = math.max(160.0, maxWidth - 40);

          final Widget collapsedContent = idle
              ? _buildAmbientClockView()
              : AnimatedDefaultTextStyle(
                  duration: morphDur,
                  curve: springCurve,
                  style: GoogleFonts.plusJakartaSans(
                    color: widget.accent,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.0,
                  ),
                  child: Text(_formatTime(context)),
                );

          // When expanded the clock/time is removed entirely: the card shows only the
          // dashboard, and the chevron inside it is the sole way to collapse it.
          final Widget sizingContent = _expanded
              ? ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dashboardMaxWidth),
                  child: widget.dashboard == null
                      ? const SizedBox.shrink()
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) {
                            final v = t.clamp(0.0, 1.0);
                            return Opacity(
                              opacity: v,
                              child: Transform.scale(
                                scale: 0.96 + 0.04 * v,
                                alignment: Alignment.topCenter,
                                child: child,
                              ),
                            );
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                            child: widget.dashboard!,
                          ),
                        ),
                )
              // The clock keeps its small size while collapsing so the spring has somewhere
              // to land; it fades in once the outgoing card has finished animating away.
              : AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _collapsing ? 0.0 : 1.0,
                  child: collapsedContent,
                );

          Widget cardContent = sizingContent;

          // Collapse keeps the dashboard mounted as an overlay that fades/scales out while
          // the card springs shut, instead of being removed in a single frame.
          final outgoing = _outgoingDashboard;
          if (outgoing != null && !_expanded) {
            cardContent = Stack(
              clipBehavior: Clip.none,
              children: [
                sizingContent,
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: 0),
                      duration: M3Motion.fastSpatial.duration,
                      curve: M3Motion.fastSpatial,
                      builder: (context, t, child) {
                        final v = t.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: v,
                          child: Transform.scale(
                            scale: 0.94 + 0.06 * v,
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        );
                      },
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minWidth: 0,
                        maxWidth: dashboardMaxWidth,
                        minHeight: 0,
                        maxHeight: 640,
                        child: SizedBox(
                          width: dashboardMaxWidth,
                          child: outgoing,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          Widget clockCard = AnimatedContainer(
            duration: morphDur,
            curve: springCurve,
            padding: EdgeInsets.symmetric(
              horizontal: _expanded ? 20 : (idle ? 20 : 22),
              vertical: _expanded ? 14 : (idle ? 0 : 10),
            ),
            decoration: BoxDecoration(
              color: idle ? Colors.transparent : pillSurface,
              borderRadius: BorderRadius.circular(
                _expanded ? 36 : (idle ? 24 : 30),
              ),
            ),
            child: cardContent,
          );

          // Only the collapsed clock reacts to taps (to expand). Once expanded, the whole
          // body is inert and only the dashboard's chevron collapses the card.
          if (!_expanded) {
            clockCard = M3SpringButton(
              onTap: widget.dashboard == null ? widget.onTap : _onPillTap,
              pressedScale: 0.94,
              child: clockCard,
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!_expanded) leadingSide,
                  Flexible(child: clockCard),
                  if (!_expanded) trailingSide,
                ],
              ),

              // Now Playing Pill below the clock (hidden while the card is expanded)
              if (hasMedia && !idle && !_expanded) ...[
                const SizedBox(height: 10),
                M3SpringButton(
                  onTap: widget.onMediaTap ?? () {},
                  pressedScale: 0.94,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: pillSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.mediaIsPlaying
                              ? Icons.music_note_rounded
                              : Icons.pause_rounded,
                          color: widget.accent,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: MarqueeText(
                            text:
                                widget.mediaArtist != null &&
                                    widget.mediaArtist!.isNotEmpty
                                ? '${widget.mediaTitle} • ${widget.mediaArtist}'
                                : widget.mediaTitle!,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(
                                alpha: widget.mediaIsPlaying ? 1.0 : 0.62,
                              ),
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
              ],
            ],
          );
        },
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
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1.5),
              Icon(icon, color: accent, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular complication matching the Pixel Watch battery dial with a 290° arc gauge.
class BatteryCircleComplication extends StatelessWidget {
  const BatteryCircleComplication({
    super.key,
    required this.accent,
    required this.surface,
    required this.border,
    this.level,
    this.isCharging = false,
    this.size = 52.0,
  });

  final Color accent;
  final Color surface;
  final Color border;
  final int? level;
  final bool isCharging;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = level?.clamp(0, 100);
    return CircleComplication(
      accent: accent,
      surface: surface,
      border: border,
      value: clamped != null ? '$clamped%' : '--%',
      icon: isCharging
          ? Icons.battery_charging_full_rounded
          : Icons.battery_full_rounded,
      progress: clamped != null ? clamped / 100.0 : 0.0,
      size: size,
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
