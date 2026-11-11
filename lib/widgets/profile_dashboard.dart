import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/launcher_platform.dart';
import '../theme/launcher_colors.dart';
import 'm3_spring_button.dart';

/// Content shown inside the expanded clock pill: profile + brightness & volume.
class ProfileDashboard extends StatefulWidget {
  const ProfileDashboard({
    super.key,
    required this.accent,
    required this.platform,
    this.name,
    this.photo,
  });

  final Color accent;
  final LauncherPlatform platform;
  final String? name;
  final Uint8List? photo;

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard>
    with WidgetsBindingObserver {
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _needsWritePermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final b = await widget.platform.getBrightness();
    final v = await widget.platform.getVolume();
    if (!mounted) return;
    setState(() {
      if (b != null) _brightness = b;
      if (v != null) _volume = v;
      _needsWritePermission = false;
    });
  }

  Future<void> _onBrightness(double value) async {
    setState(() => _brightness = value);
    final ok = await widget.platform.setBrightness(value);
    if (!ok && !_needsWritePermission && mounted) {
      setState(() => _needsWritePermission = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasName = widget.name != null && widget.name!.trim().isNotEmpty;
    return SizedBox(
      width: 264,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Center(child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.accent, width: 2.5),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF333333),
              backgroundImage:
                  widget.photo != null ? MemoryImage(widget.photo!) : null,
              child: widget.photo == null
                  ? Icon(Icons.person_rounded, color: widget.accent, size: 30)
                  : null,
            ),
          )),
          const SizedBox(height: 10),
          Text(
            hasName ? widget.name!.trim() : 'Add your name in settings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasName ? Colors.white : Colors.white54,
              fontSize: hasName ? 17 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          _PillSlider(
            accent: widget.accent,
            icon: Icons.brightness_6_rounded,
            value: _brightness,
            onChanged: _onBrightness,
          ),
          if (_needsWritePermission)
            TextButton(
              onPressed: widget.platform.openWriteSettings,
              child: Text('Allow brightness control',
                  style: TextStyle(color: widget.accent, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          _PillSlider(
            accent: widget.accent,
            icon: _volume == 0
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            value: _volume,
            onChanged: (v) {
              setState(() => _volume = v);
              widget.platform.setVolume(v);
            },
          ),
          const SizedBox(height: 14),
          _PowerButton(
            accent: widget.accent,
            onTap: () async {
              HapticFeedback.mediumImpact();
              final ok = await widget.platform.showPowerMenu();
              if (!ok) await widget.platform.openAccessibilitySettings();
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return M3SpringButton(
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        height: 46,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new_rounded, color: accent, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Power menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chunky Material 3 Expressive style slider: a tall pill filled with accent.
class _PillSlider extends StatefulWidget {
  const _PillSlider({
    required this.accent,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final Color accent;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_PillSlider> createState() => _PillSliderState();
}

class _PillSliderState extends State<_PillSlider> {
  bool _dragging = false;
  int _lastStep = -1;

  void _update(Offset local, double width) {
    final v = (local.dx / width).clamp(0.0, 1.0);
    final step = (v * 10).round();
    if (step != _lastStep) {
      _lastStep = step;
      HapticFeedback.selectionClick();
    }
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final onAccent = LauncherColors.readableOn(widget.accent);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      const handleW = 6.0;
      const gap = 5.0;
      final v = widget.value.clamp(0.0, 1.0);
      final handleX = (w * v).clamp(handleW / 2 + gap, w - handleW / 2 - gap);
      final activeW = (handleX - handleW / 2 - gap).clamp(0.0, w);
      final inactiveX = handleX + handleW / 2 + gap;
      final h = _dragging ? 56.0 : 50.0;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          setState(() => _dragging = true);
          _update(d.localPosition, w);
        },
        onTapUp: (_) => setState(() => _dragging = false),
        onTapCancel: () => setState(() => _dragging = false),
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => _update(d.localPosition, w),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: w,
          height: h,
          child: Stack(
            children: [
              // Active segment
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: activeW,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(26),
                      right: Radius.circular(6),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16),
                  child: activeW > 44
                      ? Icon(widget.icon, size: 22, color: onAccent)
                      : null,
                ),
              ),
              // Inactive segment
              Positioned(
                left: inactiveX,
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                      right: Radius.circular(26),
                    ),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: (w - inactiveX) > 44
                      ? Icon(widget.icon, size: 22, color: Colors.white54)
                      : null,
                ),
              ),
              // Handle
              Positioned(
                left: handleX - handleW / 2,
                top: 0,
                bottom: 0,
                width: handleW,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: _dragging ? 44 : 36,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
