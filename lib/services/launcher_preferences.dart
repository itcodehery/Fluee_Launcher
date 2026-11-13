import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_shortcut.dart';
import '../theme/launcher_colors.dart';

enum DrawerMode {
  grid,
  list,
}


enum AppSortMode {
  az,
  za,
  recent,
}

class LauncherPreferences {
  LauncherPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _keyQuickApps = 'quick_app_ids';
  static const _keyPinnedQuickTasks = 'pinned_quick_tasks';
  static const _keyRecentApps = 'recent_app_ids';
  static const _keySortMode = 'drawer_sort_mode';
  static const _keyWallpaperAccent = 'accent_wallpaper';
  static const _keyAccentColor = 'accent_color';
  static const _keyCompletedIntro = 'completed_intro';
  static const _keyHiddenApps = 'hidden_app_ids';
  static const _keyCustomWallpaperPath = 'custom_wallpaper_path';
  static const _keySelectedIconPack = 'selected_icon_pack';
  static const _keyCustomIconMap = 'custom_icon_map';
  static const _keyCustomLabelMap = 'custom_label_map';
  static const _keyDrawerIsList = 'drawer_is_list';
  static const _keyDrawerMode = 'drawer_display_mode';
  static const _keyAutoFocusSearch = 'auto_focus_search';
  static const _keySearchIncludesHidden = 'search_includes_hidden';
  static const _keyAmbientIdleMode = 'ambient_idle_mode';
  static const _keyProfileName = 'profile_name';
  static const _keyProfilePhoto = 'profile_photo_b64';
  static const _keyAmbientCustomText = 'ambient_custom_text';

