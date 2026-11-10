import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/launcher_platform.dart';
import '../theme/launcher_colors.dart';
import 'm3_spring_button.dart';

/// Inline Quick Settings panel matching the Pixel Watch reference layout.
/// Features zero borders, top mini buttons morphing into full squircles,
/// 6 primary options, conditional Bluetooth status, and drag handle.
class QuickSettingsPanel extends StatefulWidget {
  const QuickSettingsPanel({
    super.key,
    required this.accent,
    required this.platform,
    required this.onClose,
  });

  final Color accent;
  final LauncherPlatform platform;
  final VoidCallback onClose;

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morphController;

  // Toggles for Quick Settings options
  bool _isTorchOn = false;
  bool _isDndOn = false;
  bool _isAutoBrightnessOn = true;
  bool _isNightLightOn = false;
  bool _isAirplaneOn = true; // Active in reference image
  bool _isWifiOn = false;
  bool _isAutoRotateOn = true; // Active in reference image
  bool _isBluetoothConnected = false;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _checkBluetooth();
  }

  Future<void> _checkBluetooth() async {
    final connected = await widget.platform.isBluetoothConnected();
    if (mounted) {
      setState(() => _isBluetoothConnected = connected);
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  void _toggleMorph() {
    HapticFeedback.lightImpact();
    if (_morphController.isCompleted) {
      _morphController.reverse();
    } else {
      _morphController.forward();
    }
  }

  Future<void> _toggleTorch() async {
    HapticFeedback.mediumImpact();
    final res = await widget.platform.toggleFlashlight();
    if (mounted) setState(() => _isTorchOn = res);
  }

  @override
  Widget build(BuildContext context) {
    final activeBg = widget.accent;
    final activeFg = LauncherColors.readableOn(widget.accent);
    const inactiveBg = Color(0xFF333333);
    const inactiveFg = Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        // Dragging down morphs top buttons larger, dragging up returns or closes
        if (details.delta.dy > 2) {
          if (!_morphController.isAnimating && _morphController.value < 1.0) {
            _morphController.forward();
          }
        } else if (details.delta.dy < -4) {
          if (_morphController.value > 0.0) {
            _morphController.reverse();
          } else {
            widget.onClose();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _morphController,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_morphController.value);

          // Interpolated dimensions
          // Small circle: 38x38, radius 19
          // Large squircle: 76x54, radius 22
          final topWidth = 38.0 + (76.0 - 38.0) * t;
          final topHeight = 38.0 + (54.0 - 38.0) * t;
          final topRadius = 19.0 + (22.0 - 19.0) * t;
          final topIconSize = 18.0 + (24.0 - 18.0) * t;

          final btmWidth = 76.0 - (76.0 - 38.0) * t;
          final btmHeight = 54.0 - (54.0 - 38.0) * t;
          final btmRadius = 22.0 - (22.0 - 19.0) * t;
          final btmIconSize = 24.0 - (24.0 - 18.0) * t;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row A: Flashlight, DnD, Auto-brightness (grows on pull)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MorphButton(
                    width: topWidth,
                    height: topHeight,
                    radius: topRadius,
                    iconSize: topIconSize,
                    icon: Icons.bolt_rounded,
                    isActive: _isTorchOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: _toggleTorch,
                  ),
                  const SizedBox(width: 10),
                  _MorphButton(
                    width: topWidth,
                    height: topHeight,
                    radius: topRadius,
                    iconSize: topIconSize,
                    icon: _isDndOn
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_off_outlined,
                    isActive: _isDndOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isDndOn = !_isDndOn);
                      widget.platform.openDndSettings();
                    },
                  ),
                  const SizedBox(width: 10),
                  _MorphButton(
                    width: topWidth,
                    height: topHeight,
                    radius: topRadius,
                    iconSize: topIconSize,
                    icon: _isAutoBrightnessOn
                        ? Icons.brightness_auto_rounded
                        : Icons.brightness_6_rounded,
                    isActive: _isAutoBrightnessOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isAutoBrightnessOn = !_isAutoBrightnessOn);
                      widget.platform.openDisplaySettings();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row B: Night Light, Airplane Mode, Wifi (persistent full squircles)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MorphButton(
                    width: 76,
                    height: 54,
                    radius: 22,
                    iconSize: 24,
                    icon: Icons.nightlight_round,
                    isActive: _isNightLightOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isNightLightOn = !_isNightLightOn);
                      widget.platform.openNightLightSettings();
                    },
                  ),
                  const SizedBox(width: 10),
                  _MorphButton(
                    width: 76,
                    height: 54,
                    radius: 22,
                    iconSize: 24,
                    icon: Icons.airplanemode_active_rounded,
                    isActive: _isAirplaneOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isAirplaneOn = !_isAirplaneOn);
                      widget.platform.openAirplaneSettings();
                    },
                  ),
                  const SizedBox(width: 10),
                  _MorphButton(
                    width: 76,
                    height: 54,
                    radius: 22,
                    iconSize: 24,
                    icon: _isWifiOn ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    isActive: _isWifiOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isWifiOn = !_isWifiOn);
                      widget.platform.openWifiSettings();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row C: Auto-rotate, Camera access, Settings (shrinks on pull)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MorphButton(
                    width: btmWidth,
                    height: btmHeight,
                    radius: btmRadius,
                    iconSize: btmIconSize,
                    icon: Icons.screen_rotation_rounded,
                    isActive: _isAutoRotateOn,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isAutoRotateOn = !_isAutoRotateOn);
                      widget.platform.openAutoRotateSettings();
                    },
                  ),
                  const SizedBox(width: 10),
                  _MorphButton(
                    width: btmWidth,
                    height: btmHeight,
                    radius: btmRadius,
                    iconSize: btmIconSize,
                    icon: Icons.photo_camera_rounded,
                    isActive: false,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.platform.openCamera();
                    },
                  ),
                  const SizedBox(width: 10),
                  _MorphButton(
                    width: btmWidth,
                    height: btmHeight,
                    radius: btmRadius,
                    iconSize: btmIconSize,
                    icon: Icons.settings_rounded,
                    isActive: false,
                    activeBg: activeBg,
                    activeFg: activeFg,
                    inactiveBg: inactiveBg,
                    inactiveFg: inactiveFg,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.platform.openSystemSettings();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Capsule: Wifi, Alarm, Bluetooth (only if connected) - ZERO BORDER
              M3SpringButton(
                onTap: _toggleMorph,
                pressedScale: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: inactiveBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 10),
                      const Icon(Icons.alarm_rounded, size: 16, color: Colors.white70),
                      if (_isBluetoothConnected) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.bluetooth_connected_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Drag handle bar to collapse Quick Settings
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF444444),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MorphButton extends StatelessWidget {
  const _MorphButton({
    required this.width,
    required this.height,
    required this.radius,
    required this.iconSize,
    required this.icon,
    required this.isActive,
    required this.activeBg,
    required this.activeFg,
    required this.inactiveBg,
    required this.inactiveFg,
    required this.onTap,
  });

  final double width;
  final double height;
  final double radius;
  final double iconSize;
  final IconData icon;
  final bool isActive;
  final Color activeBg;
  final Color activeFg;
  final Color inactiveBg;
  final Color inactiveFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return M3SpringButton(
      onTap: onTap,
      pressedScale: 0.90,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isActive ? activeBg : inactiveBg,
          // Zero borders anywhere
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: isActive ? activeFg : inactiveFg,
        ),
      ),
    );
  }
}
