import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_item.dart';
import '../services/launcher_platform.dart';
import '../services/launcher_preferences.dart';
import '../theme/launcher_colors.dart';
import 'm3_spring_button.dart';

typedef SettingsSheet = SettingsPage;

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.accent,
    required this.useWallpaperAccent,
    required this.wallpaperAccent,
    required this.allApps,
    required this.hiddenAppIds,
    required this.customWallpaperPath,
    required this.availableIconPacks,
    required this.selectedIconPack,
    required this.drawerIsList,
    this.drawerMode,
    required this.autoFocusSearch,
    this.searchIncludesHidden = false,
    this.ambientIdleMode = true,
    required this.onSelectCustomAccent,
    required this.onSelectWallpaperAccent,
    required this.onToggleHideApp,
    required this.onSetCustomWallpaper,
    required this.onSelectIconPack,
    required this.onToggleDrawerIsList,
    this.onSelectDrawerMode,
    required this.onToggleAutoFocusSearch,
    this.onToggleSearchIncludesHidden,
    this.onToggleAmbientIdleMode,
    required this.onOpenHomeSettings,
    required this.onOpenAccessibilitySettings,
  });

  final Color accent;
  final bool useWallpaperAccent;
  final Color? wallpaperAccent;
  final List<AppItem> allApps;
  final Set<String> hiddenAppIds;
  final String? customWallpaperPath;
  final List<IconPackInfo> availableIconPacks;
  final String? selectedIconPack;
  final bool drawerIsList;
  final DrawerMode? drawerMode;
  final bool autoFocusSearch;
  final bool searchIncludesHidden;
  final bool ambientIdleMode;
  final ValueChanged<Color> onSelectCustomAccent;
  final VoidCallback onSelectWallpaperAccent;
  final ValueChanged<AppItem> onToggleHideApp;
  final ValueChanged<String?> onSetCustomWallpaper;
  final ValueChanged<String?> onSelectIconPack;
  final ValueChanged<bool> onToggleDrawerIsList;
  final ValueChanged<DrawerMode>? onSelectDrawerMode;
  final ValueChanged<bool> onToggleAutoFocusSearch;
  final ValueChanged<bool>? onToggleSearchIncludesHidden;
  final ValueChanged<bool>? onToggleAmbientIdleMode;
  final VoidCallback onOpenHomeSettings;
  final VoidCallback onOpenAccessibilitySettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  late Color _currentAccent;
  late bool _useWallpaper;
  late DrawerMode _drawerMode;
  late bool _autoFocus;
  late bool _searchIncludesHidden;
  late bool _ambientIdle;
  bool _showCustomSliders = false;

  @override
  void initState() {
    super.initState();
    _currentAccent = widget.accent;
    _useWallpaper = widget.useWallpaperAccent;
    _drawerMode = widget.drawerMode ??
        (widget.drawerIsList ? DrawerMode.list : DrawerMode.grid);
    _autoFocus = widget.autoFocusSearch;
    _searchIncludesHidden = widget.searchIncludesHidden;
    _ambientIdle = widget.ambientIdleMode;
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accent != widget.accent) {
      _currentAccent = widget.accent;
    }
    if (oldWidget.useWallpaperAccent != widget.useWallpaperAccent) {
      _useWallpaper = widget.useWallpaperAccent;
    }
    if (oldWidget.drawerMode != widget.drawerMode && widget.drawerMode != null) {
      _drawerMode = widget.drawerMode!;
    } else if (oldWidget.drawerIsList != widget.drawerIsList) {
      _drawerMode = widget.drawerIsList ? DrawerMode.list : DrawerMode.grid;
    }
    if (oldWidget.autoFocusSearch != widget.autoFocusSearch) {
      _autoFocus = widget.autoFocusSearch;
    }
    if (oldWidget.searchIncludesHidden != widget.searchIncludesHidden) {
      _searchIncludesHidden = widget.searchIncludesHidden;
    }
    if (oldWidget.ambientIdleMode != widget.ambientIdleMode) {
      _ambientIdle = widget.ambientIdleMode;
    }
  }

  Future<void> _pickWallpaper() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      widget.onSetCustomWallpaper(image.path);
    }
  }

  void _onColorSelected(Color color) {
    if (!mounted) return;
    setState(() {
      _currentAccent = color;
      _useWallpaper = false;
    });
    widget.onSelectCustomAccent(color);
  }

  void _onWallpaperAccentSelected() {
    if (!mounted) return;
    if (widget.wallpaperAccent != null) {
      setState(() {
        _currentAccent = widget.wallpaperAccent!;
        _useWallpaper = true;
      });
      widget.onSelectWallpaperAccent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_currentAccent);
    final hexCode =
        '#${_currentAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Scaffold(
      backgroundColor: LauncherColors.background,
      appBar: AppBar(
        backgroundColor: LauncherColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Launcher Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drawer Display Mode & Search Options
              const Text(
                'APP DRAWER & SEARCH',
                style: TextStyle(
                  color: LauncherColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          color: _currentAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Drawer Layout',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Choose grid, tiles, or list presentation',
                                style: TextStyle(
                                  color: LauncherColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildModeButton(
                          mode: DrawerMode.grid,
                          label: 'Grid (4x)',
                          icon: Icons.grid_view_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildModeButton(
                          mode: DrawerMode.tiles,
                          label: 'Android 12 Tiles',
                          icon: Icons.view_quilt_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildModeButton(
                          mode: DrawerMode.list,
                          label: 'List',
                          icon: Icons.view_headline_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Auto-focus Search Bar Toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.keyboard_alt_outlined,
                      color: _currentAccent,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-Focus Search',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Open keyboard automatically when expanding drawer',
                            style: TextStyle(
                              color: LauncherColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoFocus,
                      activeThumbColor: _currentAccent,
                      onChanged: (val) {
                        setState(() => _autoFocus = val);
                        widget.onToggleAutoFocusSearch(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Search Includes Hidden Apps Toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: _currentAccent,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show Hidden Apps in Search',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Include hidden apps in search query results',
                            style: TextStyle(
                              color: LauncherColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _searchIncludesHidden,
                      activeThumbColor: _currentAccent,
                      onChanged: (val) {
                        setState(() => _searchIncludesHidden = val);
                        widget.onToggleSearchIncludesHidden?.call(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Icon Pack Section
              const Text(
                'ICON PACK',
                style: TextStyle(
                  color: LauncherColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, color: _currentAccent, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Active Icon Pack',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Default System'),
                          selected: widget.selectedIconPack == null,
                          selectedColor: _currentAccent,
                          backgroundColor: const Color(0xFF222222),
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            color: widget.selectedIconPack == null
                                ? LauncherColors.readableOn(_currentAccent)
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) {
                            widget.onSelectIconPack(null);
                            setState(() {});
                          },
                        ),
                        for (final pack in widget.availableIconPacks)
                          ChoiceChip(
                            label: Text(pack.label),
                            selected: widget.selectedIconPack == pack.packageName,
                            selectedColor: _currentAccent,
                            backgroundColor: const Color(0xFF222222),
                            side: BorderSide.none,
                            labelStyle: TextStyle(
                              color: widget.selectedIconPack == pack.packageName
                                  ? LauncherColors.readableOn(_currentAccent)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) {
                              widget.onSelectIconPack(pack.packageName);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    if (widget.availableIconPacks.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Install icon packs from Google Play Store to apply custom themes globally or to individual apps.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Wallpaper Section
              const Text(
                'WALLPAPER',
                style: TextStyle(
                  color: LauncherColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        image: widget.customWallpaperPath != null
                            ? DecorationImage(
                                image: FileImage(File(widget.customWallpaperPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: widget.customWallpaperPath == null
                          ? const Icon(Icons.wallpaper, color: Colors.white54, size: 26)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customWallpaperPath != null
                                ? 'Custom wallpaper set'
                                : 'Default black wallpaper',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pick from gallery or reset',
                            style: TextStyle(
                              color: LauncherColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    M3SpringButton(
                      onTap: _pickWallpaper,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _currentAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Choose',
                          style: TextStyle(
                            color: LauncherColors.readableOn(_currentAccent),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (widget.customWallpaperPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: LauncherColors.danger),
                        onPressed: () {
                          widget.onSetCustomWallpaper(null);
                          setState(() {});
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Accent Color Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ACCENT COLOR',
                    style: TextStyle(
                      color: LauncherColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    hexCode,
                    style: TextStyle(
                      color: _currentAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (widget.wallpaperAccent != null)
                          _buildSwatch(
                            color: widget.wallpaperAccent!,
                            isSelected: _useWallpaper,
                            isWallpaper: true,
                            onTap: _onWallpaperAccentSelected,
                          ),
                        for (final preset in LauncherColors.accentPresets)
                          _buildSwatch(
                            color: preset,
                            isSelected: !_useWallpaper &&
                                preset.toARGB32() == _currentAccent.toARGB32(),
                            onTap: () => _onColorSelected(preset),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => _showCustomSliders = !_showCustomSliders);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _showCustomSliders ? 'Hide custom sliders' : 'Tune custom shade...',
                              style: const TextStyle(
                                color: LauncherColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              _showCustomSliders
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: LauncherColors.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showCustomSliders) ...[
                      const SizedBox(height: 12),
                      _buildHsvSlider(
                        label: 'Hue',
                        value: hsv.hue,
                        min: 0,
                        max: 360,
                        onChanged: (v) {
                          _onColorSelected(
                            HSVColor.fromAHSV(1.0, v, hsv.saturation, hsv.value).toColor(),
                          );
                        },
                      ),
                      _buildHsvSlider(
                        label: 'Saturation',
                        value: hsv.saturation,
                        min: 0,
                        max: 1,
                        onChanged: (v) {
                          _onColorSelected(
                            HSVColor.fromAHSV(1.0, hsv.hue, v, hsv.value).toColor(),
                          );
                        },
                      ),
                      _buildHsvSlider(
                        label: 'Brightness',
                        value: hsv.value.clamp(0.2, 1.0),
                        min: 0.2,
                        max: 1,
                        onChanged: (v) {
                          _onColorSelected(
                            HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, v).toColor(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Hidden Apps Manager
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HIDDEN APPS',
                    style: TextStyle(
                      color: LauncherColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${widget.hiddenAppIds.length} hidden',
                    style: TextStyle(
                      color: _currentAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search apps to hide or unhide...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF222222),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const Divider(color: Color(0x22FFFFFF), height: 1),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final isHidden = widget.hiddenAppIds.contains(app.id);
                          return ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 32,
                              height: 32,
                              child: app.icon.isNotEmpty
                                  ? Image.memory(
                                      app.icon,
                                      fit: BoxFit.contain,
                                      color: Colors.white,
                                      colorBlendMode: BlendMode.srcIn,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.apps, color: Colors.white54, size: 20),
                                    )
                                  : const Icon(Icons.apps, color: Colors.white54, size: 20),
                            ),
                            title: Text(
                              app.label,
                              style: TextStyle(
                                color: isHidden ? Colors.white38 : Colors.white,
                                fontSize: 14,
                                decoration: isHidden ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: Switch(
                              value: !isHidden,
                              activeThumbColor: _currentAccent,
                              onChanged: (_) {
                                widget.onToggleHideApp(app);
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Ambient Idle Screen Setting
              Container(
                decoration: BoxDecoration(
                  color: LauncherColors.tileBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Icon(Icons.nightlight_round, color: _currentAccent, size: 22),
                  title: const Text(
                    'Ambient Idle Screen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Dim screen, hide dock, expand clock after 8s of inactivity',
                    style: TextStyle(
                      color: LauncherColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: _ambientIdle,
                  activeThumbColor: _currentAccent,
                  onChanged: (val) {
                    setState(() => _ambientIdle = val);
                    widget.onToggleAmbientIdleMode?.call(val);
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Double-Tap to Lock Screen Accessibility Setup
              M3SpringButton(
                onTap: widget.onOpenAccessibilitySettings,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                  decoration: BoxDecoration(
                    color: LauncherColors.tileBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app_outlined, color: _currentAccent, size: 22),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Double-Tap to Lock Setup',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Enable Fluee Accessibility Service',
                              style: TextStyle(
                                  color: LauncherColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Default Launcher Button
              M3SpringButton(
                onTap: widget.onOpenHomeSettings,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Default Home App Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwatch({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool isWallpaper = false,
  }) {
    final fg = LauncherColors.readableOn(color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.5)
              : null,
        ),
        alignment: Alignment.center,
        child: isSelected
            ? Icon(Icons.check, color: fg, size: 18)
            : (isWallpaper
                ? Icon(Icons.auto_awesome, color: fg, size: 18)
                : null),
      ),
    );
  }

  Widget _buildHsvSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: LauncherColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _currentAccent,
              thumbColor: _currentAccent,
              inactiveTrackColor: const Color(0xFF3A3A3A),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required DrawerMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _drawerMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _drawerMode = mode;
          });
          widget.onSelectDrawerMode?.call(mode);
          widget.onToggleDrawerIsList(mode == DrawerMode.list);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? _currentAccent : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? LauncherColors.readableOn(_currentAccent)
                    : Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? LauncherColors.readableOn(_currentAccent)
                      : Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AppItem> get _filteredApps {
    if (_searchQuery.isEmpty) return widget.allApps;
    return widget.allApps
        .where((a) =>
            a.label.toLowerCase().contains(_searchQuery) ||
            a.packageName.toLowerCase().contains(_searchQuery))
        .toList();
  }
}
