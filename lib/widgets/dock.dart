import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_item.dart';
import '../theme/launcher_colors.dart';
import 'app_tile.dart';

const int maxDockApps = 4;

class Dock extends StatelessWidget {
  const Dock({
    super.key,
    required this.apps,
    required this.accent,
    required this.metrics,
    required this.onAppTap,
    required this.onAppLongPress,
    required this.onReorder,
    this.transparentBackground = false,
  });

  final List<AppItem> apps;
  final Color accent;
  final TileMetrics metrics;
  final ValueChanged<AppItem> onAppTap;
  final ValueChanged<AppItem> onAppLongPress;
  final void Function(int oldIndex, int newIndex) onReorder;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    final iconTint = LauncherColors.readableOn(accent);
    final count = apps.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TileMetrics.margin),
      child: Row(
        children: [
          for (var i = 0; i < maxDockApps; i++) ...[
            if (i > 0) const SizedBox(width: TileMetrics.gap),
            Expanded(
              child: i < count
                  ? DragTarget<int>(
                      onWillAcceptWithDetails: (details) =>
                          details.data != i && i < count,
                      onAcceptWithDetails: (details) {
                        HapticFeedback.mediumImpact();
                        onReorder(details.data, i);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isDropTarget = candidateData.isNotEmpty;
                        final app = apps[i];

                        return LongPressDraggable<int>(
                          data: i,
                          delay: const Duration(milliseconds: 220),
                          onDragStarted: () {
                            HapticFeedback.heavyImpact();
                          },
                          onDraggableCanceled: (_, _) {
                            onAppLongPress(app);
                          },
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: metrics.tileSize,
                              height: metrics.tileSize,
                              child: Transform.scale(
                                scale: 1.12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: metrics.borderRadius,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.45),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: AppTile(
                                    app: app,
                                    background: accent,
                                    iconTint: iconTint,
                                    borderRadius: metrics.borderRadius,
                                    onTap: () {},
                                    onLongPress: () {},
                                  ),
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.25,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: metrics.borderRadius,
                                ),
                              ),
                            ),
                          ),
                          child: AnimatedScale(
                            scale: isDropTarget ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: Container(
                              decoration: isDropTarget
                                  ? BoxDecoration(
                                      borderRadius: metrics.borderRadius,
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.5),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: AppTile(
                                app: app,
                                background: accent,
                                iconTint: iconTint,
                                borderRadius: metrics.borderRadius,
                                transparentBackground: transparentBackground,
                                onTap: () => onAppTap(app),
                                onLongPress: () {}, // Long-press in dock is reserved for drag reordering
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const AspectRatio(aspectRatio: 1),
            ),
          ],
        ],
      ),
    );
  }
}
