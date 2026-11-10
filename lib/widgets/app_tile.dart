import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../theme/launcher_colors.dart';
import 'm3_spring_button.dart';

/// Shared geometry for the 4-column app grid and 4-slot dock.
class TileMetrics {
  TileMetrics.forWidth(double width)
      : tileSize = (width - margin * 2 - gap * (columns - 1)) / columns;

  static const int columns = 4;
  static const double margin = 8.0;
  static const double gap = 10.0;
  static const double cornerRatio = 0.26;
  static const double iconFraction = 0.63;

  final double tileSize;

  BorderRadius get borderRadius =>
      BorderRadius.circular(tileSize * cornerRatio);
}

class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.app,
    required this.background,
    required this.iconTint,
    required this.borderRadius,
    required this.onTap,
    required this.onLongPress,
  });

  final AppItem app;
  final Color background;
  final Color iconTint;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return M3SpringButton(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.90,
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: borderRadius,
          ),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: TileMetrics.iconFraction,
              heightFactor: TileMetrics.iconFraction,
              child: app.icon.isNotEmpty
                  ? Image.memory(
                      app.icon,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.apps,
                        color: app.isMonochrome
                            ? iconTint
                            : LauncherColors.tileIcon,
                        size: 28,
                      ),
                      color: app.isMonochrome ? iconTint : null,
                      colorBlendMode:
                          app.isMonochrome ? BlendMode.srcIn : null,
                    )
                  : Icon(
                      Icons.apps,
                      color: app.isMonochrome
                          ? iconTint
                          : LauncherColors.tileIcon,
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
