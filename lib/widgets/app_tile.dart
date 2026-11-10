import 'package:flutter/material.dart';
import '../models/app_item.dart';
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
    this.transparentBackground = false,
  });

  final AppItem app;
  final Color background;
  final Color iconTint;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    return M3SpringButton(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.90,
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: transparentBackground ? Colors.transparent : background,
            borderRadius: borderRadius,
          ),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: TileMetrics.iconFraction,
              heightFactor: TileMetrics.iconFraction,
              child: app.icon.isNotEmpty
                  ? (app.isMonochrome
                      ? Image.memory(
                          app.icon,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          color: iconTint,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.apps,
                            color: iconTint,
                            size: 28,
                          ),
                        )
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                          child: Image.memory(
                            app.icon,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.apps,
                              color: iconTint,
                              size: 28,
                            ),
                          ),
                        ))
                  : Icon(
                      Icons.apps,
                      color: iconTint,
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
