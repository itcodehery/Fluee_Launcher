import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/app_item.dart';
import 'services/launcher_platform.dart';
import 'services/launcher_preferences.dart';
import 'theme/launcher_colors.dart';
import 'widgets/app_actions_sheet.dart';
import 'widgets/app_panel.dart';
import 'widgets/app_tile.dart';
import 'widgets/dock.dart';
import 'widgets/icon_picker_sheet.dart';
import 'widgets/intro_flow.dart';
import 'widgets/launcher_clock.dart';
import 'widgets/quick_settings_watch.dart';
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
  List<String> _dockIds = const [];
  List<IconPackInfo> _availableIconPacks = const [];
  String? _selectedIconPack;
  Map<String, String> _customIconMap = const {};
  bool _drawerIsList = false;
  DrawerMode _drawerMode = DrawerMode.grid;
  bool _autoFocusSearch = false;
  bool _searchIncludesHidden = false;
  bool _ambientIdleMode = true;
  bool _isIdle = false;
  Timer? _idleTimer;
  Timer? _mediaPollTimer;
  String? _mediaTitle;
  String? _mediaArtist;

  Color _customAccent = LauncherColors.defaultAccent;
  Color? _wallpaperAccent;
  bool _useWallpaperAccent = false;
  String? _customWallpaperPath;
  bool _isPanelExpanded = false;
  bool _isQuickSettingsOpen = false;
  bool _hasCompletedIntro = true;
  bool _isInitialized = false;

  Color get _effectiveAccent =>
      (_useWallpaperAccent && _wallpaperAccent != null)
          ? _wallpaperAccent!
          : _customAccent;

  List<AppItem> get _visibleApps =>
      _allApps.where((a) => !_hiddenAppIds.contains(a.id)).toList();

  List<AppItem> get _dockApps {
    final byId = {for (final a in _allApps) a.id: a};
    return _dockIds
        .map((id) => byId[id])
        .whereType<AppItem>()
        .take(maxDockApps)
        .toList();
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
    }
  }

  Future<void> _init() async {
    final prefs = await LauncherPreferences.load();
    final wallpaper = await _platform.getWallpaperAccent();
    final iconPacks = await _platform.getIconPacks();

    final pack = prefs.selectedIconPack;
    final customIcons = prefs.customIconMap;
    final apps = await _platform.getApps(iconPack: pack, customIconMap: customIcons);

    var dockIds = prefs.dockIds;
    if (dockIds == null && apps.isNotEmpty) {
      dockIds = _pickDefaultDock(apps);
      await prefs.setDockIds(dockIds);
    }

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _wallpaperAccent = wallpaper;
      _useWallpaperAccent = prefs.useWallpaperAccent;
      _customAccent = prefs.customAccent;
      _hasCompletedIntro = prefs.hasCompletedIntro;
      _hiddenAppIds = prefs.hiddenAppIds;
      _customWallpaperPath = prefs.customWallpaperPath;
      _selectedIconPack = pack;
      _customIconMap = customIcons;
      _drawerIsList = prefs.drawerIsList;
      _drawerMode = prefs.drawerMode;
      _autoFocusSearch = prefs.autoFocusSearch;
      _searchIncludesHidden = prefs.searchIncludesHidden;
      _ambientIdleMode = prefs.ambientIdleMode;
      _availableIconPacks = iconPacks;
      _allApps = apps;
      _dockIds = dockIds ?? const [];
      _isInitialized = true;
    });

    _resetIdleTimer();
    _startMediaPolling();
    _pkgSub = _platform.packageChanges.listen((_) => _reloadApps());
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
    if (track != null) {
      final title = track['title'] as String?;
      final artist = track['artist'] as String?;
      if (title != _mediaTitle || artist != _mediaArtist) {
        setState(() {
          _mediaTitle = title;
          _mediaArtist = artist;
        });
      }
    } else if (_mediaTitle != null) {
      setState(() {
        _mediaTitle = null;
        _mediaArtist = null;
      });
    }
  }

  void _onUserInteraction([_]) {
    if (_isIdle) {
      if (mounted) {
        setState(() => _isIdle = false);
      }
    }
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_ambientIdleMode || _isPanelExpanded || _isQuickSettingsOpen) {
      return;
    }
    // Idle threshold between 7-9 seconds (8 seconds)
    _idleTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (!_isPanelExpanded && !_isQuickSettingsOpen && _ambientIdleMode) {
        setState(() => _isIdle = true);
      }
    });
  }

  Future<void> _reloadApps() async {
    final apps = await _platform.getApps(
      iconPack: _selectedIconPack,
      customIconMap: _customIconMap,
    );
    if (!mounted) return;
    setState(() => _allApps = apps);
  }

  void _resetHome() {
    if (!mounted) return;
    _hideStatusBar();
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _isPanelExpanded = false;
      _isQuickSettingsOpen = false;
      _isIdle = false;
    });
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _mediaPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pkgSub?.cancel();
    super.dispose();
  }

  List<String> _pickDefaultDock(List<AppItem> apps) {
    const groups = [
      ['dialer', 'contacts', 'phone'],
      ['messaging', 'mms', 'message'],
      ['camera'],
      ['chrome', 'browser', 'firefox'],
    ];
    final picked = <String>[];
    for (final group in groups) {
      final match = apps.cast<AppItem?>().firstWhere(
            (app) =>
                app != null &&
                !picked.contains(app.id) &&
                group.any((p) =>
                    app.packageName.toLowerCase().contains(p) ||
                    app.activityName.toLowerCase().contains(p)),
            orElse: () => null,
          );
      if (match != null) picked.add(match.id);
    }
    for (final app in apps) {
      if (picked.length >= maxDockApps) break;
      if (!picked.contains(app.id)) picked.add(app.id);
    }
    return picked.take(maxDockApps).toList();
  }

  Future<void> _reorderDock(int oldIndex, int newIndex) async {
    final current = List<String>.from(_dockIds);
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex >= current.length) {
      return;
    }
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    setState(() => _dockIds = current);
    await _prefs?.setDockIds(current);
  }

  Future<void> _togglePin(AppItem app) async {
    final installed = _allApps.map((a) => a.id).toSet();
    final current = _dockIds.where(installed.contains).toList();
    if (current.contains(app.id)) {
      current.remove(app.id);
    } else if (current.length < maxDockApps) {
      current.add(app.id);
    }
    setState(() => _dockIds = current);
    await _prefs?.setDockIds(current);
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

  Future<void> _handleDoubleTapToLock() async {
    HapticFeedback.mediumImpact();
    final isEnabled = await _platform.isAccessibilityServiceEnabled();
    if (isEnabled) {
      await _platform.lockScreen();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enable Accessibility to lock screen on double-tap'),
          action: SnackBarAction(
            label: 'Enable',
            textColor: _effectiveAccent,
            onPressed: _platform.openAccessibilitySettings,
          ),
        ),
      );
    }
  }

  void _showAppActions(AppItem app) {
    final isPinned = _dockApps.any((a) => a.id == app.id);
    final isDockFull = _dockApps.length >= maxDockApps;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => AppActionsSheet(
        app: app,
        isPinned: isPinned,
        isDockFull: isDockFull,
        onTogglePin: () {
          Navigator.pop(sheetCtx);
          _togglePin(app);
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

  void _showQuickSettings() {
    HapticFeedback.lightImpact();
    setState(() => _isQuickSettingsOpen = true);
  }

  void _hideQuickSettings() {
    HapticFeedback.lightImpact();
    setState(() => _isQuickSettingsOpen = false);
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
          customWallpaperPath: _customWallpaperPath,
          availableIconPacks: _availableIconPacks,
          selectedIconPack: _selectedIconPack,
          drawerIsList: _drawerIsList,
          drawerMode: _drawerMode,
          autoFocusSearch: _autoFocusSearch,
          searchIncludesHidden: _searchIncludesHidden,
          ambientIdleMode: _ambientIdleMode,
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
          onSetCustomWallpaper: (path) async {
            if (!mounted) return;
            setState(() => _customWallpaperPath = path);
            await _prefs?.setCustomWallpaperPath(path);
          },
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
          onOpenHomeSettings: _platform.openHomeSettings,
          onOpenAccessibilitySettings: _platform.openAccessibilitySettings,
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
        if (_isQuickSettingsOpen) {
          setState(() => _isQuickSettingsOpen = false);
        } else if (_isPanelExpanded) {
          setState(() => _isPanelExpanded = false);
        }
      },
      child: Scaffold(
        body: Listener(
          onPointerDown: _onUserInteraction,
          onPointerMove: _onUserInteraction,
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            final metrics = TileMetrics.forWidth(maxW);
            final dockHeight = metrics.tileSize + padding.bottom;

            final targetPanelHeight = _isPanelExpanded
                ? maxH
                : maxH * 0.5 + dragHandleHeight;

            final panelBottom = _isQuickSettingsOpen ? -targetPanelHeight : 0.0;
            final clockTop = _isQuickSettingsOpen
                ? padding.top + 264.0
                : padding.top + 16.0;

            return Stack(
              children: [
                // Custom or Default Background Wallpaper with Double-Tap to Sleep, Long-Press for Settings, & Swipe-Down for Quick Settings
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _handleDoubleTapToLock,
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      _openSettingsPage();
                    },
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! > 220 &&
                            !_isPanelExpanded &&
                            !_isQuickSettingsOpen) {
                          _showQuickSettings();
                        } else if (details.primaryVelocity! < -220 &&
                            _isQuickSettingsOpen) {
                          _hideQuickSettings();
                        }
                      }
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      opacity: _isIdle ? 0.0 : 1.0,
                      child: _customWallpaperPath != null &&
                              File(_customWallpaperPath!).existsSync()
                          ? Image.file(
                              File(_customWallpaperPath!),
                              fit: BoxFit.cover,
                            )
                          : const ColoredBox(color: LauncherColors.background),
                    ),
                  ),
                ),

                // Solid black background underneath wallpaper when in idle mode
                if (_isIdle)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Colors.black),
                    ),
                  ),

                // Dark overlay when wallpaper is active to keep icons readable
                if (_customWallpaperPath != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),

                // Subtle radial glow / gradient of the accent color when Quick Settings is open
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: maxH * 0.55,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      opacity: _isQuickSettingsOpen ? 1.0 : 0.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.0, -0.6),
                            radius: 1.05,
                            colors: [
                              _effectiveAccent.withValues(alpha: 0.16),
                              _effectiveAccent.withValues(alpha: 0.07),
                              _effectiveAccent.withValues(alpha: 0.015),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.40, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Inline Quick Settings Watch Shade positioned above the clock
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: _isQuickSettingsOpen ? padding.top + 8.0 : -320.0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _isQuickSettingsOpen ? 1.0 : 0.0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: QuickSettingsPanel(
                        accent: _effectiveAccent,
                        platform: _platform,
                        onClose: _hideQuickSettings,
                      ),
                    ),
                  ),
                ),

                // Clock area: Centered Pixel Watch clock with symmetrical circular complications
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: clockTop,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: _handleDoubleTapToLock,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! > 220 &&
                            !_isPanelExpanded &&
                            !_isQuickSettingsOpen) {
                          _showQuickSettings();
                        } else if (details.primaryVelocity! < -220 &&
                            _isQuickSettingsOpen) {
                          _hideQuickSettings();
                        }
                      }
                    },
                    child: AnimatedOpacity(
                      opacity: _isPanelExpanded ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: LauncherClock(
                          accent: _effectiveAccent,
                          onTap: _platform.openAlarms,
                          onDateTap: _openCalendar,
                          onSettingsTap: _openSettingsPage,
                          isIdle: _isIdle,
                          mediaTitle: _mediaTitle,
                          mediaArtist: _mediaArtist,
                          onMediaTap: () => _platform.launch(
                            _allApps.firstWhere(
                              (a) => a.packageName.contains('music') ||
                                  a.packageName.contains('spotify') ||
                                  a.packageName.contains('audio'),
                              orElse: () => _allApps.first,
                            ),
                          ),
                          onWeatherTap: () {
                            if (_isQuickSettingsOpen) {
                              _hideQuickSettings();
                            } else {
                              _showQuickSettings();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom half / expandable app grid panel (moves down out of sight when Quick Settings is open)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: panelBottom,
                  height: targetPanelHeight,
                  child: AppPanel(
                    apps: _visibleApps,
                    allApps: _allApps,
                    metrics: metrics,
                    dockHeight: dockHeight,
                    isExpanded: _isPanelExpanded,
                    isListMode: _drawerIsList,
                    drawerMode: _drawerMode,
                    autoFocusSearch: _autoFocusSearch,
                    searchIncludesHidden: _searchIncludesHidden,
                    isIdle: _isIdle,
                    accent: _effectiveAccent,
                    onExpandedChanged: (expanded) {
                      if (_isQuickSettingsOpen) {
                        setState(() => _isQuickSettingsOpen = false);
                      }
                      setState(() => _isPanelExpanded = expanded);
                    },
                    onAppTap: _platform.launch,
                    onAppLongPress: _showAppActions,
                  ),
                ),

                // Persistent 4-slot dock at bottom (animates down / hides in idle mode)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: _isIdle ? -dockHeight - 16 : padding.bottom,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    opacity: _isIdle ? 0.0 : 1.0,
                    child: Dock(
                      apps: _dockApps,
                      accent: _effectiveAccent,
                      metrics: metrics,
                      onAppTap: _platform.launch,
                      onAppLongPress: _showAppActions,
                      onReorder: _reorderDock,
                    ),
                  ),
                ),

                // Dim scrim overlay when in ambient idle mode
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      opacity: _isIdle ? 0.38 : 0.0,
                      child: const ColoredBox(color: Colors.black),
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
