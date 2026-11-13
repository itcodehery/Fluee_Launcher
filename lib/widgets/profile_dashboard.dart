import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/launcher_platform.dart';
import 'm3_spring_button.dart';

/// Content shown inside the expanded clock card: collapse pill, greeting + avatar,
/// battery + split time tiles, expressive brightness/volume sliders, and 3 quick actions.
class ProfileDashboard extends StatefulWidget {
  const ProfileDashboard({
    super.key,
    required this.accent,
    required this.platform,
    this.name,
    this.photo,
    this.batteryLevel,
    this.isCharging = false,
    this.onSettingsTap,
    this.onCollapse,
  });

  final Color accent;
  final LauncherPlatform platform;
  final String? name;
  final Uint8List? photo;
  final int? batteryLevel;
  final bool isCharging;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCollapse;

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard>
    with WidgetsBindingObserver {
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _needsWritePermission = false;
  int? _batteryLevel;
  bool _isCharging = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _batteryLevel = widget.batteryLevel;
    _isCharging = widget.isCharging;
    WidgetsBinding.instance.addObserver(this);
    _load();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.minute != _now.minute || now.hour != _now.hour) {
        setState(() => _now = now);
      }
    });
  }

  @override
  void didUpdateWidget(ProfileDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.batteryLevel != oldWidget.batteryLevel &&
        widget.batteryLevel != null) {
      _batteryLevel = widget.batteryLevel;
    }
    if (widget.isCharging != oldWidget.isCharging) {
      _isCharging = widget.isCharging;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final b = await widget.platform.getBrightness();
    final v = await widget.platform.getVolume();
    final bat = await widget.platform.getBattery();
    if (!mounted) return;
    setState(() {
      if (b != null) _brightness = b;
      if (v != null) _volume = v;
      if (bat != null) {
        _batteryLevel = bat.level;
        _isCharging = bat.charging;
      }
      _needsWritePermission = false;
      _now = DateTime.now();
    });
  }

  Future<void> _onBrightness(double value) async {
    setState(() => _brightness = value);
    final ok = await widget.platform.setBrightness(value);
    if (!ok && !_needsWritePermission && mounted) {
      setState(() => _needsWritePermission = true);
    }
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _formattedHour(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final hour = use24h
        ? _now.hour
        : (_now.hour % 12 == 0 ? 12 : _now.hour % 12);
    return hour.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final hasName = widget.name != null && widget.name!.trim().isNotEmpty;
    final greetingName = hasName ? widget.name!.trim() : 'there';

    final pillTint = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.22),
      const Color(0xFF102018),
    );
    final subSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.14),
      const Color(0xFF0E1B15),
    );
    final batteryFillColor = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.26),
      const Color(0xFF12261D),
    );
    final actionSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.20),
      const Color(0xFF10221A),
    );

    final batteryPct = _batteryLevel?.clamp(0, 100);
    final batteryProgress = batteryPct != null ? batteryPct / 100.0 : 0.0;
    final hourStr = _formattedHour(context);
    final minStr = _now.minute.toString().padLeft(2, '0');

    return SizedBox(
      width: 296,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Collapse Pill Button
          Center(
            child: M3SpringButton(
              onTap: widget.onCollapse ?? () {},
              pressedScale: 0.90,
              child: Container(
                width: 48,
                height: 22,
                decoration: BoxDecoration(
                  color: pillTint,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: widget.accent,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Greeting + Avatar Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hey $greetingName,',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _greeting(_now.hour),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: widget.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 28,
                backgroundColor: pillTint,
                backgroundImage:
                    widget.photo != null ? MemoryImage(widget.photo!) : null,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Battery Pill + Hour Circle + Minute Rounded Square
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: subSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        final fillW = (maxW * batteryProgress)
                            .clamp(38.0, maxW);
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: fillW,
                              height: 52,
                              decoration: BoxDecoration(
                                color: batteryFillColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    _isCharging
                                        ? Icons.battery_charging_full_rounded
                                        : Icons.battery_std_rounded,
                                    color: widget.accent,
                                    size: 18,
                                  ),
                                  Text(
                                    batteryPct != null ? '$batteryPct%' : '--%',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: widget.accent,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: subSurface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hourStr,
                    style: GoogleFonts.plusJakartaSans(
                      color: widget.accent,
                      fontSize: 25,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: subSurface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    minStr,
                    style: GoogleFonts.plusJakartaSans(
                      color: widget.accent,
                      fontSize: 25,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Expressive Brightness & Volume Sliders
          _ExpressiveSlider(
            accent: widget.accent,
            icon: Icons.wb_sunny_outlined,
            value: _brightness,
            onChanged: _onBrightness,
          ),
          if (_needsWritePermission)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.platform.openWriteSettings,
                child: Text(
                  'Allow brightness control',
                  style: TextStyle(color: widget.accent, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 10),
          _ExpressiveSlider(
            accent: widget.accent,
            icon: _volume == 0
                ? Icons.volume_off_outlined
                : Icons.volume_up_outlined,
            value: _volume,
            onChanged: (v) {
              setState(() => _volume = v);
              widget.platform.setVolume(v);
            },
          ),
          const SizedBox(height: 18),

          // Bottom 3 Action Buttons: Power Menu, Settings, Notifications
          Row(
            children: [
              _DashboardActionButton(
                icon: Icons.power_settings_new_rounded,
                accent: widget.accent,
                background: actionSurface,
                tooltip: 'Power menu',
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final ok = await widget.platform.showPowerMenu();
                  if (!ok) await widget.platform.openAccessibilitySettings();
                },
              ),
              const SizedBox(width: 8),
              _DashboardActionButton(
                icon: Icons.settings_outlined,
                accent: widget.accent,
                background: actionSurface,
                tooltip: 'Settings',
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onCollapse?.call();
                  widget.onSettingsTap?.call();
                },
              ),
              const SizedBox(width: 8),
              _DashboardActionButton(
                icon: Icons.notifications_outlined,
                accent: widget.accent,
                background: actionSurface,
                tooltip: 'Notifications',
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final ok = await widget.platform.openNotifications();
                  if (!ok) await widget.platform.openAccessibilitySettings();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  const _DashboardActionButton({
    required this.icon,
    required this.accent,
    required this.background,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color background;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: M3SpringButton(
          onTap: onTap,
          pressedScale: 0.92,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Material 3 Expressive slider with rounded track segments and a vertical pill thumb.
class _ExpressiveSlider extends StatelessWidget {
  const _ExpressiveSlider({
    required this.accent,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final Color accent;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  void _updateFromLocalDx(double dx, double width) {
    if (width <= 0) return;
    onChanged((dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _updateFromLocalDx(d.localPosition.dx, width),
                onHorizontalDragUpdate: (d) =>
                    _updateFromLocalDx(d.localPosition.dx, width),
                child: SizedBox(
                  height: 28,
                  width: width,
                  child: CustomPaint(
                    painter: _ExpressiveSliderPainter(
                      value: clamped,
                      accent: accent,
                      inactiveColor: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExpressiveSliderPainter extends CustomPainter {
  _ExpressiveSliderPainter({
    required this.value,
    required this.accent,
    required this.inactiveColor,
  });

  final double value;
  final Color accent;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 8.0;
    const thumbWidth = 5.0;
    const thumbHeight = 24.0;
    const gap = 5.0;

    final cy = size.height / 2;
    final thumbCenterX =
        (thumbWidth / 2) + value * (size.width - thumbWidth).clamp(0.0, size.width);

    // Active track (left of thumb)
    final activeEnd = thumbCenterX - thumbWidth / 2 - gap;
    if (activeEnd > 2.0) {
      final activeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - trackHeight / 2, activeEnd, trackHeight),
        const Radius.circular(trackHeight / 2),
      );
      canvas.drawRRect(activeRect, Paint()..color = accent);
    }

    // Inactive track (right of thumb)
    final inactiveStart = thumbCenterX + thumbWidth / 2 + gap;
    if (inactiveStart < size.width - 2.0) {
      final inactiveRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inactiveStart,
          cy - trackHeight / 2,
          size.width - inactiveStart,
          trackHeight,
        ),
        const Radius.circular(trackHeight / 2),
      );
      canvas.drawRRect(inactiveRect, Paint()..color = inactiveColor);
    }

    // Vertical pill thumb
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(thumbCenterX, cy),
        width: thumbWidth,
        height: thumbHeight,
      ),
      const Radius.circular(thumbWidth / 2),
    );
    canvas.drawRRect(thumbRect, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _ExpressiveSliderPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.accent != accent ||
      oldDelegate.inactiveColor != inactiveColor;
}
