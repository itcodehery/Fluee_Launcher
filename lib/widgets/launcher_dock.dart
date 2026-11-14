import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_item.dart';
import '../theme/app_shapes.dart';
import '../theme/m3_motion.dart';
import 'm3_spring_button.dart';

/// Total slots in the continuous one-by-one swipable dock.
const int maxDockApps = 10;

/// Expressive continuous dock carousel that swipes through apps one by one,
/// smoothly scaling the centered highlighted app larger with its label pill.
class LauncherDock extends StatefulWidget {
  const LauncherDock({
    super.key,
    required this.slots,
    required this.accent,
    required this.onAppTap,
    required this.onAppLongPress,
    required this.onEmptySlotTap,
  });

  /// Exactly [maxDockApps] entries; null means an empty configurable slot.
  final List<AppItem?> slots;
  final Color accent;
  final ValueChanged<AppItem> onAppTap;
  final void Function(int slotIndex, AppItem app) onAppLongPress;
  final ValueChanged<int> onEmptySlotTap;

  @override
  State<LauncherDock> createState() => _LauncherDockState();
}

class _LauncherDockState extends State<LauncherDock> {
  static const int _initialCenterIndex = 2;

  late final PageController _pageController;
  int _highlightedIndex = _initialCenterIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.20,
      initialPage: _initialCenterIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _sizeForDistance(double distance) {
    if (distance <= 1.0) {
      return lerpDouble(82.0, 54.0, distance)!;
    }
    if (distance <= 2.0) {
      return lerpDouble(54.0, 42.0, distance - 1.0)!;
    }
    return 42.0;
  }

  double _opacityForDistance(double distance) {
    if (distance <= 1.0) {
      return lerpDouble(1.0, 0.86, distance)!;
    }
    if (distance <= 2.0) {
      return lerpDouble(0.86, 0.68, distance - 1.0)!;
    }
    return 0.68;
  }

  AppIconShape _shapeForSlot(int index, AppItem? app, bool isFocused) {
    if (isFocused) return AppIconShape.roundedSquare;
    if (app != null) return appShapeForId(app.id);
    switch (index % 5) {
      case 1:
        return AppIconShape.circle;
      case 3:
        return AppIconShape.cookie;
      default:
        return AppIconShape.roundedSquare;
    }
  }

  Widget _buildAppIcon(AppItem app, Color iconColor, double fallbackSize) {
    if (app.icon.isEmpty) {
      return Icon(Icons.apps_rounded, color: iconColor, size: fallbackSize);
    }
    if (app.isMonochrome) {
      return Image.memory(
        app.icon,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        color: iconColor,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, _, _) =>
            Icon(Icons.apps_rounded, color: iconColor, size: fallbackSize),
      );
    }
    return ColorFiltered(
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
        errorBuilder: (_, _, _) =>
            Icon(Icons.apps_rounded, color: iconColor, size: fallbackSize),
      ),
    );
  }

  Widget _buildSlot(int index, double currentPage) {
    final app = index < widget.slots.length ? widget.slots[index] : null;
    final delta = index - currentPage;
    final distance = delta.abs();
    final size = _sizeForDistance(distance);
    final opacity = _opacityForDistance(distance);
    final isFocused = distance < 0.45;
    // Equalize visual gaps between the outer 42px icons and inner 54px/82px icons.
    final shiftX = distance > 1.0
        ? -delta.sign * 17.0 * (distance - 1.0).clamp(0.0, 1.5)
        : 0.0;

    final surfaceAlpha = lerpDouble(0.16, 0.11, distance.clamp(0.0, 1.0))!;
    final surface = Color.alphaBlend(
      widget.accent.withValues(alpha: surfaceAlpha),
      const Color(0xFF0A120D),
    );
    final iconColor = widget.accent.withValues(alpha: opacity);
    final shape = _shapeForSlot(index, app, isFocused);
    final border = isFocused
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
        : appShapeBorder(shape, size);

    return Transform.translate(
      offset: Offset(shiftX, 0),
      child: Center(
        child: M3SpringButton(
        onTap: () {
          HapticFeedback.lightImpact();
          if (app != null) {
            widget.onAppTap(app);
          } else {
            widget.onEmptySlotTap(index);
          }
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (app != null) {
            widget.onAppLongPress(index, app);
          } else {
            widget.onEmptySlotTap(index);
          }
        },
        pressedScale: 0.88,
        child: Container(
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: surface,
            shape: border,
          ),
          child: Center(
            child: app == null
                ? Icon(
                    Icons.add_rounded,
                    color: iconColor.withValues(alpha: isFocused ? 0.65 : 0.45),
                    size: lerpDouble(28, 18, (distance / 2.0).clamp(0.0, 1.0))!,
                  )
                : FractionallySizedBox(
                    widthFactor: isFocused ? 0.48 : 0.54,
                    heightFactor: isFocused ? 0.48 : 0.54,
                    child: _buildAppIcon(app, iconColor, isFocused ? 34 : 22),
                  ),
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightedApp = _highlightedIndex < widget.slots.length
        ? widget.slots[_highlightedIndex]
        : null;
    final centerLabel = highlightedApp?.label ?? 'Tap + to add';

    final pillSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.13),
      const Color(0xFF0A120D),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 92,
          child: PageView.builder(
            controller: _pageController,
            itemCount: maxDockApps,
            padEnds: true,
            onPageChanged: (index) {
              if (_highlightedIndex != index) {
                HapticFeedback.selectionClick();
                setState(() => _highlightedIndex = index);
              }
            },
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) {
                  final page = (_pageController.hasClients &&
                          _pageController.position.haveDimensions)
                      ? (_pageController.page ?? _highlightedIndex.toDouble())
                      : _highlightedIndex.toDouble();
                  return _buildSlot(index, page);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: M3Motion.fastEffects.duration,
          switchInCurve: M3Motion.fastSpatial,
          switchOutCurve: M3Motion.fastEffects,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey<String>('dock-label-$_highlightedIndex-$centerLabel'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: pillSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              centerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: widget.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
