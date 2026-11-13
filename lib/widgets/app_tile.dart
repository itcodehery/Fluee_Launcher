import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../theme/app_shapes.dart';
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
    this.shape,
  });

  final AppItem app;
  final Color background;
  final Color iconTint;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool transparentBackground;
  final AppIconShape? shape;

  @override
  Widget build(BuildContext context) {
    // When in ambient mode (transparent background on black screen), use pure white for monochrome icons
    // so they remain clearly visible rather than blending into darkness.
    final effectiveIconTint = transparentBackground ? Colors.white : iconTint;
    final resolvedShape = shape ?? appShapeForId(app.id);

    return M3SpringButton(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.90,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shapeBorder = appShapeBorder(resolvedShape, constraints.maxWidth);
            return AnimatedContainer(
              duration: Duration(milliseconds: transparentBackground ? 1000 : 320),
              curve: Curves.easeOutCubic,
              decoration: ShapeDecoration(
                color: transparentBackground ? Colors.transparent : background,
                shape: shapeBorder,
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
                          color: effectiveIconTint,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.apps,
                            color: effectiveIconTint,
                            size: 28,
                          ),
                        )
                      : ColorFiltered(
                          colorFilter: transparentBackground
                              ? const ColorFilter.matrix(<double>[
                                  0.26, 0.75, 0.10, 0, 45,
                                  0.26, 0.75, 0.10, 0, 45,
                                  0.26, 0.75, 0.10, 0, 45,
                                  0,    0,    0,    1, 0,
                                ])
                              : const ColorFilter.matrix(<double>[
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
                              color: effectiveIconTint,
                              size: 28,
                            ),
                          ),
                        ))
                  : Icon(
                      Icons.apps,
                      color: effectiveIconTint,
                      size: 28,
                    ),
            ),
          ),
            );
          },
        ),
      ),
    );
  }
}

/// 2-column pill tile shown in place of the currently playing media app in the grid.
class MediaAppTile extends StatelessWidget {
  const MediaAppTile({
    super.key,
    required this.app,
    required this.tileSize,
    required this.title,
    required this.artist,
    required this.albumArt,
    required this.accent,
    required this.onTap,
    required this.onLongPress,
    this.isPlaying = true,
    this.background = const Color(0xFF141414),
    this.borderRadius,
    this.transparentBackground = false,
  });

  final AppItem app;
  final double tileSize;
  final String title;
  final String artist;
  final Uint8List? albumArt;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isPlaying;
  final Color background;
  final BorderRadius? borderRadius;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    // Smaller artwork + no wasted vertical padding leaves more room for the title/artist
    // inside a 2-column tile.
    final artSize = tileSize * 0.62;
    final hasArt = albumArt != null && albumArt!.isNotEmpty;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final artCacheWidth = (artSize * dpr).round();

    return M3SpringButton(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: Duration(milliseconds: transparentBackground ? 1000 : 320),
        curve: Curves.easeOutCubic,
        height: tileSize,
        padding: EdgeInsets.symmetric(horizontal: (tileSize - artSize) / 2),
        decoration: BoxDecoration(
          color: transparentBackground ? Colors.transparent : background,
          borderRadius: borderRadius ?? BorderRadius.circular(tileSize / 2),
          border: transparentBackground
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: artSize,
                height: artSize,
                child: hasArt
                    ? Image.memory(
                        albumArt!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: artCacheWidth,
                        errorBuilder: (_, _, _) => _fallbackArt(artSize),
                      )
                    : _fallbackArt(artSize),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isPlaying ? 1.0 : 0.72),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.15,
                    ),
                  ),
                  if (artist.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: isPlaying ? 0.62 : 0.45),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isPlaying)
              _MiniWaveform(color: accent)
            else
              Icon(Icons.pause_rounded, color: accent, size: 16),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _fallbackArt(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF262626),
      alignment: Alignment.center,
      child: app.icon.isNotEmpty
          ? Image.memory(
              app.icon,
              width: size * 0.6,
              height: size * 0.6,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            )
          : Icon(Icons.music_note_rounded, color: accent, size: size * 0.5),
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 12.0, 16.0, 10.0, 7.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < heights.length; i++) ...[
          if (i > 0) const SizedBox(width: 2.2),
          Container(
            width: 2.2,
            height: heights[i],
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ],
    );
  }
}
