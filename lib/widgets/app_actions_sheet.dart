import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../models/app_shortcut.dart';
import '../services/launcher_platform.dart';
import '../theme/launcher_colors.dart';
import 'app_tile.dart';
import 'm3_spring_button.dart';

class AppActionsSheet extends StatefulWidget {
  const AppActionsSheet({
    super.key,
    required this.app,
    required this.platform,
    required this.accent,
    required this.isQuickPinned,
    required this.isQuickFull,
    required this.onToggleQuick,
    required this.onRenameApp,
    required this.onChangeIcon,
    required this.onHideApp,
    required this.onAppInfo,
    required this.onUninstall,
    this.onShortcutTap,
    this.pinnedTaskKeys = const {},
    this.onTogglePinShortcut,
  });

  final AppItem app;
  final LauncherPlatform platform;
  final Color accent;
  final bool isQuickPinned;
  final bool isQuickFull;
  final VoidCallback onToggleQuick;
  final VoidCallback onRenameApp;
  final VoidCallback onChangeIcon;
  final VoidCallback onHideApp;
  final VoidCallback onAppInfo;
  final VoidCallback onUninstall;
  final void Function(AppShortcut shortcut)? onShortcutTap;
  final Set<String> pinnedTaskKeys;
  final ValueChanged<AppShortcut>? onTogglePinShortcut;

  @override
  State<AppActionsSheet> createState() => _AppActionsSheetState();
}

class _AppActionsSheetState extends State<AppActionsSheet> {
  List<AppShortcut> _shortcuts = const [];

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    final list = await widget.platform.getAppShortcuts(widget.app.packageName);
    if (!mounted) return;
    setState(() => _shortcuts = list);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Icon + Label Header
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: LauncherColors.tileBackground,
                        borderRadius:
                            BorderRadius.circular(52 * TileMetrics.cornerRatio),
                      ),
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: TileMetrics.iconFraction,
                          heightFactor: TileMetrics.iconFraction,
                          child: widget.app.icon.isNotEmpty
                              ? (widget.app.isMonochrome
                                  ? Image.memory(
                                      widget.app.icon,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.apps,
                                        color: LauncherColors.tileIcon,
                                        size: 26,
                                      ),
                                      color: LauncherColors.tileIcon,
                                      colorBlendMode: BlendMode.srcIn,
                                    )
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0,      0,      0,      1, 0,
                                      ]),
                                      child: Image.memory(
                                        widget.app.icon,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                          Icons.apps,
                                          color: LauncherColors.tileIcon,
                                          size: 26,
                                        ),
                                      ),
                                    ))
                              : const Icon(
                                  Icons.apps,
                                  color: LauncherColors.tileIcon,
                                  size: 26,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LauncherColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Dynamic Shortcuts (if available)
              if (_shortcuts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1F1D),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      for (final s in _shortcuts)
                        Builder(
                          builder: (context) {
                            final isPinned = widget.pinnedTaskKeys
                                .contains('${s.packageName}/${s.id}');
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.pop(context);
                                if (widget.onShortcutTap != null) {
                                  widget.onShortcutTap!(s);
                                } else {
                                  widget.platform.startShortcut(s.packageName, s.id);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF262C29),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: s.icon.isNotEmpty
                                          ? Image.memory(s.icon, width: 22, height: 22)
                                          : Icon(Icons.bolt_rounded, size: 20, color: widget.accent),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        s.displayLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (widget.onTogglePinShortcut != null)
                                      IconButton(
                                        tooltip: isPinned ? 'Unpin quick task' : 'Pin quick task',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          Navigator.pop(context);
                                          widget.onTogglePinShortcut!(s);
                                        },
                                        icon: Icon(
                                          isPinned
                                              ? Icons.push_pin_rounded
                                              : Icons.push_pin_outlined,
                                          size: 18,
                                          color: isPinned ? widget.accent : Colors.white54,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.north_east_rounded,
                                        size: 15,
                                        color: Colors.white38,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Color(0x22FFFFFF), height: 1),
              ),

              _ActionRow(
                icon: Icons.apps_rounded,
                title: widget.isQuickPinned
                    ? 'Remove from quick apps'
                    : (widget.isQuickFull ? 'Quick apps are full' : 'Pin to quick apps'),
                enabled: widget.isQuickPinned || !widget.isQuickFull,
                onTap: widget.onToggleQuick,
              ),
              _ActionRow(
                icon: Icons.edit_outlined,
                title: 'Rename app',
                onTap: widget.onRenameApp,
              ),
              _ActionRow(
                icon: Icons.brush_outlined,
                title: 'Change app icon',
                onTap: widget.onChangeIcon,
              ),
              _ActionRow(
                icon: Icons.visibility_off_outlined,
                title: 'Hide app',
                onTap: widget.onHideApp,
              ),
              _ActionRow(
                icon: Icons.info_outline,
                title: 'App info',
                onTap: widget.onAppInfo,
              ),
              _ActionRow(
                icon: Icons.delete_outline,
                title: 'Uninstall',
                color: LauncherColors.danger,
                onTap: widget.onUninstall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
    this.color = Colors.white,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: M3SpringButton(
        onTap: enabled ? onTap : null,
        pressedScale: 0.96,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
