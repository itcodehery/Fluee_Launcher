import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../theme/launcher_colors.dart';
import 'app_tile.dart';
import 'dock.dart';
import 'm3_spring_button.dart';

class AppActionsSheet extends StatelessWidget {
  const AppActionsSheet({
    super.key,
    required this.app,
    required this.isPinned,
    required this.isDockFull,
    required this.onTogglePin,
    required this.onChangeIcon,
    required this.onHideApp,
    required this.onAppInfo,
    required this.onUninstall,
  });

  final AppItem app;
  final bool isPinned;
  final bool isDockFull;
  final VoidCallback onTogglePin;
  final VoidCallback onChangeIcon;
  final VoidCallback onHideApp;
  final VoidCallback onAppInfo;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final canPin = isPinned || !isDockFull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                        child: app.icon.isNotEmpty
                            ? Image.memory(
                                app.icon,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.apps,
                                  color: LauncherColors.tileIcon,
                                  size: 26,
                                ),
                                color: app.isMonochrome
                                    ? LauncherColors.tileIcon
                                    : null,
                                colorBlendMode:
                                    app.isMonochrome ? BlendMode.srcIn : null,
                              )
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
                        app.label,
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
                        app.packageName,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0x33FFFFFF), height: 1),
            ),
            _ActionRow(
              icon: Icons.push_pin_outlined,
              title: isPinned
                  ? 'Remove from dock'
                  : (isDockFull
                      ? 'Dock is full ($maxDockApps/$maxDockApps)'
                      : 'Pin to dock'),
              enabled: canPin,
              onTap: onTogglePin,
            ),
            _ActionRow(
              icon: Icons.brush_outlined,
              title: 'Change app icon',
              onTap: onChangeIcon,
            ),
            _ActionRow(
              icon: Icons.visibility_off_outlined,
              title: 'Hide app',
              onTap: onHideApp,
            ),
            _ActionRow(
              icon: Icons.info_outline,
              title: 'App info',
              onTap: onAppInfo,
            ),
            _ActionRow(
              icon: Icons.delete_outline,
              title: 'Uninstall',
              color: LauncherColors.danger,
              onTap: onUninstall,
            ),
          ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
