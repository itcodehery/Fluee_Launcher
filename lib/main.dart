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
import 'widgets/app_actions_sheet.dart';
import 'widgets/app_panel.dart';
import 'widgets/app_tile.dart';
import 'widgets/icon_picker_sheet.dart';
import 'widgets/intro_flow.dart';
import 'widgets/launcher_clock.dart';
import 'widgets/profile_dashboard.dart';
import 'widgets/quick_apps_panel.dart';
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
  List<String> _quickIds = List<String>.filled(maxQuickApps, '');
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
  String? _ambientCustomText;
  String? _profileName;
  Uint8List? _profilePhoto;
  bool _isIdle = false;
  Timer? _idleTimer;
  Timer? _mediaPollTimer;
  String? _mediaTitle;
  String? _mediaArtist;

  Color _customAccent = LauncherColors.defaultAccent;
  Color? _wallpaperAccent;
  bool _useWallpaperAccent = false;
  bool _isPanelExpanded = false;
  bool _isQuickSettingsOpen = false;
  double _qsDragOffset = 0.0;
  double? _drawerDragT;
  bool _isDraggingQs = false;
  int? _dragPointer;
  Offset _dragOrigin = Offset.zero;
  bool _dragClaimed = false;
  double _dragStartPos = 0;
  double _maxH = 800;
  VelocityTracker? _velocityTracker;

  static const double _qsPanelHeight = 252.0;
  static const double _qsTravel = _qsPanelHeight + 16.0;
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

  List<AppItem?> get _quickSlots {
    final byId = {for (final a in _allApps) a.id: a};
    return [for (final id in _quickIds) byId[id]];
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

  void _pickQuickApp(int slot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => QuickAppPickerSheet(
        apps: _visibleApps,
        onSelected: (app) {
          Navigator.pop(sheetCtx);
          final current = List<String>.from(_quickIds);
          final existing = current.indexOf(app.id);
          if (existing >= 0) current[existing] = '';
          current[slot] = app.id;
          _setQuickIds(current);
        },
      ),
    );
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
      _ambientCustomText = prefs.ambientCustomText;
      _profileName = prefs.profileName;
      _profilePhoto = prefs.profilePhoto;
      _availableIconPacks = iconPacks;
      _allApps = apps;
      _quickIds = _normalizeQuick(prefs.quickAppIds);
      _isInitialized = true;
    });

    _resetIdleTimer();
    _startMediaPolling();
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
      _ambientCustomText = _prefs!.ambientCustomText;
      _profileName = _prefs!.profileName;
      _profilePhoto = _prefs!.profilePhoto;
      _quickIds = _normalizeQuick(_prefs!.quickAppIds);
      _hiddenAppIds = _prefs!.hiddenAppIds;
      _selectedIconPack = _prefs!.selectedIconPack;
      _customLabelMap = _prefs!.customLabelMap;
      _customIconMap = _prefs!.customIconMap;
    });
    _reloadApps();
    _loadShortcuts();
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
    if (track != null && track['isPlaying'] == true) {
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

  void _onUserInteraction() {
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
    setState(() {
      _isDraggingQs = false;
      _drawerDragT = null;
      _qsDragOffset = 0.0;
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

  double _computeCollapsedHeight(TileMetrics metrics, double bottomInset) {
    return dragHandleHeight + 4.0 + (metrics.tileSize * 2) + TileMetrics.gap + bottomInset + 12.0;
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
    final drawerTravel = _maxH - _computeCollapsedHeight(TileMetrics.forWidth(400), 0);
    if (!_dragClaimed) {
      if (d.dy.abs() > 18 && d.dy.abs() > d.dx.abs() * 1.5) {
        _dragClaimed = true;
        _dragOrigin = e.position;
        _dragStartPos = _isQuickSettingsOpen ? _qsTravel : 0.0;
      } else {
        return;
      }
    }
    final pos = (_dragStartPos + (e.position.dy - _dragOrigin.dy))
        .clamp(-drawerTravel, _qsTravel);
    setState(() {
      _isDraggingQs = true;
      _qsDragOffset = pos > 0 ? pos : 0.0;
      _drawerDragT = pos < 0 ? (-pos / drawerTravel) : 0.0;
    });
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer != _dragPointer) return;
    final claimed = _dragClaimed;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final drawerTravel = _maxH - _computeCollapsedHeight(TileMetrics.forWidth(400), 0);
    _dragPointer = null;
    _velocityTracker = null;
    _dragClaimed = false;
    if (!claimed) return;

    final pos = _qsDragOffset > 0 ? _qsDragOffset : -(_drawerDragT ?? 0) * drawerTravel;
    int target;
    if (velocity > 300) {
      target = pos < 0 ? 0 : 1;
    } else if (velocity < -300) {
      target = pos > 0 ? 0 : -1;
    } else if (pos > _qsTravel * 0.4) {
      target = 1;
    } else if (pos < -drawerTravel * 0.2) {
      target = -1;
    } else {
      target = 0;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isDraggingQs = false;
      _drawerDragT = null;
      _isQuickSettingsOpen = target == 1;
      _isPanelExpanded = target == -1;
      _qsDragOffset = target == 1 ? _qsTravel : 0.0;
    });
    _resetIdleTimer();
  }
  void _showQuickSettings() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDraggingQs = false;
      _qsDragOffset = _qsTravel;
      _isQuickSettingsOpen = true;
    });
  }

  void _hideQuickSettings() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDraggingQs = false;
      _drawerDragT = null;
      _qsDragOffset = 0.0;
      _isQuickSettingsOpen = false;
    });
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
          ambientCustomText: _ambientCustomText,
          profileName: _profileName,
          profilePhoto: _profilePhoto,
          quickAppCount: _quickIds.where((id) => id.isNotEmpty).length,
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
          onAmbientCustomTextChanged: (text) async {
            if (!mounted) return;
            setState(() => _ambientCustomText = text);
            await _prefs?.setAmbientCustomText(text);
          },
          onOpenHomeSettings: _platform.openHomeSettings,
          onOpenAccessibilitySettings: _platform.openAccessibilitySettings,
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
        if (_isQuickSettingsOpen) {
          _hideQuickSettings();
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
            final collapsedH = _computeCollapsedHeight(metrics, padding.bottom);
            final drawerT = _drawerDragT ?? (_isPanelExpanded ? 1.0 : 0.0);
            final targetPanelHeight = collapsedH + (maxH - collapsedH) * drawerT;

            final dragRatio = (_qsDragOffset / _qsTravel).clamp(0.0, 1.0);

            final restingClockTop = _isIdle ? (maxH * 0.18) : (padding.top + 16.0);
            final openClockTop = padding.top + _qsPanelHeight + 12.0;

            final qsOpenTop = padding.top + 8.0;
            final qsClosedTop = -_qsPanelHeight - 20.0;
            final double qsTop;
            final double clockTop;
            final double panelBottom;
            final double qsOpacity;
            final double glowOpacity;

            if (_isDraggingQs) {
              qsTop = qsClosedTop + (_qsTravel + 20.0) * dragRatio;
              clockTop = restingClockTop + (openClockTop - restingClockTop) * dragRatio;
              panelBottom = -collapsedH * dragRatio;
              qsOpacity = dragRatio;
              glowOpacity = dragRatio;
            } else {
              qsTop = _isQuickSettingsOpen ? qsOpenTop : qsClosedTop;
              clockTop = _isQuickSettingsOpen ? openClockTop : restingClockTop;
              panelBottom = (_isQuickSettingsOpen || _isIdle) ? -targetPanelHeight : 0.0;
              qsOpacity = _isQuickSettingsOpen ? 1.0 : 0.0;
              glowOpacity = _isQuickSettingsOpen ? 1.0 : 0.0;
            }

            final clockOpacity = (_isPanelExpanded && _drawerDragT == null)
                ? 0.0
                : (1.0 - drawerT).clamp(0.0, 1.0);

            final animDuration = _isDraggingQs
                ? Duration.zero
                : Duration(milliseconds: _isIdle ? 1100 : 240);

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
                    child: const ColoredBox(color: LauncherColors.background),
                  ),
                ),

                // Subtle radial glow / gradient of the accent color when Quick Settings is open
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: maxH * 0.60,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: animDuration,
                      curve: Curves.easeOutCubic,
                      opacity: glowOpacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.0, -1.35),
                            radius: 1.4,
                            colors: [
                              _effectiveAccent.withValues(alpha: 0.45),
                              _effectiveAccent.withValues(alpha: 0.25),
                              _effectiveAccent.withValues(alpha: 0.08),
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
                  duration: animDuration,
                  curve: Curves.easeOutCubic,
                  top: qsTop,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: animDuration,
                    opacity: qsOpacity,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: QuickAppsPanel(
                        accent: _effectiveAccent,
                        platform: _platform,
                        slots: _quickSlots,
                        onClose: _hideQuickSettings,
                        onAppTap: (app) {
                          _hideQuickSettings();
                          _launchApp(app);
                        },
                        onAppLongPress: _showAppActions,
                        onEmptySlotTap: _pickQuickApp,
                      ),
                    ),
                  ),
                ),

                // Clock area: Centered Pixel Watch clock with symmetrical circular complications
                AnimatedPositioned(
                  duration: animDuration,
                  curve: Curves.easeOutCubic,
                  top: clockTop,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: _handleDoubleTapToLock,
                    child: AnimatedOpacity(
                      opacity: clockOpacity,
                      duration: _isDraggingQs ? Duration.zero : const Duration(milliseconds: 200),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: LauncherClock(
                          accent: _effectiveAccent,
                          onTap: _platform.openAlarms,
                          dashboard: ProfileDashboard(
                            accent: _effectiveAccent,
                            platform: _platform,
                            name: _profileName,
                            photo: _profilePhoto,
                          ),
                          onDateTap: _openCalendar,
                          onSettingsTap: _openSettingsPage,
                          isIdle: _isIdle,
                          mediaTitle: _mediaTitle,
                          mediaArtist: _mediaArtist,
                          customAmbientText: _ambientCustomText,
                          onMediaTap: () => _platform.launch(
                            _allApps.firstWhere(
                              (a) =>
                                  a.packageName.contains('music') ||
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

                // Bottom half / expandable app grid panel (moves down out of sight when Quick Settings or Ambient Mode is open)
                AnimatedPositioned(
                  duration: animDuration,
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
                    onShortcutTap: (s) {
                      _platform.startShortcut(s.packageName, s.id);
                    },
                    onExpandedChanged: (expanded) {
                      if (_isQuickSettingsOpen) {
                        _hideQuickSettings();
                      }
                      setState(() => _isPanelExpanded = expanded);
                    },
                    onAppTap: _launchApp,
                    onAppLongPress: _showAppActions,
                  ),
                ),

                // Dim scrim overlay when in ambient idle mode
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: _isIdle ? 1200 : 300),
                      curve: Curves.easeInOutCubic,
                      opacity: _isIdle ? 0.42 : 0.0,
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
