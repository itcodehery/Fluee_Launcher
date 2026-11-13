import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_item.dart';
import '../models/app_shortcut.dart';
import '../services/launcher_preferences.dart';
import '../theme/launcher_colors.dart';
import 'app_tile.dart';
import 'm3_spring_button.dart';

const double dragHandleHeight = 36.0;

const ColorFilter _desaturatedFilter = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class AppPanel extends StatefulWidget {
  const AppPanel({
    super.key,
    required this.apps,
    this.allApps = const [],
    required this.metrics,
    required this.dockHeight,
    required this.isExpanded,
    this.isListMode = false,
    this.drawerMode,
    this.onDrawerModeChanged,
    this.autoFocusSearch = false,
    this.searchIncludesHidden = false,
    this.isIdle = false,
    this.recentAppIds = const [],
    this.sortMode = AppSortMode.az,
    this.onSortModeChanged,
    required this.accent,
    this.shortcuts = const [],
    this.onShortcutTap,
    this.mediaPackageName,
    this.mediaTitle,
    this.mediaArtist,
    this.mediaAlbumArt,
    this.mediaIsPlaying = true,
    required this.onExpandedChanged,
    required this.onAppTap,
    required this.onAppLongPress,
  });

  final List<AppItem> apps;
  final List<AppItem> allApps;
  final TileMetrics metrics;
  final double dockHeight;
  final bool isExpanded;
  final bool isListMode;
  final DrawerMode? drawerMode;
  final ValueChanged<DrawerMode>? onDrawerModeChanged;
  final bool autoFocusSearch;
  final bool searchIncludesHidden;
  final bool isIdle;
  final List<String> recentAppIds;
  final AppSortMode sortMode;
  final ValueChanged<AppSortMode>? onSortModeChanged;
  final Color accent;
  final List<AppShortcut> shortcuts;
  final ValueChanged<AppShortcut>? onShortcutTap;
  final String? mediaPackageName;
  final String? mediaTitle;
  final String? mediaArtist;
  final Uint8List? mediaAlbumArt;
  final bool mediaIsPlaying;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<AppItem> onAppTap;
  final ValueChanged<AppItem> onAppLongPress;

  @override
  State<AppPanel> createState() => _AppPanelState();
}

