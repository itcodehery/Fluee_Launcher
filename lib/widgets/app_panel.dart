import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../theme/launcher_colors.dart';
import 'app_tile.dart';
import 'm3_spring_button.dart';

const double dragHandleHeight = 36.0;

class AppPanel extends StatefulWidget {
  const AppPanel({
    super.key,
    required this.apps,
    this.allApps = const [],
    required this.metrics,
    required this.dockHeight,
    required this.isExpanded,
    required this.isListMode,
    this.autoFocusSearch = false,
    this.searchIncludesHidden = false,
    required this.accent,
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
  final bool autoFocusSearch;
  final bool searchIncludesHidden;
  final Color accent;
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
  double _dragUpDistance = 0;
  bool _expandedTriggeredThisDrag = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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

  List<AppItem> get _filteredApps {
    final pool = (widget.searchIncludesHidden &&
            _query.isNotEmpty &&
            widget.allApps.isNotEmpty)
        ? widget.allApps
        : widget.apps;
    if (_query.isEmpty) return pool;
    return pool
        .where((a) =>
            a.label.toLowerCase().contains(_query) ||
            a.packageName.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayApps = _filteredApps;
    final listBottomPadding = widget.isExpanded
        ? 12.0
        : (widget.dockHeight + TileMetrics.gap);

    return Column(
      children: [
        _PanelHandle(
          onToggle: () => widget.onExpandedChanged(!widget.isExpanded),
          onDragUp: () => widget.onExpandedChanged(true),
          onDragDown: () => widget.onExpandedChanged(false),
        ),

        Expanded(
          child: Listener(
            onPointerDown: (_) {
              _dragDownDistance = 0;
              _dragUpDistance = 0;
              _expandedTriggeredThisDrag = false;
            },
            onPointerMove: (event) {
              if (_expandedTriggeredThisDrag) return;
              if (widget.isExpanded) {
                // If at the top of the grid and dragging downward -> collapse
                final isAtTop = !_scrollController.hasClients ||
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
              } else {
                // If NOT expanded and dragging upward -> expand
                if (event.delta.dy < 0) {
                  _dragUpDistance += -event.delta.dy;
                  if (_dragUpDistance > 24) {
                    _expandedTriggeredThisDrag = true;
                    widget.onExpandedChanged(true);
                  }
                } else {
                  _dragUpDistance = 0;
                }
              }
            },
            onPointerUp: (_) {
              _dragDownDistance = 0;
              _dragUpDistance = 0;
              _expandedTriggeredThisDrag = false;
            },
            onPointerCancel: (_) {
              _dragDownDistance = 0;
              _dragUpDistance = 0;
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
                  } else if (!widget.isExpanded && notification.overscroll > 12) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !widget.isExpanded) {
                        widget.onExpandedChanged(true);
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
                  final dockTop = (h - widget.dockHeight).clamp(0.0, h);
                  final fadeStart =
                      ((dockTop - widget.metrics.tileSize * 0.5) / h)
                          .clamp(0.0, 1.0);
                  final fadeEnd =
                      ((dockTop + widget.metrics.tileSize * 0.35) / h)
                          .clamp(fadeStart, 1.0);

                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, fadeStart, fadeEnd, 1.0],
                    colors: const [
                      Colors.black,
                      Colors.black,
                      Color(0x40000000),
                      Color(0x40000000),
                    ],
                  ).createShader(rect);
                },
                child: widget.isListMode
                    ? ListView.builder(
                        controller: _scrollController,
                        itemExtent: 64, // performance optimization for 120Hz smooth scrolling
                        padding: EdgeInsets.only(
                          left: TileMetrics.margin + 6,
                          right: TileMetrics.margin + 6,
                          top: 4,
                          bottom: listBottomPadding,
                        ),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
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
                                              ? Image.memory(
                                                  app.icon,
                                                  fit: BoxFit.contain,
                                                  gaplessPlayback: true,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.apps, color: LauncherColors.tileIcon, size: 22),
                                                  color: app.isMonochrome
                                                      ? LauncherColors.tileIcon
                                                      : null,
                                                  colorBlendMode: app.isMonochrome
                                                      ? BlendMode.srcIn
                                                      : null,
                                                )
                                              : const Icon(Icons.apps, color: LauncherColors.tileIcon, size: 22),
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
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: TileMetrics.margin,
                          right: TileMetrics.margin,
                          top: 4,
                          bottom: listBottomPadding,
                        ),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
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
                            background: LauncherColors.tileBackground,
                            iconTint: LauncherColors.tileIcon,
                            borderRadius: widget.metrics.borderRadius,
                            onTap: () => widget.onAppTap(app),
                            onLongPress: () => widget.onAppLongPress(app),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),

        // Animated Search Bar positioned neatly ABOVE the persistent dock
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
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                            decoration: const InputDecoration(
                              hintText: 'Search apps...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
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
                            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                          ),
                      ],
                    ),
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