  static Future<LauncherPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LauncherPreferences(prefs);
  }

  bool get hasCompletedIntro => _prefs.getBool(_keyCompletedIntro) ?? false;

  Future<void> setCompletedIntro(bool completed) =>
      _prefs.setBool(_keyCompletedIntro, completed);

  List<String> get quickAppIds =>
      _prefs.getStringList(_keyQuickApps) ?? const [];

  Future<void> setQuickAppIds(List<String> ids) =>
      _prefs.setStringList(_keyQuickApps, ids);

  List<PinnedQuickTask> get pinnedQuickTasks {
    final raw = _prefs.getString(_keyPinnedQuickTasks);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PinnedQuickTask.fromJson)
          .where((t) => t.packageName.isNotEmpty && t.shortcutId.isNotEmpty)
          .take(maxPinnedQuickTasks)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setPinnedQuickTasks(List<PinnedQuickTask> tasks) async {
    final capped = tasks.take(maxPinnedQuickTasks).map((t) => t.toJson()).toList();
    await _prefs.setString(_keyPinnedQuickTasks, jsonEncode(capped));
  }

  List<String> get recentAppIds =>
      _prefs.getStringList(_keyRecentApps) ?? const [];

  Future<void> addRecentApp(String appId) async {
    final list = recentAppIds.toSet().toList();
    list.remove(appId);
    list.insert(0, appId);
    if (list.length > 30) {
      list.removeRange(30, list.length);
    }
    await _prefs.setStringList(_keyRecentApps, list);
  }

  AppSortMode get sortMode {
    final name = _prefs.getString(_keySortMode);
    return AppSortMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => AppSortMode.az,
    );
  }

  Future<void> setSortMode(AppSortMode mode) =>
      _prefs.setString(_keySortMode, mode.name);

  Set<String> get hiddenAppIds =>
      (_prefs.getStringList(_keyHiddenApps) ?? const []).toSet();

  Future<void> setHiddenAppIds(Set<String> ids) =>
      _prefs.setStringList(_keyHiddenApps, ids.toList());

  String? get customWallpaperPath => _prefs.getString(_keyCustomWallpaperPath);

  Future<void> setCustomWallpaperPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_keyCustomWallpaperPath);
    } else {
      await _prefs.setString(_keyCustomWallpaperPath, path);
    }
  }

  String? get selectedIconPack => _prefs.getString(_keySelectedIconPack);

  Future<void> setSelectedIconPack(String? pack) async {
    if (pack == null) {
      await _prefs.remove(_keySelectedIconPack);
    } else {
      await _prefs.setString(_keySelectedIconPack, pack);
    }
  }

  Map<String, String> get customLabelMap {
    final raw = _prefs.getString(_keyCustomLabelMap);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  Future<void> setCustomLabel(String appId, String newLabel) async {
    final map = Map<String, String>.from(customLabelMap);
    if (newLabel.trim().isEmpty) {
      map.remove(appId);
    } else {
      map[appId] = newLabel.trim();
    }
    await _prefs.setString(_keyCustomLabelMap, jsonEncode(map));
  }

  Future<void> resetCustomLabel(String appId) async {
    final map = Map<String, String>.from(customLabelMap);
    map.remove(appId);
    await _prefs.setString(_keyCustomLabelMap, jsonEncode(map));
  }

  Map<String, String> get customIconMap {
    final raw = _prefs.getString(_keyCustomIconMap);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setCustomIcon(String appId, String packWithDrawable) async {
    final current = customIconMap;
    current[appId] = packWithDrawable;
    await _prefs.setString(_keyCustomIconMap, jsonEncode(current));
  }

  Future<void> resetCustomIcon(String appId) async {
    final current = customIconMap;
    current.remove(appId);
    await _prefs.setString(_keyCustomIconMap, jsonEncode(current));
  }

  bool get drawerIsList => drawerMode == DrawerMode.list;

  Future<void> setDrawerIsList(bool isList) =>
      setDrawerMode(isList ? DrawerMode.list : DrawerMode.grid);

  DrawerMode get drawerMode {
    final modeStr = _prefs.getString(_keyDrawerMode);
    if (modeStr != null) {
      return DrawerMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => DrawerMode.grid,
      );
    }
    final legacyList = _prefs.getBool(_keyDrawerIsList) ?? false;
    return legacyList ? DrawerMode.list : DrawerMode.grid;
  }

  Future<void> setDrawerMode(DrawerMode mode) async {
    await _prefs.setString(_keyDrawerMode, mode.name);
    await _prefs.setBool(_keyDrawerIsList, mode == DrawerMode.list);
  }

  bool get autoFocusSearch => _prefs.getBool(_keyAutoFocusSearch) ?? false;

  Future<void> setAutoFocusSearch(bool value) =>
      _prefs.setBool(_keyAutoFocusSearch, value);

  bool get searchIncludesHidden =>
      _prefs.getBool(_keySearchIncludesHidden) ?? false;

  Future<void> setSearchIncludesHidden(bool value) =>
      _prefs.setBool(_keySearchIncludesHidden, value);

  bool get ambientIdleMode => _prefs.getBool(_keyAmbientIdleMode) ?? true;

  Future<void> setAmbientIdleMode(bool value) =>
      _prefs.setBool(_keyAmbientIdleMode, value);

  String? get profileName => _prefs.getString(_keyProfileName);

  Future<void> setProfileName(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(_keyProfileName);
    } else {
      await _prefs.setString(_keyProfileName, value.trim());
    }
  }

  Uint8List? get profilePhoto {
    final b64 = _prefs.getString(_keyProfilePhoto);
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> setProfilePhoto(Uint8List? bytes) async {
    if (bytes == null) {
      await _prefs.remove(_keyProfilePhoto);
    } else {
      await _prefs.setString(_keyProfilePhoto, base64Encode(bytes));
    }
  }

  
  String? get ambientCustomText => _prefs.getString(_keyAmbientCustomText);

  Future<void> setAmbientCustomText(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(_keyAmbientCustomText);
    } else {
      await _prefs.setString(_keyAmbientCustomText, value.trim());
    }
  }

  bool get useWallpaperAccent =>
      _prefs.getBool(_keyWallpaperAccent) ?? false;

  Color get customAccent {
    final value = _prefs.getInt(_keyAccentColor);
    return value != null ? Color(value) : LauncherColors.defaultAccent;
  }

  Future<void> setCustomAccent(Color color) async {
    await _prefs.setBool(_keyWallpaperAccent, false);
    await _prefs.setInt(_keyAccentColor, color.toARGB32());
  }

  Future<void> setUseWallpaperAccent() =>
      _prefs.setBool(_keyWallpaperAccent, true);

  /// Exports current launcher layout, custom labels, hidden apps, quick apps, and theme to a Map.
  Map<String, dynamic> exportBackupJson() {
    return {
      'launcher': 'Fluee',
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'quickAppIds': quickAppIds,
      'pinnedQuickTasks': pinnedQuickTasks.map((t) => t.toJson()).toList(),
      'recentAppIds': recentAppIds,
      'sortMode': sortMode.name,
      'hiddenAppIds': hiddenAppIds.toList(),
      'customLabelMap': customLabelMap,
      'customIconMap': customIconMap,
      'selectedIconPack': selectedIconPack,
      'drawerMode': drawerMode.name,
      'autoFocusSearch': autoFocusSearch,
      'searchIncludesHidden': searchIncludesHidden,
      'ambientIdleMode': ambientIdleMode,
      'ambientCustomText': ambientCustomText,
      'profileName': profileName,
      'profilePhoto': _prefs.getString(_keyProfilePhoto),
      'useWallpaperAccent': useWallpaperAccent,
      'customAccent': customAccent.toARGB32(),
      'customWallpaperPath': customWallpaperPath,
    };
  }

  /// Restores launcher layout, custom labels, hidden apps, quick apps, and theme from JSON string.
  Future<bool> importBackupJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return false;
      final data = decoded;
      if (data['launcher'] != 'Fluee' && !data.containsKey('version')) {
        return false;
      }

      if (data.containsKey('quickAppIds')) {
        final list = (data['quickAppIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
        await setQuickAppIds(list);
      }
      if (data.containsKey('pinnedQuickTasks')) {
        final rawList = data['pinnedQuickTasks'] as List? ?? const [];
        final tasks = rawList
            .whereType<Map<String, dynamic>>()
            .map(PinnedQuickTask.fromJson)
            .where((t) => t.packageName.isNotEmpty && t.shortcutId.isNotEmpty)
            .take(maxPinnedQuickTasks)
            .toList();
        await setPinnedQuickTasks(tasks);
      }
      if (data.containsKey('hiddenAppIds')) {
        final list = (data['hiddenAppIds'] as List?)?.map((e) => e.toString()).toSet() ?? {};
        await setHiddenAppIds(list);
      }
      if (data.containsKey('customLabelMap')) {
        final rawMap = data['customLabelMap'] as Map<String, dynamic>?;
        if (rawMap != null) {
          await _prefs.setString(_keyCustomLabelMap, jsonEncode(rawMap));
        }
      }
      if (data.containsKey('customIconMap')) {
        final rawMap = data['customIconMap'] as Map<String, dynamic>?;
        if (rawMap != null) {
          await _prefs.setString(_keyCustomIconMap, jsonEncode(rawMap));
        }
      }
      if (data.containsKey('selectedIconPack')) {
        await setSelectedIconPack(data['selectedIconPack'] as String?);
      }
      if (data.containsKey('drawerMode')) {
        final modeName = data['drawerMode'] as String?;
        final mode = DrawerMode.values.firstWhere(
          (m) => m.name == modeName,
          orElse: () => DrawerMode.grid,
        );
        await setDrawerMode(mode);
      }
      if (data.containsKey('autoFocusSearch')) {
        await setAutoFocusSearch(data['autoFocusSearch'] as bool? ?? false);
      }
      if (data.containsKey('searchIncludesHidden')) {
        await setSearchIncludesHidden(data['searchIncludesHidden'] as bool? ?? false);
      }
      if (data.containsKey('ambientIdleMode')) {
        await setAmbientIdleMode(data['ambientIdleMode'] as bool? ?? true);
      }
      if (data.containsKey('ambientCustomText')) {
        await setAmbientCustomText(data['ambientCustomText'] as String?);
      }
      if (data.containsKey('profileName')) {
        await setProfileName(data['profileName'] as String?);
      }
      if (data.containsKey('profilePhoto')) {
        final b64 = data['profilePhoto'] as String?;
        if (b64 != null) {
          await _prefs.setString(_keyProfilePhoto, b64);
        } else {
          await _prefs.remove(_keyProfilePhoto);
        }
      }
      if (data.containsKey('useWallpaperAccent')) {
        final useWp = data['useWallpaperAccent'] as bool? ?? false;
        if (useWp) {
          await setUseWallpaperAccent();
        } else if (data.containsKey('customAccent')) {
          final cInt = data['customAccent'] as int?;
          if (cInt != null) {
            await setCustomAccent(Color(cInt));
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
