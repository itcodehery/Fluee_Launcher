import 'dart:async';
import 'package:flutter/services.dart';
import '../models/app_item.dart';

class IconPackInfo {
  const IconPackInfo({
    required this.packageName,
    required this.label,
    required this.icon,
  });

  final String packageName;
  final String label;
  final Uint8List icon;

  factory IconPackInfo.fromMap(Map<Object?, Object?> map) {
    return IconPackInfo(
      packageName: (map['packageName'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      icon: (map['icon'] as Uint8List?) ?? Uint8List(0),
    );
  }
}

class IconPackDrawable {
  const IconPackDrawable({
    required this.drawableName,
    required this.icon,
  });

  final String drawableName;
  final Uint8List icon;

  factory IconPackDrawable.fromMap(Map<Object?, Object?> map) {
    return IconPackDrawable(
      drawableName: (map['drawableName'] as String?) ?? '',
      icon: (map['icon'] as Uint8List?) ?? Uint8List(0),
    );
  }
}

class LauncherPlatform {
  LauncherPlatform({void Function()? onHomePressed}) {
    _method.setMethodCallHandler((call) async {
      if (call.method == 'onHomePressed') {
        onHomePressed?.call();
      }
    });
  }

  static const _method = MethodChannel('fluee/launcher');
  static const _events = EventChannel('fluee/app_changes');

  Stream<void> get packageChanges {
    try {
      return _events.receiveBroadcastStream().map((_) {});
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<List<AppItem>> getApps({
    String? iconPack,
    Map<String, String>? customIconMap,
  }) async {
    try {
      final raw = await _method.invokeListMethod<Map<Object?, Object?>>(
        'getApps',
        {
          'iconPack': iconPack,
          'customIconMap': customIconMap ?? <String, String>{},
        },
      );
      if (raw == null) return const [];
      final seen = <String>{};
      final uniqueApps = <AppItem>[];
      for (final map in raw) {
        final app = AppItem.fromMap(map);
        if (app.packageName.isNotEmpty && seen.add(app.id)) {
          uniqueApps.add(app);
        }
      }
      uniqueApps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      return uniqueApps;
    } on MissingPluginException {
      // Fallback if app was hot-restarted before native rebuild
      final raw = await _method.invokeListMethod<Map<Object?, Object?>>('getApps');
      if (raw == null) return const [];
      final seen = <String>{};
      final uniqueApps = <AppItem>[];
      for (final map in raw) {
        final app = AppItem.fromMap(map);
        if (app.packageName.isNotEmpty && seen.add(app.id)) {
          uniqueApps.add(app);
        }
      }
      uniqueApps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      return uniqueApps;
    } catch (_) {
      return const [];
    }
  }

  Future<List<IconPackInfo>> getIconPacks() async {
    try {
      final raw = await _method.invokeListMethod<Map<Object?, Object?>>('getIconPacks');
      if (raw == null) return const [];
      return raw.map(IconPackInfo.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<IconPackDrawable>> getIconPackDrawables(String packageName) async {
    try {
      final raw = await _method.invokeListMethod<Map<Object?, Object?>>(
        'getIconPackDrawables',
        {'packageName': packageName},
      );
      if (raw == null) return const [];
      return raw.map(IconPackDrawable.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final enabled = await _method.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAccessibilitySettings() async {
    try {
      final res = await _method.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openWifiSettings() async {
    try {
      await _method.invokeMethod('openWifiSettings');
    } catch (_) {}
  }

  Future<void> openSoundSettings() async {
    try {
      await _method.invokeMethod('openSoundSettings');
    } catch (_) {}
  }

  Future<void> openBatterySettings() async {
    try {
      await _method.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  Future<void> openAirplaneSettings() async {
    try {
      await _method.invokeMethod('openAirplaneSettings');
    } catch (_) {}
  }

  Future<void> openDisplaySettings() async {
    try {
      await _method.invokeMethod('openDisplaySettings');
    } catch (_) {}
  }

  Future<void> openDndSettings() async {
    try {
      await _method.invokeMethod('openDndSettings');
    } catch (_) {}
  }

  Future<void> openSystemSettings() async {
    try {
      await _method.invokeMethod('openSystemSettings');
    } catch (_) {}
  }

  Future<void> openAutoRotateSettings() async {
    try {
      await _method.invokeMethod('openAutoRotateSettings');
    } catch (_) {}
  }

  Future<void> openNightLightSettings() async {
    try {
      await _method.invokeMethod('openNightLightSettings');
    } catch (_) {}
  }

  Future<void> openCamera() async {
    try {
      await _method.invokeMethod('openCamera');
    } catch (_) {}
  }

  Future<void> openBluetoothSettings() async {
    try {
      await _method.invokeMethod('openBluetoothSettings');
    } catch (_) {}
  }

  Future<bool> isBluetoothConnected() async {
    try {
      final res = await _method.invokeMethod<bool>('isBluetoothConnected');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleFlashlight() async {
    try {
      final res = await _method.invokeMethod<bool>('toggleFlashlight');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> lockScreen() async {
    try {
      final res = await _method.invokeMethod<bool>('lockScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> launch(AppItem app) async {
    try {
      await _method.invokeMethod('launch', {
        'packageName': app.packageName,
        'activityName': app.activityName,
        'userSerial': app.userSerial,
      });
    } catch (_) {}
  }

  Future<void> openAppInfo(AppItem app) async {
    try {
      await _method.invokeMethod('appInfo', {
        'packageName': app.packageName,
        'activityName': app.activityName,
        'userSerial': app.userSerial,
      });
    } catch (_) {}
  }

  Future<void> uninstall(AppItem app) async {
    try {
      await _method.invokeMethod('uninstall', {
        'packageName': app.packageName,
      });
    } catch (_) {}
  }

  Future<void> openAlarms() async {
    try {
      await _method.invokeMethod('openAlarms');
    } catch (_) {}
  }

  Future<void> openHomeSettings() async {
    try {
      await _method.invokeMethod('openHomeSettings');
    } catch (_) {}
  }

  Future<Color?> getWallpaperAccent() async {
    try {
      final argb = await _method.invokeMethod<int>('wallpaperAccent');
      return argb != null ? Color(argb) : null;
    } catch (_) {
      return null;
    }
  }
}
