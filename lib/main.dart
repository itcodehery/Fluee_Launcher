import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/app_item.dart';
import 'models/app_shortcut.dart';
import 'services/launcher_platform.dart';
import 'services/launcher_preferences.dart';
import 'theme/launcher_colors.dart';
import 'theme/m3_motion.dart';
import 'widgets/app_actions_sheet.dart';
import 'widgets/app_panel.dart';
import 'widgets/app_tile.dart';
import 'widgets/icon_picker_sheet.dart';
import 'widgets/intro_flow.dart';
import 'widgets/ambient_lock_keypad.dart';
import 'widgets/launcher_clock.dart';
import 'widgets/launcher_dock.dart';
import 'widgets/profile_dashboard.dart';
import 'widgets/quick_apps_panel.dart';
import 'widgets/quick_tasks_bar.dart';
import 'widgets/settings_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FlueeLauncherApp());
}

class FlueeLauncherApp extends StatelessWidget {
  const FlueeLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluee Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: LauncherColors.background,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: LauncherColors.sheetBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
      ),
      home: const LauncherScreen(),
    );
  }
}

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> with WidgetsBindingObserver {
  late final LauncherPlatform _platform;
  LauncherPreferences? _prefs;
  StreamSubscription<void>? _pkgSub;

  List<AppItem> _allApps = const [];
  Set<String> _hiddenAppIds = <String>{};
  List<AppShortcut> _allShortcuts = const [];
  List<PinnedQuickTask> _pinnedQuickTasks = const [];
  List<String> _quickIds = List<String>.filled(maxQuickApps, '');
  List<String> _dockIds = List<String>.filled(maxDockApps, '');
  List<IconPackInfo> _availableIconPacks = const [];
  String? _selectedIconPack;
  Map<String, String> _customIconMap = const {};
  Map<String, String> _customLabelMap = const {};
  bool _drawerIsList = false;
  DrawerMode _drawerMode = DrawerMode.grid;
  bool _autoFocusSearch = false;
  bool _searchIncludesHidden = false;
  AppSortMode _sortMode = AppSortMode.az;
  List<String> _recentAppIds = const [];
  bool _ambientIdleMode = true;
  int _ambientTimeoutSeconds = 15;
  AmbientStyle _ambientStyle = AmbientStyle.pillsGlow;
  bool _ambientLockEnabled = false;
  String? _ambientLockPin;
  String? _ambientCustomText;
  String? _profileName;
  Uint8List? _profilePhoto;
  bool _isIdle = false;
  bool _isAmbientKeypadShown = false;
  Timer? _idleTimer;
  Timer? _mediaPollTimer;
  Timer? _batteryPollTimer;
  int? _batteryLevel;
  bool _isCharging = false;
  String? _mediaTitle;
  String? _mediaArtist;
  String? _mediaPackageName;
  Uint8List? _mediaAlbumArt;
  bool _mediaIsPlaying = false;
  int? _mediaArtId;

  Color _customAccent = LauncherColors.defaultAccent;
  Color? _wallpaperAccent;
  bool _useWallpaperAccent = false;
  bool _isPanelExpanded = false;
  bool _isDashboardOpen = false;
  double _dashboardDragOffset = 0.0;
  double? _drawerDragT;
  bool _isDraggingDashboard = false;
  int? _dragPointer;
  Offset _dragOrigin = Offset.zero;
  bool _dragClaimed = false;
  double _dragStartPos = 0;
  double _maxH = 800;
  VelocityTracker? _velocityTracker;

  static const double _dashboardTravel = 340.0;
  bool _hasCompletedIntro = true;
  bool _isInitialized = false;

  Color get _effectiveAccent =>
      (_useWallpaperAccent && _wallpaperAccent != null)
          ? _wallpaperAccent!
          : _customAccent;

  List<AppItem> get _visibleApps =>
      _allApps.where((a) => !_hiddenAppIds.contains(a.id)).toList();

  List<String> _normalizeQuick(List<String> ids) => List<String>.generate(
      maxQuickApps, (i) => i < ids.length ? ids[i] : '');

  List<String> _normalizeDock(List<String> ids) => List<String>.generate(
      maxDockApps, (i) => i < ids.length ? ids[i] : '');

  List<AppItem?> get _quickSlots {
    final byId = {for (final a in _allApps) a.id: a};
    return [for (final id in _quickIds) byId[id]];
  }

  List<AppItem?> get _dockSlots {
    final byId = {for (final a in _allApps) a.id: a};
    return [for (final id in _dockIds) byId[id]];
  }

  Future<void> _setDockIds(List<String> ids) async {
    setState(() => _dockIds = ids);
    await _prefs?.setDockAppIds(ids);
  }

  void _pickDockApp(int slot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => QuickAppPickerSheet(
        apps: _visibleApps,
        onSelected: (app) {
          Navigator.pop(sheetCtx);
          final current = List<String>.from(_dockIds);
          final existing = current.indexOf(app.id);
          if (existing >= 0) current[existing] = '';
          current[slot] = app.id;
          _setDockIds(current);
        },
      ),
    );
  }

  void _showDockSlotMenu(int slot, AppItem app) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.bolt_rounded, color: _effectiveAccent),
                title: const Text('App tasks & info', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showAppActions(app);
                },
              ),
              ListTile(
                leading: Icon(Icons.swap_horiz_rounded, color: _effectiveAccent),
                title: const Text('Replace dock app', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickDockApp(slot);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: LauncherColors.danger),
                title: const Text('Remove from dock', style: TextStyle(color: LauncherColors.danger)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  final current = List<String>.from(_dockIds);
                  current[slot] = '';
                  _setDockIds(current);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setQuickIds(List<String> ids) async {
    setState(() => _quickIds = ids);
    await _prefs?.setQuickAppIds(ids);
  }

  Future<void> _toggleQuick(AppItem app) async {
    final current = List<String>.from(_quickIds);
    final idx = current.indexOf(app.id);
    if (idx >= 0) {
      current[idx] = '';
    } else {
      final free = _quickSlots.indexWhere((a) => a == null);
      if (free < 0) return;
      current[free] = app.id;
    }
    await _setQuickIds(current);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideStatusBar();
    _platform = LauncherPlatform(onHomePressed: _resetHome);
    _init();
  }

  void _hideStatusBar() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hideStatusBar();
      _syncBattery();
    }
  }

  Future<void> _init() async {
    final prefs = await LauncherPreferences.load();
    final wallpaper = await _platform.getWallpaperAccent();
    final iconPacks = await _platform.getIconPacks();

    final pack = prefs.selectedIconPack;
    final customIcons = prefs.customIconMap;
    final rawApps = await _platform.getApps(iconPack: pack, customIconMap: customIcons);
    final customLabels = prefs.customLabelMap;
    final apps = rawApps.map((a) {
      final custom = customLabels[a.id];
      return (custom != null && custom.isNotEmpty) ? a.copyWith(label: custom) : a;
    }).toList();



    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _wallpaperAccent = wallpaper;
      _useWallpaperAccent = prefs.useWallpaperAccent;
      _customAccent = prefs.customAccent;
      _hasCompletedIntro = prefs.hasCompletedIntro;
      _hiddenAppIds = prefs.hiddenAppIds;
      _selectedIconPack = pack;
      _customIconMap = customIcons;
      _customLabelMap = prefs.customLabelMap;
      _drawerIsList = prefs.drawerIsList;
      _drawerMode = prefs.drawerMode;
      _sortMode = prefs.sortMode;
      _recentAppIds = prefs.recentAppIds;
      _autoFocusSearch = prefs.autoFocusSearch;
      _searchIncludesHidden = prefs.searchIncludesHidden;
      _ambientIdleMode = prefs.ambientIdleMode;
      _ambientTimeoutSeconds = prefs.ambientTimeoutSeconds;
      _ambientStyle = prefs.ambientStyle;
      _ambientLockEnabled = prefs.ambientLockEnabled;
      _ambientLockPin = prefs.ambientLockPin;
      _ambientCustomText = prefs.ambientCustomText;
      _profileName = prefs.profileName;
      _profilePhoto = prefs.profilePhoto;
      _availableIconPacks = iconPacks;
      _allApps = apps;
      _quickIds = _normalizeQuick(prefs.quickAppIds);
      _dockIds = _normalizeDock(prefs.dockAppIds);
      _pinnedQuickTasks = prefs.pinnedQuickTasks;
      _isInitialized = true;
    });

    _resetIdleTimer();
    _startMediaPolling();
    _startBatteryPolling();
    _loadShortcuts();
    _pkgSub = _platform.packageChanges.listen((_) {
      _reloadApps();
      _loadShortcuts();
    });
  }

  Future<void> _loadShortcuts() async {
    final shortcuts = await _platform.getAppShortcuts();
    if (!mounted) return;
    setState(() => _allShortcuts = shortcuts);
  }

  void _onBackupRestored() async {
    if (_prefs == null) return;
    setState(() {
      _customAccent = _prefs!.customAccent;
      _useWallpaperAccent = _prefs!.useWallpaperAccent;
      _drawerMode = _prefs!.drawerMode;
      _drawerIsList = _prefs!.drawerIsList;
      _autoFocusSearch = _prefs!.autoFocusSearch;
      _searchIncludesHidden = _prefs!.searchIncludesHidden;
      _ambientIdleMode = _prefs!.ambientIdleMode;
      _ambientTimeoutSeconds = _prefs!.ambientTimeoutSeconds;
      _ambientStyle = _prefs!.ambientStyle;
      _ambientLockEnabled = _prefs!.ambientLockEnabled;
      _ambientLockPin = _prefs!.ambientLockPin;
      _ambientCustomText = _prefs!.ambientCustomText;
      _profileName = _prefs!.profileName;
      _profilePhoto = _prefs!.profilePhoto;
      _quickIds = _normalizeQuick(_prefs!.quickAppIds);
      _dockIds = _normalizeDock(_prefs!.dockAppIds);
      _pinnedQuickTasks = _prefs!.pinnedQuickTasks;
      _hiddenAppIds = _prefs!.hiddenAppIds;
      _selectedIconPack = _prefs!.selectedIconPack;
      _customLabelMap = _prefs!.customLabelMap;
      _customIconMap = _prefs!.customIconMap;
    });
    _reloadApps();
    _loadShortcuts();
  }

  void _startBatteryPolling() {
    _batteryPollTimer?.cancel();
    _syncBattery();
    _batteryPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _syncBattery();
    });
  }

  Future<void> _syncBattery() async {
    final battery = await _platform.getBattery();
    if (!mounted || battery == null) return;
    if (battery.level != _batteryLevel || battery.charging != _isCharging) {
      setState(() {
        _batteryLevel = battery.level;
        _isCharging = battery.charging;
      });
    }
  }

  void _startMediaPolling() {
    _mediaPollTimer?.cancel();
    _checkMediaTrack();
    _mediaPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkMediaTrack();
    });
  }

  Future<void> _checkMediaTrack() async {
    final track = await _platform.getMediaTrack();
    if (!mounted) return;

    final title = track?['title'] as String?;
    if (track == null || title == null || title.isEmpty) {
      if (_mediaTitle != null || _mediaPackageName != null) {
        setState(() {
          _mediaTitle = null;
          _mediaArtist = null;
          _mediaPackageName = null;
          _mediaAlbumArt = null;
          _mediaIsPlaying = false;
          _mediaArtId = null;
        });
      }
      return;
    }

    final artist = (track['artist'] as String?) ?? '';
    final packageName = (track['packageName'] as String?) ?? '';
    final isPlaying = track['isPlaying'] == true;
    final artId = track['artId'] as int?;

    // The native side only sends album art bytes when the artwork changed; otherwise the
    // previously decoded image is kept so it is not decoded again on every poll.
    var albumArt = _mediaAlbumArt;
    final rawArt = track['albumArt'];
    if (rawArt is Uint8List) {
      albumArt = rawArt.isEmpty ? null : rawArt;
    } else if (rawArt is List) {
      final bytes = Uint8List.fromList(rawArt.cast<int>());
      albumArt = bytes.isEmpty ? null : bytes;
    } else if (artId == null || artId != _mediaArtId) {
      albumArt = null;
    }

    if (title != _mediaTitle ||
        artist != _mediaArtist ||
        packageName != _mediaPackageName ||
        isPlaying != _mediaIsPlaying ||
        artId != _mediaArtId) {
      setState(() {
        _mediaTitle = title;
        _mediaArtist = artist;
        _mediaPackageName = packageName;
        _mediaAlbumArt = albumArt;
        _mediaIsPlaying = isPlaying;
        _mediaArtId = artId;
      });
    }
  }

  bool get _hasAmbientPin =>
      _ambientLockEnabled &&
      _ambientLockPin != null &&
      _ambientLockPin!.isNotEmpty;

  void _setIdle(bool idle, {bool showKeypad = false}) {
    if (_isIdle != idle) {
      _platform.setWindowDim(idle);
    }
    setState(() {
      _isIdle = idle;
      _isAmbientKeypadShown = idle ? showKeypad : false;
    });
  }

  void _onUserInteraction() {
    if (_isIdle) {
      if (_hasAmbientPin) {
        if (!_isAmbientKeypadShown && mounted) {
          setState(() => _isAmbientKeypadShown = true);
        }
        return;
      }
      if (mounted) {
        _setIdle(false);
      }
    }
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_ambientIdleMode || _isPanelExpanded || _isDashboardOpen) {
      return;
    }
    _idleTimer = Timer(Duration(seconds: _ambientTimeoutSeconds), () {
      if (!mounted) return;
      if (!_isPanelExpanded && !_isDashboardOpen && _ambientIdleMode) {
        _setIdle(true);
      }
    });
  }

  Future<void> _reloadApps() async {
    final apps = await _platform.getApps(
      iconPack: _selectedIconPack,
      customIconMap: _customIconMap,
    );
    if (!mounted) return;
    final labels = _prefs?.customLabelMap ?? _customLabelMap;
    final mappedApps = apps.map((a) {
      final custom = labels[a.id];
      return (custom != null && custom.isNotEmpty) ? a.copyWith(label: custom) : a;
    }).toList();
    setState(() {
      _customLabelMap = labels;
      _allApps = mappedApps;
    });
  }

  void _resetHome() {
    if (!mounted) return;
    _hideStatusBar();
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (!_hasAmbientPin && _isIdle) {
      _platform.setWindowDim(false);
    }
    setState(() {
      _isDraggingDashboard = false;
      _drawerDragT = null;
      _dashboardDragOffset = 0.0;
      _isPanelExpanded = false;
      _isDashboardOpen = false;
      if (!_hasAmbientPin) {
        _isIdle = false;
        _isAmbientKeypadShown = false;
      }
    });
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _platform.setWindowDim(false);
    _idleTimer?.cancel();
    _mediaPollTimer?.cancel();
    _batteryPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pkgSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleHideApp(AppItem app) async {
    final current = Set<String>.from(_hiddenAppIds);
    if (current.contains(app.id)) {
      current.remove(app.id);
    } else {
      current.add(app.id);
    }
    setState(() => _hiddenAppIds = current);
    await _prefs?.setHiddenAppIds(current);
  }

  void _hideDashboard() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDraggingDashboard = false;
      _drawerDragT = null;
      _dashboardDragOffset = 0.0;
      _isDashboardOpen = false;
    });
    _resetIdleTimer();
  }

  void _showRenameDialog(AppItem app) {
    final controller = TextEditingController(text: app.label);
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename app', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: _effectiveAccent,
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _effectiveAccent.withValues(alpha: 0.5))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _effectiveAccent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == app.label) {
                await _prefs?.resetCustomLabel(app.id);
              } else {
                await _prefs?.setCustomLabel(app.id, newName);
              }
              _reloadApps();
            },
            child: Text('Save', style: TextStyle(color: _effectiveAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _setPinnedQuickTasks(List<PinnedQuickTask> tasks) async {
    final capped = tasks.take(maxPinnedQuickTasks).toList();
    setState(() => _pinnedQuickTasks = capped);
    await _prefs?.setPinnedQuickTasks(capped);
  }

  Future<void> _togglePinShortcut(AppShortcut s) async {
    final key = '${s.packageName}/${s.id}';
    final current = List<PinnedQuickTask>.from(_pinnedQuickTasks);
    final existingIdx = current.indexWhere((t) => t.key == key);
    if (existingIdx >= 0) {
      current.removeAt(existingIdx);
      await _setPinnedQuickTasks(current);
      return;
    }
    if (current.length >= maxPinnedQuickTasks) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Up to 2 quick tasks can be pinned. Unpin one first.'),
        ),
      );
      return;
    }
    current.add(
      PinnedQuickTask(
        packageName: s.packageName,
        shortcutId: s.id,
        label: s.displayLabel,
      ),
    );
    await _setPinnedQuickTasks(current);
  }

  Future<void> _pickQuickTask({int? replaceIndex}) async {
    if (_allShortcuts.isEmpty) {
      await _loadShortcuts();
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => QuickTaskPickerSheet(
        shortcuts: _allShortcuts,
        apps: _visibleApps,
        accent: _effectiveAccent,
        pinnedKeys: _pinnedQuickTasks.map((t) => t.key).toSet(),
        onSelected: (shortcut) {
          Navigator.pop(sheetCtx);
          final next = PinnedQuickTask(
            packageName: shortcut.packageName,
            shortcutId: shortcut.id,
            label: shortcut.displayLabel,
          );
          final updated = List<PinnedQuickTask>.from(_pinnedQuickTasks);
          updated.removeWhere((t) => t.key == next.key);
          if (replaceIndex != null && replaceIndex < updated.length) {
            updated[replaceIndex] = next;
          } else if (updated.length < maxPinnedQuickTasks) {
            updated.add(next);
          } else {
            updated[maxPinnedQuickTasks - 1] = next;
          }
          _setPinnedQuickTasks(updated);
        },
      ),
    );
  }

  void _showQuickTaskMenu(int index, PinnedQuickTask task) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.swap_horiz_rounded, color: _effectiveAccent),
                title: const Text('Replace quick task', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickQuickTask(replaceIndex: index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined, color: LauncherColors.danger),
                title: const Text('Unpin from home', style: TextStyle(color: LauncherColors.danger)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  final updated = List<PinnedQuickTask>.from(_pinnedQuickTasks)
                    ..removeAt(index);
                  _setPinnedQuickTasks(updated);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppActions(AppItem app) {
    final isQuickPinned = _quickIds.contains(app.id);
    final isQuickFull = _quickSlots.every((a) => a != null);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => AppActionsSheet(
        app: app,
        platform: _platform,
        accent: _effectiveAccent,
        isQuickPinned: isQuickPinned,
        isQuickFull: isQuickFull,
        onShortcutTap: (s) {
          _platform.startShortcut(s.packageName, s.id);
        },
        pinnedTaskKeys: _pinnedQuickTasks.map((t) => t.key).toSet(),
        onTogglePinShortcut: _togglePinShortcut,
        onRenameApp: () {
          Navigator.pop(sheetCtx);
          _showRenameDialog(app);
        },
        onToggleQuick: () {
          Navigator.pop(sheetCtx);
          _toggleQuick(app);
        },
        onChangeIcon: () {
          Navigator.pop(sheetCtx);
          _showIconPicker(app);
        },
        onHideApp: () {
          Navigator.pop(sheetCtx);
          _toggleHideApp(app);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${app.label} hidden from home'),
              action: SnackBarAction(
                label: 'Undo',
                textColor: _effectiveAccent,
                onPressed: () => _toggleHideApp(app),
              ),
            ),
          );
        },
        onAppInfo: () {
          Navigator.pop(sheetCtx);
          _platform.openAppInfo(app);
        },
        onUninstall: () {
          Navigator.pop(sheetCtx);
          _platform.uninstall(app);
        },
      ),
    );
  }

  void _showIconPicker(AppItem app) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => IconPickerSheet(
        app: app,
        accent: _effectiveAccent,
        platform: _platform,
        availableIconPacks: _availableIconPacks,
        onSelectIcon: (packPackage, drawableName) async {
          await _prefs?.setCustomIcon(app.id, '$packPackage/$drawableName');
          if (!mounted) return;
          setState(() {
            _customIconMap = _prefs?.customIconMap ?? {};
          });
          _reloadApps();
        },
        onResetIcon: () async {
          await _prefs?.resetCustomIcon(app.id);
          if (!mounted) return;
          setState(() {
            _customIconMap = _prefs?.customIconMap ?? {};
          });
          _reloadApps();
        },
      ),
    );
  }

  void _launchApp(AppItem app) {
    _platform.launch(app);
    _prefs?.addRecentApp(app.id);
    if (mounted) {
      setState(() {
        _recentAppIds = _prefs?.recentAppIds ?? _recentAppIds;
      });
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    final wasIdle = _isIdle;
    _onUserInteraction();
    if (wasIdle || _isPanelExpanded || _dragPointer != null) return;
    _dragPointer = e.pointer;
    _dragOrigin = e.position;
    _dragClaimed = false;
    _velocityTracker = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
  }

  void _onPointerMove(PointerMoveEvent e) {
    _onUserInteraction();
    if (e.pointer != _dragPointer) return;
    _velocityTracker?.addPosition(e.timeStamp, e.position);
    final d = e.position - _dragOrigin;
    final drawerTravel = _maxH > 0 ? _maxH : 800.0;
    if (!_dragClaimed) {
      if (d.dy.abs() > 18 && d.dy.abs() > d.dx.abs() * 1.5) {
        _dragClaimed = true;
        _dragOrigin = e.position;
        _dragStartPos = _isDashboardOpen ? _dashboardTravel : 0.0;
      } else {
        return;
      }
    }
    final pos = (_dragStartPos + (e.position.dy - _dragOrigin.dy))
        .clamp(-drawerTravel, _dashboardTravel);
    setState(() {
      _isDraggingDashboard = true;
      _dashboardDragOffset = pos > 0 ? pos : 0.0;
      _drawerDragT = (!_isDashboardOpen && pos < 0) ? (-pos / drawerTravel) : 0.0;
    });
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer != _dragPointer) return;
    final claimed = _dragClaimed;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final drawerTravel = _maxH > 0 ? _maxH : 800.0;
    _dragPointer = null;
    _velocityTracker = null;
    _dragClaimed = false;
    if (!claimed) return;

    final pos = _dashboardDragOffset > 0
        ? _dashboardDragOffset
        : -(_drawerDragT ?? 0) * drawerTravel;
    int target;
    if (velocity > 300) {
      target = pos < 0 ? 0 : 1;
    } else if (velocity < -300) {
      target = pos > 0 ? 0 : -1;
    } else if (pos > _dashboardTravel * 0.35) {
      target = 1;
    } else if (pos < -drawerTravel * 0.16) {
      target = -1;
    } else {
      target = 0;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isDraggingDashboard = false;
      _drawerDragT = null;
      if (_isDashboardOpen && target != 1) {
        _isDashboardOpen = false;
        _dashboardDragOffset = 0.0;
      } else {
        _isDashboardOpen = target == 1;
        _isPanelExpanded = target == -1;
        _dashboardDragOffset = target == 1 ? _dashboardTravel : 0.0;
      }
    });
    _resetIdleTimer();
  }

  void _openCalendar() {
    _platform.openCalendar();
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => SettingsPage(
          accent: _effectiveAccent,
          useWallpaperAccent: _useWallpaperAccent,
          wallpaperAccent: _wallpaperAccent,
          allApps: _allApps,
          hiddenAppIds: _hiddenAppIds,
          availableIconPacks: _availableIconPacks,
          selectedIconPack: _selectedIconPack,
          drawerIsList: _drawerIsList,
          drawerMode: _drawerMode,
          autoFocusSearch: _autoFocusSearch,
          searchIncludesHidden: _searchIncludesHidden,
          ambientIdleMode: _ambientIdleMode,
          ambientTimeoutSeconds: _ambientTimeoutSeconds,
          ambientStyle: _ambientStyle,
          ambientLockEnabled: _ambientLockEnabled,
          ambientLockPin: _ambientLockPin,
          ambientCustomText: _ambientCustomText,
          profileName: _profileName,
          profilePhoto: _profilePhoto,
          quickAppCount: _quickIds.where((id) => id.isNotEmpty).length,
          pinnedQuickTasks: _pinnedQuickTasks,
          allShortcuts: _allShortcuts,
          onPinnedQuickTasksChanged: _setPinnedQuickTasks,
          prefs: _prefs,
          platform: _platform,
          onBackupRestored: _onBackupRestored,
          onProfileNameChanged: (name) async {
            if (!mounted) return;
            setState(() => _profileName = name);
            await _prefs?.setProfileName(name);
          },
          onProfilePhotoChanged: (bytes) async {
            if (!mounted) return;
            setState(() => _profilePhoto = bytes);
            await _prefs?.setProfilePhoto(bytes);
          },
          onSelectCustomAccent: (color) {
            if (!mounted) return;
            setState(() {
              _useWallpaperAccent = false;
              _customAccent = color;
            });
            _prefs?.setCustomAccent(color);
          },
          onSelectWallpaperAccent: () {
            if (!mounted) return;
            setState(() => _useWallpaperAccent = true);
            _prefs?.setUseWallpaperAccent();
          },
          onToggleHideApp: _toggleHideApp,
          onSelectIconPack: (pack) async {
            if (!mounted) return;
            setState(() => _selectedIconPack = pack);
            await _prefs?.setSelectedIconPack(pack);
            _reloadApps();
          },
          onToggleDrawerIsList: (isList) async {
            if (!mounted) return;
            setState(() {
              _drawerIsList = isList;
              _drawerMode = isList ? DrawerMode.list : DrawerMode.grid;
            });
            await _prefs?.setDrawerIsList(isList);
          },
          onSelectDrawerMode: (mode) async {
            if (!mounted) return;
            setState(() {
              _drawerMode = mode;
              _drawerIsList = mode == DrawerMode.list;
            });
            await _prefs?.setDrawerMode(mode);
          },
          onToggleAutoFocusSearch: (val) async {
            if (!mounted) return;
            setState(() => _autoFocusSearch = val);
            await _prefs?.setAutoFocusSearch(val);
          },
          onToggleSearchIncludesHidden: (val) async {
            if (!mounted) return;
            setState(() => _searchIncludesHidden = val);
            await _prefs?.setSearchIncludesHidden(val);
          },
          onToggleAmbientIdleMode: (val) async {
            if (!mounted) return;
            setState(() => _ambientIdleMode = val);
            await _prefs?.setAmbientIdleMode(val);
            _resetIdleTimer();
          },
          onAmbientTimeoutChanged: (seconds) async {
            if (!mounted) return;
            setState(() => _ambientTimeoutSeconds = seconds);
            await _prefs?.setAmbientTimeoutSeconds(seconds);
            _resetIdleTimer();
          },
          onAmbientStyleChanged: (style) async {
            if (!mounted) return;
            setState(() => _ambientStyle = style);
            await _prefs?.setAmbientStyle(style);
          },
          onToggleAmbientLock: (val) async {
            if (!mounted) return;
            setState(() => _ambientLockEnabled = val);
            await _prefs?.setAmbientLockEnabled(val);
          },
          onAmbientLockPinChanged: (pin) async {
            if (!mounted) return;
            setState(() => _ambientLockPin = pin);
            await _prefs?.setAmbientLockPin(pin);
          },
          onAmbientCustomTextChanged: (text) async {
            if (!mounted) return;
            setState(() => _ambientCustomText = text);
            await _prefs?.setAmbientCustomText(text);
          },
          onOpenHomeSettings: _platform.openHomeSettings,
          onOpenNotificationListenerSettings: _platform.openNotificationListenerSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: LauncherColors.background,
        body: Center(child: SizedBox.shrink()),
      );
    }

    // First-run experience: Show Intro Flow and accent picker
    if (!_hasCompletedIntro) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: IntroFlow(
          initialAccent: _effectiveAccent,
          wallpaperAccent: _wallpaperAccent,
          onOpenHomeSettings: _platform.openHomeSettings,
          onComplete: (chosenAccent) async {
            final isWallpaper = _wallpaperAccent != null &&
                chosenAccent.toARGB32() == _wallpaperAccent!.toARGB32();
            if (isWallpaper) {
              await _prefs?.setUseWallpaperAccent();
            } else {
              await _prefs?.setCustomAccent(chosenAccent);
            }
            await _prefs?.setCompletedIntro(true);

            if (!mounted) return;
            setState(() {
              _useWallpaperAccent = isWallpaper;
              _customAccent = chosenAccent;
              _hasCompletedIntro = true;
            });
          },
        ),
      );
    }

    final padding = MediaQuery.paddingOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (_isIdle && _isAmbientKeypadShown) {
          setState(() => _isAmbientKeypadShown = false);
        } else if (_isDashboardOpen) {
          _hideDashboard();
        } else if (_isPanelExpanded) {
          setState(() => _isPanelExpanded = false);
        }
      },
      child: Scaffold(
        body: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            final metrics = TileMetrics.forWidth(maxW);
            final dockHeight = padding.bottom;

            _maxH = maxH;
            final drawerT = (_drawerDragT ?? (_isPanelExpanded ? 1.0 : 0.0)).clamp(0.0, 1.0);
            final dashboardT = _isDraggingDashboard
                ? (_dashboardDragOffset / _dashboardTravel).clamp(0.0, 1.0)
                : (_isDashboardOpen ? 1.0 : 0.0);

            final double clockTop;
            if (_isIdle) {
              if (_isAmbientKeypadShown) {
                clockTop = _ambientStyle == AmbientStyle.bigClock
                    ? (padding.top + 14.0)
                    : (maxH * 0.14);
              } else {
                clockTop = _ambientStyle == AmbientStyle.bigClock
                    ? (maxH * 0.14)
                    : (maxH * 0.44);
              }
            } else {
              clockTop = padding.top + 18.0;
            }

            final topGlowOpacity = _isIdle ? 0.0 : dashboardT * (1.0 - drawerT);

            final clockVisible = !(_isPanelExpanded && _drawerDragT == null);
            final clockOpacity = _isIdle
                ? 1.0
                : (clockVisible
                    ? ((1.0 - drawerT * 1.6) * (1.0 - dashboardT * 1.4)).clamp(0.0, 1.0)
                    : 0.0);

            final dockVisible =
                !_isIdle &&
                !_isDashboardOpen &&
                !(_isPanelExpanded && _drawerDragT == null);
            final dockOpacity = dockVisible
                ? ((1.0 - drawerT * 2.0) * (1.0 - dashboardT * 1.6))
                    .clamp(0.0, 1.0)
                : 0.0;

            final keypadVisible = _isIdle && _isAmbientKeypadShown && _hasAmbientPin;

            final animDuration = _isDraggingDashboard
                ? Duration.zero
                : M3Motion.slowSpatial.duration;
            final panelBottom = _isIdle
                ? -maxH
                : -maxH * (1.0 - drawerT);

            return Stack(
              children: [
                // Pure black wallpaper; tap collapses dashboard, long-press opens Settings
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_isDashboardOpen) {
                        _hideDashboard();
                      }
                    },
                    onLongPress: () {
                      if (_isIdle) return;
                      HapticFeedback.mediumImpact();
                      _openSettingsPage();
                    },
                    child: const ColoredBox(color: LauncherColors.background),
                  ),
                ),

                // Subtle radial glow at the top when Dashboard is swiped down
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: maxH * 0.62,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: _isDraggingDashboard
                          ? Duration.zero
                          : M3Motion.defaultEffects.duration,
                      curve: M3Motion.defaultEffects,
                      opacity: topGlowOpacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.0, -1.25),
                            radius: 1.35,
                            colors: [
                              _effectiveAccent.withValues(alpha: 0.42),
                              _effectiveAccent.withValues(alpha: 0.20),
                              _effectiveAccent.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.38, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Subtle bottom ambient glow behind the dock or ambient lock keypad
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: keypadVisible ? 420 : 380,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: _isDraggingDashboard
                          ? Duration.zero
                          : M3Motion.defaultEffects.duration,
                      curve: M3Motion.defaultEffects,
                      opacity: keypadVisible ? 1.0 : dockOpacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.0, 1.05),
                            radius: 0.90,
                            colors: [
                              _effectiveAccent.withValues(alpha: 0.28),
                              _effectiveAccent.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.42, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Clock area: 3-pill Pixel Watch clock (or Ambient Mode)
                AnimatedPositioned(
                  duration: animDuration,
                  curve: M3Motion.slowSpatial,
                  top: clockTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !clockVisible || _isIdle || dashboardT > 0.2,
                    child: AnimatedScale(
                      scale: _isIdle ? 1.0 : (1.0 - 0.10 * dashboardT),
                      duration: _isDraggingDashboard
                          ? Duration.zero
                          : M3Motion.defaultSpatial.duration,
                      curve: M3Motion.defaultSpatial,
                      child: AnimatedOpacity(
                        opacity: clockOpacity,
                        duration: _isDraggingDashboard
                            ? Duration.zero
                            : M3Motion.defaultEffects.duration,
                        curve: M3Motion.defaultEffects,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: LauncherClock(
                            accent: _effectiveAccent,
                            batteryLevel: _batteryLevel,
                            isCharging: _isCharging,
                            onTap: _platform.openAlarms,
                            onDateTap: _openCalendar,
                            onSettingsTap: _openSettingsPage,
                            isIdle: _isIdle,
                            ambientStyle: _ambientStyle,
                            isCompactForKeypad: _isAmbientKeypadShown,
                            mediaTitle: _mediaTitle,
                            mediaArtist: _mediaArtist,
                            mediaIsPlaying: _mediaIsPlaying,
                            customAmbientText: _ambientCustomText,
                            onMediaTap: () {
                              if (_allApps.isEmpty) return;
                              AppItem? target;
                              if (_mediaPackageName != null &&
                                  _mediaPackageName!.isNotEmpty) {
                                for (final a in _allApps) {
                                  if (a.packageName == _mediaPackageName) {
                                    target = a;
                                    break;
                                  }
                                }
                              }
                              target ??= _allApps.firstWhere(
                                (a) =>
                                    a.packageName.contains('music') ||
                                    a.packageName.contains('spotify') ||
                                    a.packageName.contains('audio'),
                                orElse: () => _allApps.first,
                              );
                              _launchApp(target);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Top-half Dashboard revealed when swiping down on home screen
                Positioned(
                  top: padding.top + 18,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: _isIdle || dashboardT < 0.2 || drawerT > 0.1,
                    child: AnimatedSlide(
                      offset: Offset(0, -0.06 * (1.0 - dashboardT)),
                      duration: _isDraggingDashboard
                          ? Duration.zero
                          : M3Motion.defaultSpatial.duration,
                      curve: M3Motion.defaultSpatial,
                      child: AnimatedScale(
                        scale: 0.94 + 0.06 * dashboardT,
                        alignment: Alignment.topCenter,
                        duration: _isDraggingDashboard
                            ? Duration.zero
                            : M3Motion.defaultSpatial.duration,
                        curve: M3Motion.defaultSpatial,
                        child: AnimatedOpacity(
                          opacity: _isIdle
                              ? 0.0
                              : (dashboardT * (1.0 - drawerT * 2.0)).clamp(0.0, 1.0),
                          duration: _isDraggingDashboard
                              ? Duration.zero
                              : M3Motion.defaultEffects.duration,
                          curve: M3Motion.defaultEffects,
                          child: ProfileDashboard(
                            accent: _effectiveAccent,
                            platform: _platform,
                            name: _profileName,
                            photo: _profilePhoto,
                            batteryLevel: _batteryLevel,
                            isCharging: _isCharging,
                            pinnedTasks: _pinnedQuickTasks,
                            shortcuts: _allShortcuts,
                            onTaskTap: (task) {
                              _platform.startShortcut(
                                task.packageName,
                                task.shortcutId,
                              );
                            },
                            onTaskLongPress: _showQuickTaskMenu,
                            onAddTaskTap: () => _pickQuickTask(),
                            onPowerTap: () {
                              setState(() {
                                _isDashboardOpen = false;
                                _dashboardDragOffset = 0.0;
                              });
                              _setIdle(true);
                            },
                            onCollapse: _hideDashboard,
                            onSettingsTap: _openSettingsPage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Ambient Lock Keypad (slides up with M3 slowSpatial spring)
                AnimatedPositioned(
                  duration: M3Motion.slowSpatial.duration,
                  curve: M3Motion.slowSpatial,
                  left: 0,
                  right: 0,
                  bottom: keypadVisible ? (padding.bottom + 56) : -440,
                  child: IgnorePointer(
                    ignoring: !keypadVisible,
                    child: AnimatedOpacity(
                      duration: M3Motion.defaultEffects.duration,
                      curve: M3Motion.defaultEffects,
                      opacity: keypadVisible ? 1.0 : 0.0,
                      child: Center(
                        child: AmbientLockKeypad(
                          accent: _effectiveAccent,
                          expectedPin: _ambientLockPin ?? '',
                          isVisible: keypadVisible,
                          onUnlocked: () {
                            _setIdle(false);
                            _resetIdleTimer();
                          },
                          onCancel: () {
                            setState(() => _isAmbientKeypadShown = false);
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Continuous one-by-one swipable Dock at the bottom
                AnimatedPositioned(
                  duration: _isDraggingDashboard ? Duration.zero : animDuration,
                  curve: M3Motion.slowSpatial,
                  left: 0,
                  right: 0,
                  bottom: dockVisible
                      ? (padding.bottom + 18 - 140 * dashboardT)
                      : -140,
                  child: IgnorePointer(
                    ignoring: !dockVisible || drawerT > 0.2 || dashboardT > 0.2,
                    child: AnimatedOpacity(
                      duration: _isDraggingDashboard
                          ? Duration.zero
                          : M3Motion.defaultEffects.duration,
                      curve: M3Motion.defaultEffects,
                      opacity: dockOpacity,
                      child: LauncherDock(
                        slots: _dockSlots,
                        accent: _effectiveAccent,
                        onAppTap: _launchApp,
                        onAppLongPress: _showDockSlotMenu,
                        onEmptySlotTap: _pickDockApp,
                      ),
                    ),
                  ),
                ),

                // Expandable full-screen app drawer (slides up on swipe up)
                AnimatedPositioned(
                  duration: _isDraggingDashboard ? Duration.zero : M3Motion.slowSpatial.duration,
                  curve: M3Motion.slowSpatial,
                  left: 0,
                  right: 0,
                  bottom: panelBottom,
                  height: maxH,
                  child: IgnorePointer(
                    ignoring: !_isPanelExpanded && drawerT == 0.0,
                    child: AnimatedOpacity(
                      duration: _isDraggingDashboard
                          ? Duration.zero
                          : M3Motion.defaultEffects.duration,
                      curve: M3Motion.defaultEffects,
                      opacity: (_isPanelExpanded || drawerT > 0.02) ? 1.0 : 0.0,
                      child: AppPanel(
                        apps: _visibleApps,
                        allApps: _allApps,
                        metrics: metrics,
                        dockHeight: dockHeight,
                        isExpanded: _isPanelExpanded,
                        isListMode: _drawerIsList,
                        drawerMode: _drawerMode,
                        onDrawerModeChanged: (mode) async {
                          setState(() {
                            _drawerMode = mode;
                            _drawerIsList = mode == DrawerMode.list;
                          });
                          await _prefs?.setDrawerMode(mode);
                        },
                        autoFocusSearch: _autoFocusSearch,
                        searchIncludesHidden: _searchIncludesHidden,
                        isIdle: _isIdle,
                        recentAppIds: _recentAppIds,
                        sortMode: _sortMode,
                        onSortModeChanged: (mode) async {
                          setState(() => _sortMode = mode);
                          await _prefs?.setSortMode(mode);
                        },
                        accent: _effectiveAccent,
                        shortcuts: _allShortcuts,
                        mediaPackageName: _mediaPackageName,
                        mediaTitle: _mediaTitle,
                        mediaArtist: _mediaArtist,
                        mediaAlbumArt: _mediaAlbumArt,
                        mediaIsPlaying: _mediaIsPlaying,
                        onShortcutTap: (s) {
                          _platform.startShortcut(s.packageName, s.id);
                        },
                        onExpandedChanged: (expanded) {
                          if (_isDashboardOpen) {
                            _hideDashboard();
                          }
                          setState(() => _isPanelExpanded = expanded);
                        },
                        onAppTap: _launchApp,
                        onAppLongPress: _showAppActions,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }
}
