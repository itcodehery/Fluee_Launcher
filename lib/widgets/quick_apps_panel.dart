import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../services/launcher_platform.dart';
import '../theme/launcher_colors.dart';
import 'm3_spring_button.dart';

const int maxQuickApps = 6;

/// Pull-down shade: battery pill, 6 pinnable app slots, and a status pill.
class QuickAppsPanel extends StatefulWidget {
  const QuickAppsPanel({
    super.key,
    required this.accent,
    required this.platform,
    required this.slots,
    required this.onClose,
    required this.onAppTap,
    required this.onAppLongPress,
    required this.onEmptySlotTap,
  });

  final Color accent;
  final LauncherPlatform platform;

  /// Exactly [maxQuickApps] entries; null means an empty slot.
  final List<AppItem?> slots;
  final VoidCallback onClose;
  final void Function(AppItem app) onAppTap;
  final void Function(AppItem app) onAppLongPress;
  final void Function(int index) onEmptySlotTap;

  @override
  State<QuickAppsPanel> createState() => _QuickAppsPanelState();
}

class _QuickAppsPanelState extends State<QuickAppsPanel>
    with WidgetsBindingObserver {
  static const _pillBg = Color(0xFF333333);

  bool _isBluetoothConnected = false;
  int? _battery;
  bool _charging = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    final bt = await widget.platform.isBluetoothConnected();
    final battery = await widget.platform.getBattery();
    if (!mounted) return;
    setState(() {
      _isBluetoothConnected = bt;
      _battery = battery?.level;
      _charging = battery?.charging ?? false;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _slot(int i, double width, double height) {
    final app = widget.slots[i];
    // Pill squircle matching reference 2 (76x54 with 24px radius)
    final radius = BorderRadius.circular(24);
    return SizedBox(
      width: width,
      height: height,
      child: app == null
          ? M3SpringButton(
              onTap: () => widget.onEmptySlotTap(i),
              pressedScale: 0.90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _pillBg.withValues(alpha: 0.7),
                  borderRadius: radius,
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, color: Colors.white38, size: 24),
                ),
              ),
            )
          : M3SpringButton(
              onTap: () => widget.onAppTap(app),
              onLongPress: () => widget.onAppLongPress(app),
              pressedScale: 0.90,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: radius,
                ),
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.58,
                  heightFactor: 0.58,
                  child: app.icon.isNotEmpty
                      ? (app.isMonochrome
                          ? Image.memory(
                              app.icon,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              color: LauncherColors.readableOn(widget.accent),
                              colorBlendMode: BlendMode.srcIn,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.apps,
                                color: LauncherColors.readableOn(widget.accent),
                                size: 24,
                              ),
                            )
                          : Image.memory(
                              app.icon,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.apps,
                                color: LauncherColors.readableOn(widget.accent),
                                size: 24,
                              ),
                            ))
                      : Icon(
                          Icons.apps,
                          color: LauncherColors.readableOn(widget.accent),
                          size: 24,
                        ),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batteryIcon = _charging
        ? Icons.battery_charging_full_rounded
        : Icons.battery_full_rounded;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Battery pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: _pillBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(batteryIcon, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  _battery == null ? '--%' : '$_battery%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  _slot(row * 3 + col, 76, 54),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Status pill: Wifi, Alarm, Bluetooth (if connected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: _pillBg,
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
                  const Icon(Icons.bluetooth_connected_rounded,
                      size: 16, color: Colors.white70),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

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
      ),
    );
  }
}

/// Bottom sheet listing apps to choose from for a quick-app slot.
class QuickAppPickerSheet extends StatelessWidget {
  const QuickAppPickerSheet({
    super.key,
    required this.apps,
    required this.onSelected,
  });

  final List<AppItem> apps;
  final void Function(AppItem app) onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pin to quick apps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, i) {
                  final app = apps[i];
                  return ListTile(
                    leading: SizedBox(
                      width: 36,
                      height: 36,
                      child: app.icon.isNotEmpty
                          ? Image.memory(
                              app.icon,
                              gaplessPlayback: true,
                              color: app.isMonochrome
                                  ? LauncherColors.tileIcon
                                  : null,
                              colorBlendMode:
                                  app.isMonochrome ? BlendMode.srcIn : null,
                            )
                          : const Icon(Icons.apps, color: LauncherColors.tileIcon),
                    ),
                    title: Text(app.label,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => onSelected(app),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