class _AppPanelState extends State<AppPanel> {
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  double _dragDownDistance = 0;
  bool _expandedTriggeredThisDrag = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AppPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When expanding, auto-focus search if preference is enabled
    if (!oldWidget.isExpanded && widget.isExpanded && widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isExpanded) return;
        _searchFocusNode.requestFocus();
      });
    }

    // When collapsing, reset scroll position to top and clear search safely post-frame
    if (oldWidget.isExpanded && !widget.isExpanded) {
      if (_query.isNotEmpty) {
        _query = '';
        _searchController.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.unfocus();
        if (_scrollController.hasClients && _scrollController.offset > 0) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<AppItem> get _sortedAndFilteredApps {
    final pool =
        (widget.searchIncludesHidden &&
            _query.isNotEmpty &&
            widget.allApps.isNotEmpty)
        ? widget.allApps
        : widget.apps;

    List<AppItem> result;
    if (_query.isEmpty) {
      if (widget.sortMode == AppSortMode.recent) {
        result = List<AppItem>.from(pool);
      } else {
        // Pin recently used apps right at the start of the drawer when not searching
        final recentApps = _recentApps;
        final recentSet = recentApps.map((a) => a.id).toSet();
        final remaining = pool.where((a) => !recentSet.contains(a.id)).toList();

        if (widget.sortMode == AppSortMode.az) {
          remaining.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        } else if (widget.sortMode == AppSortMode.za) {
          remaining.sort((a, b) => b.label.toLowerCase().compareTo(a.label.toLowerCase()));
        }
        result = [...recentApps, ...remaining];
        return result;
      }
    } else {
      result = pool
          .where(
            (a) => a.label.toLowerCase().contains(_query),
          )
          .toList();
    }

    switch (widget.sortMode) {
      case AppSortMode.az:
        result.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        break;
      case AppSortMode.za:
        result.sort((a, b) => b.label.toLowerCase().compareTo(a.label.toLowerCase()));
        break;
      case AppSortMode.recent:
        final recentOrder = {
          for (var i = 0; i < widget.recentAppIds.length; i++)
            widget.recentAppIds[i]: i
        };
        result.sort((a, b) {
          final posA = recentOrder[a.id] ?? 999999;
          final posB = recentOrder[b.id] ?? 999999;
          if (posA != posB) return posA.compareTo(posB);
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
        break;
    }
    return result;
  }

  List<AppShortcut> get _matchingShortcuts {
    if (_query.isEmpty) return const [];
    return widget.shortcuts.where((s) {
      final short = s.shortLabel.toLowerCase();
      final long = s.longLabel?.toLowerCase() ?? '';
      return short.contains(_query) || long.contains(_query);
    }).take(6).toList();
  }

  List<AppItem> get _recentApps {
    if (widget.recentAppIds.isEmpty) return const [];
    final byId = {for (final a in widget.allApps.isNotEmpty ? widget.allApps : widget.apps) a.id: a};
    return widget.recentAppIds
        .map((id) => byId[id])
        .whereType<AppItem>()
        .take(8)
        .toList();
  }

  DrawerMode get _effectiveMode =>
      widget.drawerMode ??
      (widget.isListMode ? DrawerMode.list : DrawerMode.grid);

  Widget _buildAppList(List<AppItem> displayApps, double listBottomPadding) {
    // While searching, results stack up from just above the search bar.
    final reverse = _query.isNotEmpty;
    switch (_effectiveMode) {
      case DrawerMode.list:
        return ListView.builder(
          reverse: reverse,
          controller: _scrollController,
          itemExtent: 64, // performance optimization for 120Hz smooth scrolling
          padding: EdgeInsets.only(
            left: TileMetrics.margin + 6,
            right: TileMetrics.margin + 6,
            top: 4,
            bottom: listBottomPadding,
          ),
          physics: widget.isExpanded
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const NeverScrollableScrollPhysics(),
          itemCount: displayApps.length,
          itemBuilder: (context, index) {
            final app = displayApps[index];
            return M3SpringButton(
              key: ValueKey('${app.id}_$index'),
              onTap: () => widget.onAppTap(app),
              onLongPress: () => widget.onAppLongPress(app),
              pressedScale: 0.97,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: LauncherColors.tileBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.65,
                            heightFactor: 0.65,
                            child: app.icon.isNotEmpty
                                ? (app.isMonochrome
                                      ? Image.memory(
                                          app.icon,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.apps,
                                                    color:
                                                        LauncherColors.tileIcon,
                                                    size: 22,
                                                  ),
                                          color: LauncherColors.tileIcon,
                                          colorBlendMode: BlendMode.srcIn,
                                        )
                                      : ColorFiltered(
                                          colorFilter: _desaturatedFilter,
                                          child: Image.memory(
                                            app.icon,
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.apps,
                                                      color: LauncherColors
                                                          .tileIcon,
                                                      size: 22,
                                                    ),
                                          ),
                                        ))
                                : const Icon(
                                    Icons.apps,
                                    color: LauncherColors.tileIcon,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        app.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

      case DrawerMode.grid:
        final hasActiveMedia = widget.mediaPackageName != null &&
            widget.mediaPackageName!.isNotEmpty &&
            widget.mediaTitle != null &&
            widget.mediaTitle!.isNotEmpty &&
            displayApps.any((a) => a.packageName == widget.mediaPackageName);

        if (!hasActiveMedia) {
          return GridView.builder(
            reverse: reverse,
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: TileMetrics.margin,
              right: TileMetrics.margin,
              top: 4,
              bottom: listBottomPadding,
            ),
            physics: widget.isExpanded
                ? const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  )
                : const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: TileMetrics.columns,
              mainAxisSpacing: TileMetrics.gap,
              crossAxisSpacing: TileMetrics.gap,
            ),
            itemCount: displayApps.length,
            itemBuilder: (context, index) {
              final app = displayApps[index];
              return AppTile(
                key: ValueKey('${app.id}_$index'),
                app: app,
                background: widget.isIdle
                    ? Colors.transparent
                    : LauncherColors.tileBackground,
                transparentBackground: widget.isIdle,
                iconTint: LauncherColors.tileIcon,
                borderRadius: widget.metrics.borderRadius,
                onTap: () => widget.onAppTap(app),
                onLongPress: () => widget.onAppLongPress(app),
              );
            },
          );
        }

        // Pack grid items into 4-column rows where the playing media app spans 2 columns.
        final rows = <List<({AppItem app, bool isMedia, int index})>>[];
        var currentRow = <({AppItem app, bool isMedia, int index})>[];
        var usedCols = 0;
        var matchedMediaApp = false;
        for (var i = 0; i < displayApps.length; i++) {
          final app = displayApps[i];
          final isMedia = !matchedMediaApp &&
              app.packageName == widget.mediaPackageName;
          if (isMedia) matchedMediaApp = true;
          final span = isMedia ? 2 : 1;
          if (usedCols + span > TileMetrics.columns) {
            rows.add(currentRow);
            currentRow = [];
            usedCols = 0;
          }
          currentRow.add((app: app, isMedia: isMedia, index: i));
          usedCols += span;
          if (usedCols >= TileMetrics.columns) {
            rows.add(currentRow);
            currentRow = [];
            usedCols = 0;
          }
        }
        if (currentRow.isNotEmpty) {
          rows.add(currentRow);
        }

        final tileSize = widget.metrics.tileSize;
        return ListView.builder(
          reverse: reverse,
          controller: _scrollController,
          padding: EdgeInsets.only(
            left: TileMetrics.margin,
            right: TileMetrics.margin,
            top: 4,
            bottom: listBottomPadding,
          ),
          physics: widget.isExpanded
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (context, rowIndex) {
            final row = rows[rowIndex];
            final isLast = rowIndex == rows.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : TileMetrics.gap),
              child: Row(
                children: [
                  for (var col = 0; col < row.length; col++) ...[
                    if (col > 0) const SizedBox(width: TileMetrics.gap),
                    if (row[col].isMedia)
                      SizedBox(
                        width: tileSize * 2 + TileMetrics.gap,
                        height: tileSize,
                        child: MediaAppTile(
                          key: ValueKey('media_${row[col].app.id}_${row[col].index}'),
                          app: row[col].app,
                          tileSize: tileSize,
                          title: widget.mediaTitle!,
                          artist: widget.mediaArtist ?? '',
                          albumArt: widget.mediaAlbumArt,
                          accent: widget.accent,
                          isPlaying: widget.mediaIsPlaying,
                          background: widget.isIdle
                              ? Colors.transparent
                              : LauncherColors.tileBackground,
                          borderRadius: widget.metrics.borderRadius,
                          transparentBackground: widget.isIdle,
                          onTap: () => widget.onAppTap(row[col].app),
                          onLongPress: () => widget.onAppLongPress(row[col].app),
                        ),
                      )
                    else
                      SizedBox(
                        width: tileSize,
                        height: tileSize,
                        child: AppTile(
                          key: ValueKey('${row[col].app.id}_${row[col].index}'),
                          app: row[col].app,
                          background: widget.isIdle
                              ? Colors.transparent
                              : LauncherColors.tileBackground,
                          transparentBackground: widget.isIdle,
                          iconTint: LauncherColors.tileIcon,
                          borderRadius: widget.metrics.borderRadius,
                          onTap: () => widget.onAppTap(row[col].app),
                          onLongPress: () => widget.onAppLongPress(row[col].app),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayApps = _sortedAndFilteredApps;
    final listBottomPadding = widget.isExpanded
        ? (widget.dockHeight + 48 + 24)
        : (widget.dockHeight + TileMetrics.gap);

    return Column(
      children: [
        _PanelHandle(
          onToggle: () => widget.onExpandedChanged(!widget.isExpanded),
          onDragUp: () {},
          onDragDown: () => widget.onExpandedChanged(false),
        ),

        Expanded(
          child: Listener(
            onPointerDown: (_) {
              _dragDownDistance = 0;
              _expandedTriggeredThisDrag = false;
            },
            onPointerMove: (event) {
              if (_expandedTriggeredThisDrag) return;
              if (widget.isExpanded) {
                // If at the top of the grid and dragging downward -> collapse
                final isAtTop =
                    !_scrollController.hasClients ||
                    _scrollController.offset <= 0;
                if (isAtTop && event.delta.dy > 0) {
                  _dragDownDistance += event.delta.dy;
                  if (_dragDownDistance > 24) {
                    _expandedTriggeredThisDrag = true;
                    widget.onExpandedChanged(false);
                  }
                } else {
                  _dragDownDistance = 0;
                }
              }
            },
            onPointerUp: (_) {
              _dragDownDistance = 0;
              _expandedTriggeredThisDrag = false;
            },
            onPointerCancel: (_) {
              _dragDownDistance = 0;
              _expandedTriggeredThisDrag = false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is OverscrollNotification) {
                  if (widget.isExpanded && notification.overscroll < -12) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && widget.isExpanded) {
                        widget.onExpandedChanged(false);
                      }
                    });
                  }
                }
                return false;
              },
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) {
                  if (widget.isExpanded) {
                    return const LinearGradient(
                      colors: [Colors.black, Colors.black],
                    ).createShader(rect);
                  }
                  final h = rect.height;
                  if (h <= 0) {
                    return const LinearGradient(
                      colors: [Colors.black, Colors.black],
                    ).createShader(rect);
                  }
                  return const LinearGradient(
                    colors: [Colors.black, Colors.black],
                  ).createShader(rect);
                },
                child: _buildAppList(displayApps, listBottomPadding),
              ),
            ),
          ),
        ),

        // Floating Search Bar positioned neatly ABOVE the persistent dock (no bottom container)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.isExpanded
              ? Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 6,
                    bottom: widget.dockHeight + 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.isNotEmpty && _matchingShortcuts.isNotEmpty) ...[
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _matchingShortcuts.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final s = _matchingShortcuts[index];
                              return M3SpringButton(
                                onTap: () {
                                  widget.onShortcutTap?.call(s);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF222624),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (s.icon.isNotEmpty) ...[
                                        Image.memory(s.icon, width: 16, height: 16),
                                        const SizedBox(width: 6),
                                      ] else ...[
                                        Icon(Icons.bolt_rounded, size: 16, color: widget.accent),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        s.displayLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.accent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                        child: Row(
                          children: [
                            // Filter / Sort Menu Button
                            PopupMenuButton<AppSortMode>(
                          tooltip: 'Sort Apps',
                          color: const Color(0xFF262626),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          initialValue: widget.sortMode,
                          onSelected: (mode) {
                            HapticFeedback.lightImpact();
                            widget.onSortModeChanged?.call(mode);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.tune_rounded,
                              color: LauncherColors.readableOn(widget.accent),
                              size: 22,
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: AppSortMode.az,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                    color: widget.sortMode == AppSortMode.az
                                        ? widget.accent
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'A to Z',
                                    style: TextStyle(
                                      color: widget.sortMode == AppSortMode.az
                                          ? widget.accent
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: AppSortMode.za,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: widget.sortMode == AppSortMode.za
                                        ? widget.accent
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Z to A',
                                    style: TextStyle(
                                      color: widget.sortMode == AppSortMode.za
                                          ? widget.accent
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: AppSortMode.recent,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                    color: widget.sortMode == AppSortMode.recent
                                        ? widget.accent
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Most Recently Used',
                                    style: TextStyle(
                                      color: widget.sortMode == AppSortMode.recent
                                          ? widget.accent
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),

                        // Nested dark pill text field container
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    cursorColor: widget.accent,
                                    textInputAction: TextInputAction.go,
                                    onChanged: (val) {
                                      setState(() => _query = val.trim().toLowerCase());
                                      if (_scrollController.hasClients) {
                                        _scrollController.jumpTo(0);
                                      }
                                    },
                                    onSubmitted: (_) {
                                      if (_query.isEmpty) return;
                                      final results = _sortedAndFilteredApps;
                                      if (results.isNotEmpty) {
                                        widget.onAppTap(results.first);
                                      } else if (_matchingShortcuts.isNotEmpty) {
                                        widget.onShortcutTap?.call(_matchingShortcuts.first);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Search for apps',
                                      hintStyle: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_query.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

class _PanelHandle extends StatefulWidget {
  const _PanelHandle({
    required this.onToggle,
    required this.onDragUp,
    required this.onDragDown,
  });

  final VoidCallback onToggle;
  final VoidCallback onDragUp;
  final VoidCallback onDragDown;

  @override
  State<_PanelHandle> createState() => _PanelHandleState();
}

class _PanelHandleState extends State<_PanelHandle> {
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggle,
      onVerticalDragStart: (_) => _dragDelta = 0,
      onVerticalDragUpdate: (details) {
        _dragDelta += details.delta.dy;
        if (_dragDelta < -12) {
          widget.onDragUp();
        } else if (_dragDelta > 12) {
          widget.onDragDown();
        }
      },
      child: SizedBox(
        height: dragHandleHeight,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: const BoxDecoration(
              color: LauncherColors.dragHandle,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }
}
