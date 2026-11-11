import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
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
    this.customWallpaperPath,
    required this.availableIconPacks,
    required this.selectedIconPack,
    required this.drawerIsList,
    this.drawerMode,
    required this.autoFocusSearch,
    this.searchIncludesHidden = false,
    this.ambientIdleMode = true,
    this.ambientCustomText,
    this.profileName,
    this.profilePhoto,
    this.quickAppCount = 0,
    this.onProfileNameChanged,
    this.onProfilePhotoChanged,
    required this.onSelectCustomAccent,
    required this.onSelectWallpaperAccent,
    required this.onToggleHideApp,
    this.onSetCustomWallpaper,
    required this.onSelectIconPack,
    required this.onToggleDrawerIsList,
    this.onSelectDrawerMode,
    required this.onToggleAutoFocusSearch,
    this.onToggleSearchIncludesHidden,
    this.onToggleAmbientIdleMode,
    this.onAmbientCustomTextChanged,
    this.prefs,
    this.platform,
    this.onBackupRestored,
    required this.onOpenHomeSettings,
    required this.onOpenAccessibilitySettings,
    this.onOpenNotificationListenerSettings,
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
  final String? ambientCustomText;
  final String? profileName;
  final Uint8List? profilePhoto;
  final int quickAppCount;
  final LauncherPreferences? prefs;
  final LauncherPlatform? platform;
  final VoidCallback? onBackupRestored;
  final ValueChanged<String?>? onProfileNameChanged;
  final ValueChanged<Uint8List?>? onProfilePhotoChanged;
  final ValueChanged<Color> onSelectCustomAccent;
  final VoidCallback onSelectWallpaperAccent;
  final ValueChanged<AppItem> onToggleHideApp;
  final ValueChanged<String?>? onSetCustomWallpaper;
  final ValueChanged<String?> onSelectIconPack;
  final ValueChanged<bool> onToggleDrawerIsList;
  final ValueChanged<DrawerMode>? onSelectDrawerMode;
  final ValueChanged<bool> onToggleAutoFocusSearch;
  final ValueChanged<bool>? onToggleSearchIncludesHidden;
  final ValueChanged<bool>? onToggleAmbientIdleMode;
  final ValueChanged<String?>? onAmbientCustomTextChanged;
  final VoidCallback onOpenHomeSettings;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback? onOpenNotificationListenerSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _searchQuery = '';
  late Color _currentAccent;
  late bool _useWallpaper;
  late DrawerMode _drawerMode;
  late bool _autoFocus;
  late bool _searchIncludesHidden;
  late bool _ambientIdle;
  late final TextEditingController _profileNameController;
  Uint8List? _profilePhoto;
  late final TextEditingController _ambientTextController;
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
    _profileNameController = TextEditingController(text: widget.profileName ?? '');
    _profilePhoto = widget.profilePhoto;
    _ambientTextController = TextEditingController(text: widget.ambientCustomText ?? '');
  }

  @override
  void dispose() {
    _ambientTextController.dispose();
    _profileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _profilePhoto = bytes);
      widget.onProfilePhotoChanged?.call(bytes);
    } catch (_) {}
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
    if (oldWidget.profileName != widget.profileName) {
      _profileNameController.text = widget.profileName ?? '';
    }
    if (oldWidget.profilePhoto != widget.profilePhoto) {
      _profilePhoto = widget.profilePhoto;
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

  Future<void> _exportBackup() async {
    if (widget.prefs == null || widget.platform == null) return;
    final jsonMap = widget.prefs!.exportBackupJson();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'fluee_backup_$dateStr.json';

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export Backup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Save layout, pinned quick apps, custom labels, hidden apps and theme preferences.',
                style: TextStyle(
                  color: Color(0xFF8B9691),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF242A27),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.file_download_outlined, color: _currentAccent, size: 20),
                ),
                title: const Text('Save to Storage or Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Export JSON file to Downloads, Drive, etc.', style: TextStyle(color: Color(0xFF8B9691), fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final ok = await widget.platform!.exportBackupFile(jsonStr, fileName);
                  if (!mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup exported successfully!')),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF242A27),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share_outlined, color: _currentAccent, size: 20),
                ),
                title: const Text('Share Backup File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Send JSON backup via apps or cloud', style: TextStyle(color: Color(0xFF8B9691), fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await widget.platform!.shareBackup(jsonStr, 'Fluee Launcher Backup');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF242A27),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.copy_rounded, color: _currentAccent, size: 20),
                ),
                title: const Text('Copy JSON to Clipboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Copy raw configuration text', style: TextStyle(color: Color(0xFF8B9691), fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await Clipboard.setData(ClipboardData(text: jsonStr));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup JSON copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreBackup() async {
    if (widget.prefs == null || widget.platform == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Restore Backup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Import and restore your layout, custom labels, hidden apps and themes.',
                style: TextStyle(
                  color: Color(0xFF8B9691),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF242A27),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.folder_open_outlined, color: _currentAccent, size: 20),
                ),
                title: const Text('Import from Storage or Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Pick a .json backup file from Drive or disk', style: TextStyle(color: Color(0xFF8B9691), fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final content = await widget.platform!.importBackupFile();
                  if (content == null || content.isEmpty) return;
                  await _applyImportedBackup(content);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF242A27),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.paste_rounded, color: _currentAccent, size: 20),
                ),
                title: const Text('Paste JSON from Clipboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Restore from copied configuration text', style: TextStyle(color: Color(0xFF8B9691), fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text == null || data!.text!.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clipboard is empty.')),
                    );
                    return;
                  }
                  await _applyImportedBackup(data.text!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyImportedBackup(String content) async {
    if (widget.prefs == null) return;
    final success = await widget.prefs!.importBackupJson(content);
    if (!mounted) return;
    if (success) {
      widget.onBackupRestored?.call();
      setState(() {
        _currentAccent = widget.prefs!.customAccent;
        _useWallpaper = widget.prefs!.useWallpaperAccent;
        _drawerMode = widget.prefs!.drawerMode;
        _autoFocus = widget.prefs!.autoFocusSearch;
        _searchIncludesHidden = widget.prefs!.searchIncludesHidden;
        _ambientIdle = widget.prefs!.ambientIdleMode;
        _profileNameController.text = widget.prefs!.profileName ?? '';
        _profilePhoto = widget.prefs!.profilePhoto;
        _ambientTextController.text = widget.prefs!.ambientCustomText ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout and settings restored successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid backup file or format.')),
      );
    }
  }

  void _showAccessibilityDisclosure() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF242A27),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.accessibility_new_rounded, color: _currentAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Accessibility Service Disclosure',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Fluee Launcher requests Accessibility Service access solely to enable the double-tap to lock screen gesture and open the power menu.\n\n'
                '• Fluee Launcher does not monitor your keystrokes or inputs.\n'
                '• Fluee Launcher does not read screen content or personal activity.\n'
                '• No user data is ever tracked, stored, or transmitted.',
                style: TextStyle(
                  color: Color(0xFFB0BCB6),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: M3SpringButton(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242A27),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: M3SpringButton(
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onOpenAccessibilitySettings();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _currentAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Proceed to Settings',
                          style: TextStyle(
                            color: LauncherColors.readableOn(_currentAccent),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Last Updated: November 11, 2026\n\n'
                  '1. Zero Personal Data Collection\n'
                  'Fluee Launcher is a 100% offline, local-only application. We do not collect, transmit, store, or share any personal information. The app does not request or use internet access.\n\n'
                  '2. Local App Discovery (QUERY_ALL_PACKAGES)\n'
                  'Fluee Launcher queries installed apps solely to display your app drawer and search results locally on your device.\n\n'
                  '3. Accessibility Service Usage\n'
                  'The Accessibility Service is used solely to lock the screen upon double-tap and display the power menu. It does not monitor keystrokes or inspect window contents.\n\n'
                  '4. Media Playback\n'
                  'Notification listener access is used strictly to read the active track title and artist for home screen display.\n\n'
                  '5. Local Backups\n'
                  'All launcher layouts and preferences are stored locally on your device and exported only when requested by you via Android Storage Access Framework.',
                  style: TextStyle(
                    color: Color(0xFFB0BCB6),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Expressive toggle switch matching the user's reference design language:
  /// - ON: Accent background pill, contrasting white thumb with checkmark icon inside.
  /// - OFF: Muted dark track, silver thumb with cross icon inside.
  Widget _expressiveSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 54,
        height: 32,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: value ? _currentAccent : const Color(0xFF333A37),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: value
                  ? LauncherColors.readableOn(_currentAccent)
                  : const Color(0xFF6C7571),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                value ? Icons.check_rounded : Icons.close_rounded,
                size: 15,
                color: value ? _currentAccent : const Color(0xFF191D1B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: _currentAccent.withValues(alpha: 0.85),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F1D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _buildTileHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF242A27),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _currentAccent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8B9691),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_currentAccent);
    final hexCode =
        '#${_currentAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1211),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1211),
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
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Segmented Stats Card matching "Focus 25 | Short break 5 | Long break 15"
              Row(
                children: [
                  _buildStatCard(
                    label: 'ALL APPS',
                    value: '${widget.allApps.length}',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    label: 'HIDDEN',
                    value: '${widget.hiddenAppIds.length}',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    label: 'QUICK APPS',
                    value: '${widget.quickAppCount}',
                  ),
                ],
              ),

              // Drawer Display Mode & Search Options
              _buildSectionHeader('APP DRAWER & SEARCH'),

              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTileHeader(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'App Drawer Layout',
                      subtitle: 'Choose grid or list presentation',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildModeButton(
                          mode: DrawerMode.grid,
                          label: 'Grid (4x)',
                          icon: Icons.grid_view_rounded,
                        ),
                        const SizedBox(width: 10),
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

              // Auto-focus Search Bar Toggle
              _buildCard(
                child: _buildTileHeader(
                  icon: Icons.keyboard_alt_outlined,
                  title: 'Auto-Focus Search',
                  subtitle: 'Open keyboard automatically when expanding drawer',
                  trailing: _expressiveSwitch(
                    value: _autoFocus,
                    onChanged: (val) {
                      setState(() => _autoFocus = val);
                      widget.onToggleAutoFocusSearch(val);
                    },
                  ),
                ),
              ),

              // Search Includes Hidden Apps Toggle
              _buildCard(
                child: _buildTileHeader(
                  icon: Icons.visibility_outlined,
                  title: 'Show Hidden Apps in Search',
                  subtitle: 'Include hidden apps in search query results',
                  trailing: _expressiveSwitch(
                    value: _searchIncludesHidden,
                    onChanged: (val) {
                      setState(() => _searchIncludesHidden = val);
                      widget.onToggleSearchIncludesHidden?.call(val);
                    },
                  ),
                ),
              ),

              // Appearance & Theme Section
              _buildSectionHeader('APPEARANCE & THEME'),

              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTileHeader(
                      icon: Icons.palette_outlined,
                      title: 'Accent Color',
                      subtitle: 'Choose wallpaper accent or custom shade',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242A27),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hexCode,
                          style: TextStyle(
                            color: _currentAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                color: Color(0xFF8B9691),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              _showCustomSliders
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF8B9691),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showCustomSliders) ...[
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
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

              // Icon Pack Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTileHeader(
                      icon: Icons.interests_outlined,
                      title: 'Active Icon Pack',
                      subtitle: 'Apply custom icons to installed apps',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Default System'),
                          selected: widget.selectedIconPack == null,
                          selectedColor: _currentAccent,
                          backgroundColor: const Color(0xFF242A27),
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
                            backgroundColor: const Color(0xFF242A27),
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
                  ],
                ),
              ),

              // Profile Section
              _buildSectionHeader('PROFILE & DASHBOARD'),

              _buildCard(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF242A27),
                            backgroundImage: _profilePhoto != null
                                ? MemoryImage(_profilePhoto!)
                                : null,
                            child: _profilePhoto == null
                                ? Icon(
                                    Icons.person_rounded,
                                    color: _currentAccent,
                                    size: 28,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: _currentAccent,
                              child: Icon(
                                Icons.edit_rounded,
                                size: 11,
                                color: LauncherColors.readableOn(_currentAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _profileNameController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (t) => widget.onProfileNameChanged?.call(t),
                        decoration: InputDecoration(
                          labelText: 'Profile name',
                          labelStyle: TextStyle(
                            color: _currentAccent,
                            fontSize: 13,
                          ),
                          hintText: 'Enter your name...',
                          hintStyle: const TextStyle(color: Color(0xFF6C7571), fontSize: 13),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF242A27),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (_profilePhoto != null)
                      IconButton(
                        tooltip: 'Remove photo',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFF8B9691),
                        ),
                        onPressed: () {
                          setState(() => _profilePhoto = null);
                          widget.onProfilePhotoChanged?.call(null);
                        },
                      ),
                  ],
                ),
              ),

              // Ambient Idle Screen Setting
              _buildSectionHeader('AMBIENT SCREEN'),

              _buildCard(
                child: Column(
                  children: [
                    _buildTileHeader(
                      icon: Icons.nightlight_round_outlined,
                      title: 'Ambient Idle Screen',
                      subtitle: 'Dim screen and expand clock after 8s idle',
                      trailing: _expressiveSwitch(
                        value: _ambientIdle,
                        onChanged: (val) {
                          setState(() => _ambientIdle = val);
                          widget.onToggleAmbientIdleMode?.call(val);
                        },
                      ),
                    ),
                    if (_ambientIdle) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ambientTextController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (text) {
                          widget.onAmbientCustomTextChanged?.call(text);
                        },
                        decoration: InputDecoration(
                          labelText: 'Custom Ambient Text',
                          labelStyle: TextStyle(color: _currentAccent, fontSize: 12),
                          hintText: 'e.g. Focus on what matters, breathe...',
                          hintStyle: const TextStyle(color: Color(0xFF6C7571), fontSize: 13),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF242A27),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Hidden Apps Manager
              _buildSectionHeader('APP MANAGEMENT'),

              _buildCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTileHeader(
                      icon: Icons.visibility_off_outlined,
                      title: 'Manage Hidden Apps',
                      subtitle: '${widget.hiddenAppIds.length} apps currently hidden',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search apps to hide or unhide...',
                        hintStyle: const TextStyle(color: Color(0xFF6C7571), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8B9691), size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF242A27),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final isHidden = widget.hiddenAppIds.contains(app.id);
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: SizedBox(
                              width: 32,
                              height: 32,
                              child: app.icon.isNotEmpty
                                  ? Image.memory(
                                      app.icon,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.apps, color: Colors.white54, size: 20),
                                    )
                                  : const Icon(Icons.apps, color: Colors.white54, size: 20),
                            ),
                            title: Text(
                              app.label,
                              style: TextStyle(
                                color: isHidden ? const Color(0xFF8B9691) : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                decoration: isHidden ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: _expressiveSwitch(
                              value: !isHidden,
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

              // Backup & Restore Section
              if (widget.prefs != null && widget.platform != null) ...[
                _buildSectionHeader('BACKUP & RESTORE'),
                _buildCard(
                  child: Column(
                    children: [
                      _buildTileHeader(
                        icon: Icons.cloud_sync_outlined,
                        title: 'Backup & Restore',
                        subtitle: 'Export or import your layout & preferences',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: M3SpringButton(
                              onTap: _exportBackup,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF242A27),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file_rounded, size: 18, color: _currentAccent),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Export',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: M3SpringButton(
                              onTap: _restoreBackup,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF242A27),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded, size: 18, color: _currentAccent),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Restore',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // System Shortcuts Section
              _buildSectionHeader('SYSTEM SHORTCUTS'),

              M3SpringButton(
                onTap: _showAccessibilityDisclosure,
                child: _buildCard(
                  child: _buildTileHeader(
                    icon: Icons.touch_app_outlined,
                    title: 'Double-Tap to Lock Setup',
                    subtitle: 'Enable Fluee Accessibility Service',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ),
                ),
              ),

              M3SpringButton(
                onTap: widget.onOpenNotificationListenerSettings ?? () {},
                child: _buildCard(
                  child: _buildTileHeader(
                    icon: Icons.music_note_rounded,
                    title: 'Now Playing Setup',
                    subtitle: 'Enable Notification Access to detect music',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ),
                ),
              ),

              M3SpringButton(
                onTap: widget.onOpenHomeSettings,
                child: _buildCard(
                  child: _buildTileHeader(
                    icon: Icons.home_outlined,
                    title: 'Default Home App Settings',
                    subtitle: 'Select Fluee as your default launcher',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ),
                ),
              ),

              // Legal & Privacy Section
              _buildSectionHeader('ABOUT & PRIVACY'),

              M3SpringButton(
                onTap: _showPrivacyPolicy,
                child: _buildCard(
                  child: _buildTileHeader(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: '100% offline, zero data collection',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white38,
                      size: 14,
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

  Widget _buildStatCard({
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1F1D),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B9691),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
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
        ),
        alignment: Alignment.center,
        child: isSelected
            ? Icon(Icons.check_rounded, color: fg, size: 20)
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
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B9691),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              activeTrackColor: _currentAccent,
              inactiveTrackColor: const Color(0xFF2E3532),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: _currentAccent.withValues(alpha: 0.15),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? _currentAccent : const Color(0xFF242A27),
            borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? LauncherColors.readableOn(_currentAccent)
                      : Colors.white70,
                  fontSize: 12,
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
        .where((a) => a.label.toLowerCase().contains(_searchQuery))
        .toList();
  }
}
