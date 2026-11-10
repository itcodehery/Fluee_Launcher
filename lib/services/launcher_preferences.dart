import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _keyDock = 'dock_ids';
  static const _keyRecentApps = 'recent_app_ids';
  static const _keySortMode = 'drawer_sort_mode';
  static const _keyWallpaperAccent = 'accent_wallpaper';
  static const _keyAccentColor = 'accent_color';
  static const _keyCompletedIntro = 'completed_intro';
  static const _keyHiddenApps = 'hidden_app_ids';
  static const _keyCustomWallpaperPath = 'custom_wallpaper_path';
  static const _keySelectedIconPack = 'selected_icon_pack';
  static const _keyCustomIconMap = 'custom_icon_map';
  static const _keyDrawerIsList = 'drawer_is_list';
  static const _keyDrawerMode = 'drawer_display_mode';
  static const _keyAutoFocusSearch = 'auto_focus_search';
  static const _keySearchIncludesHidden = 'search_includes_hidden';
  static const _keyAmbientIdleMode = 'ambient_idle_mode';
  static const _keyAmbientCustomText = 'ambient_custom_text';

  static Future<LauncherPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LauncherPreferences(prefs);
  }

  bool get hasCompletedIntro => _prefs.getBool(_keyCompletedIntro) ?? false;

  Future<void> setCompletedIntro(bool completed) =>
      _prefs.setBool(_keyCompletedIntro, completed);

  List<String>? get dockIds => _prefs.getStringList(_keyDock);

  Future<void> setDockIds(List<String> ids) =>
      _prefs.setStringList(_keyDock, ids);

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
}
