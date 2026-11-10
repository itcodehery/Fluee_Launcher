import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/launcher_colors.dart';

class LauncherPreferences {
  LauncherPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _keyDock = 'dock_ids';
  static const _keyWallpaperAccent = 'accent_wallpaper';
  static const _keyAccentColor = 'accent_color';
  static const _keyCompletedIntro = 'completed_intro';
  static const _keyHiddenApps = 'hidden_app_ids';
  static const _keyCustomWallpaperPath = 'custom_wallpaper_path';
  static const _keySelectedIconPack = 'selected_icon_pack';
  static const _keyCustomIconMap = 'custom_icon_map';
  static const _keyDrawerIsList = 'drawer_is_list';
  static const _keyAutoFocusSearch = 'auto_focus_search';
  static const _keySearchIncludesHidden = 'search_includes_hidden';

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

  bool get drawerIsList => _prefs.getBool(_keyDrawerIsList) ?? false;

  Future<void> setDrawerIsList(bool isList) =>
      _prefs.setBool(_keyDrawerIsList, isList);

  bool get autoFocusSearch => _prefs.getBool(_keyAutoFocusSearch) ?? false;

  Future<void> setAutoFocusSearch(bool value) =>
      _prefs.setBool(_keyAutoFocusSearch, value);

  bool get searchIncludesHidden =>
      _prefs.getBool(_keySearchIncludesHidden) ?? false;

  Future<void> setSearchIncludesHidden(bool value) =>
      _prefs.setBool(_keySearchIncludesHidden, value);

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
