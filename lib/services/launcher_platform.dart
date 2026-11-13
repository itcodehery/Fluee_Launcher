import 'dart:async';
import 'package:flutter/services.dart';
import '../models/app_item.dart';
import '../models/app_shortcut.dart';

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

  Future<bool> isBluetoothConnected() async {
    try {
      final res = await _method.invokeMethod<bool>('isBluetoothConnected');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<({int level, bool charging})?> getBattery() async {
    try {
      final res = await _method.invokeMapMethod<String, dynamic>('getBatteryLevel');
      if (res == null) return null;
      return (
        level: (res['level'] as num).toInt(),
        charging: res['charging'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<double?> getVolume() async {
    try {
      return await _method.invokeMethod<double>('getVolume');
    } catch (_) {
      return null;
    }
  }

  Future<void> setVolume(double value) async {
    try {
      await _method.invokeMethod('setVolume', {'value': value});
    } catch (_) {}
  }

  Future<double?> getBrightness() async {
    try {
      return await _method.invokeMethod<double>('getBrightness');
    } catch (_) {
      return null;
    }
  }

  /// Returns false when the "modify system settings" permission is missing.
  Future<bool> setBrightness(double value) async {
    try {
      return await _method.invokeMethod<bool>('setBrightness', {'value': value}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openWriteSettings() async {
    try {
      await _method.invokeMethod('openWriteSettings');
    } catch (_) {}
  }

  /// Opens the system power menu; false if the accessibility service is off.
  Future<bool> showPowerMenu() async {
    try {
      return await _method.invokeMethod<bool>('showPowerMenu') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system notification shade; false if unavailable.
  Future<bool> openNotifications() async {
    try {
      return await _method.invokeMethod<bool>('openNotifications') ?? false;
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

  Future<Map<String, dynamic>?> getMediaTrack() async {
    try {
      final res = await _method.invokeMapMethod<String, dynamic>('getMediaTrack');
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isNotificationAccessGranted() async {
    try {
      final res = await _method.invokeMethod<bool>('isNotificationAccessGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _method.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
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

  Future<void> openCalendar() async {
    try {
      await _method.invokeMethod('openCalendar');
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

  /// Queries Android dynamic and manifest shortcuts for a given package or all apps.
  Future<List<AppShortcut>> getAppShortcuts([String? packageName]) async {
    try {
      final raw = await _method.invokeListMethod<Map<dynamic, dynamic>>(
        'getShortcuts',
        packageName != null ? {'packageName': packageName} : null,
      );
      if (raw == null) return const [];
      return raw.map(AppShortcut.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Starts a specific shortcut via Android LauncherApps API.
  Future<bool> startShortcut(String packageName, String shortcutId) async {
    try {
      final ok = await _method.invokeMethod<bool>('startShortcut', {
        'packageName': packageName,
        'shortcutId': shortcutId,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Exports backup JSON to local storage, SD Card, or cloud storage via system file picker.
  Future<bool> exportBackupFile(String jsonContent, String fileName) async {
    try {
      final ok = await _method.invokeMethod<bool>('exportBackupFile', {
        'content': jsonContent,
        'fileName': fileName,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Imports backup JSON from local storage, Google Drive, or cloud storage via system file picker.
  Future<String?> importBackupFile() async {
    try {
      return await _method.invokeMethod<String>('importBackupFile');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system share sheet with the backup JSON text.
  Future<bool> shareBackup(String jsonContent, [String? title]) async {
    try {
      final ok = await _method.invokeMethod<bool>('shareBackup', {
        'content': jsonContent,
        'title': title ?? 'Fluee Launcher Backup',
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
