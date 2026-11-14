import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_item.dart';
import '../models/app_shortcut.dart';
import '../services/launcher_preferences.dart';
import '../theme/launcher_colors.dart';
import '../theme/m3_motion.dart';
import 'app_tile.dart';
import 'm3_spring_button.dart';

const double dragHandleHeight = 36.0;

class _AppCategory {
  const _AppCategory({required this.name, required this.apps});
  final String name;
  final List<AppItem> apps;
}

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
  bool _isCategorized = true;
  bool _isSearchOpen = false;
  String? _expandedCategory;
  double _dragDownDistance = 0;
  bool _expandedTriggeredThisDrag = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.isExpanded && widget.autoFocusSearch) {
      _isSearchOpen = true;
    }
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AppPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isExpanded && widget.isExpanded && widget.autoFocusSearch) {
      setState(() => _isSearchOpen = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isExpanded) return;
        _searchFocusNode.requestFocus();
      });
    }

    if (oldWidget.isExpanded && !widget.isExpanded) {
      if (_query.isNotEmpty || _isSearchOpen) {
        _query = '';
        _isSearchOpen = false;
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
      result = List<AppItem>.from(pool);
    } else {
      result = pool
          .where((a) => a.label.toLowerCase().contains(_query))
          .toList();
    }

    switch (widget.sortMode) {
      case AppSortMode.az:
        result.sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
      case AppSortMode.za:
        result.sort(
          (a, b) => b.label.toLowerCase().compareTo(a.label.toLowerCase()),
        );
      case AppSortMode.recent:
        final recentOrder = {
          for (var i = 0; i < widget.recentAppIds.length; i++)
            widget.recentAppIds[i]: i,
        };
        result.sort((a, b) {
          final posA = recentOrder[a.id] ?? 999999;
          final posB = recentOrder[b.id] ?? 999999;
          if (posA != posB) return posA.compareTo(posB);
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
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

  String _categoryForApp(AppItem app) {
    final key = '${app.packageName} ${app.label}'.toLowerCase();
    if (_matchesAny(key, const [
      'setting',
      'files',
      'clock',
      'alarm',
      'calculator',
      'calendar',
      'vending',
      'play store',
      'system',
      'security',
      'battery',
    ])) {
      return 'Settings';
    }
    if (_matchesAny(key, const [
      'contact',
      'dialer',
      'phone',
      'sms',
      'messaging',
      'messages',
      'whatsapp',
      'telegram',
      'signal',
      'discord',
      'slack',
      'teams',
      'zoom',
      'meet',
    ])) {
      return 'Contacts';
    }
    if (_matchesAny(key, const [
      'chrome',
      'browser',
      'firefox',
      'brave',
      'edge',
      'opera',
      'duckduckgo',
      'maps',
      'earth',
      'search',
      'wikipedia',
      'reddit',
    ])) {
      return 'Internet';
    }
    if (_matchesAny(key, const [
      'game',
      'unity',
      'roblox',
      'minecraft',
      'chess',
      'puzzle',
      'arcade',
      'pubg',
      'clash',
    ])) {
      return 'Games';
    }
    if (_matchesAny(key, const [
      'youtube',
      'spotify',
      'music',
      'photo',
      'gallery',
      'camera',
      'vlc',
      'netflix',
      'twitch',
      'podcast',
      'audio',
      'video',
      'media',
    ])) {
      return 'Media';
    }
    if (_matchesAny(key, const [
      'mail',
      'gmail',
      'outlook',
      'docs',
      'sheets',
      'drive',
      'keep',
      'note',
      'task',
      'todo',
      'notion',
      'obsidian',
    ])) {
      return 'Productivity';
    }
    return 'Utilities';
  }

  bool _matchesAny(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n)) return true;
    }
    return false;
  }

  List<_AppCategory> _buildCategories(List<AppItem> apps) {
    const order = [
      'Settings',
      'Contacts',
      'Internet',
      'Games',
      'Media',
      'Productivity',
      'Utilities',
    ];
    final buckets = <String, List<AppItem>>{};
    for (final app in apps) {
      final cat = _categoryForApp(app);
      (buckets[cat] ??= <AppItem>[]).add(app);
    }
    final categories = <_AppCategory>[];
    for (final name in order) {
      final list = buckets[name];
      if (list != null && list.isNotEmpty) {
        categories.add(_AppCategory(name: name, apps: list));
      }
    }
    return categories;
  }

  Widget _buildAppIconTile(AppItem app, Color tileSurface) {
    return M3SpringButton(
      key: ValueKey('drawer-tile-${app.id}'),
      onTap: () => widget.onAppTap(app),
      onLongPress: () => widget.onAppLongPress(app),
      pressedScale: 0.90,
      child: Tooltip(
        message: app.label,
        child: Container(
          decoration: BoxDecoration(
            color: tileSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: 0.54,
            heightFactor: 0.54,
            child: app.icon.isNotEmpty
                ? (app.isMonochrome
                    ? Image.memory(
                        app.icon,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        color: widget.accent,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.apps_rounded,
                          color: widget.accent,
                          size: 26,
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
                          errorBuilder: (_, _, _) => Icon(
                            Icons.apps_rounded,
                            color: widget.accent,
                            size: 26,
                          ),
                        ),
                      ))
                : Icon(
                    Icons.apps_rounded,
                    color: widget.accent,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorizedBody(
    List<AppItem> apps,
    Color cardSurface,
    Color tileSurface,
  ) {
    final categories = _buildCategories(apps);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        widget.dockHeight + 88,
      ),
      physics: widget.isExpanded
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isCategoryExpanded = _expandedCategory == category.name;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _expandedCategory = isCategoryExpanded ? null : category.name;
            });
          },
          child: AnimatedContainer(
            duration: M3Motion.defaultSpatial.duration,
            curve: M3Motion.defaultSpatial,
            padding: EdgeInsets.fromLTRB(
              20,
              isCategoryExpanded ? 18 : 20,
              20,
              isCategoryExpanded ? 12 : 20,
            ),
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: AnimatedSize(
              duration: M3Motion.defaultSpatial.duration,
              curve: M3Motion.defaultSpatial,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.plusJakartaSans(
                          color: widget.accent,
                          fontSize: isCategoryExpanded ? 17 : 28,
                          fontWeight: isCategoryExpanded
                              ? FontWeight.w600
                              : FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        '${category.apps.length}',
                        style: GoogleFonts.plusJakartaSans(
                          color: widget.accent.withValues(alpha: 0.78),
                          fontSize: isCategoryExpanded ? 13.5 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (isCategoryExpanded) ...[
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: category.apps.length,
                      itemBuilder: (context, appIdx) => _buildAppIconTile(
                        category.apps[appIdx],
                        tileSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: widget.accent,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllAppsBody(
    List<AppItem> apps,
    Color cardSurface,
    Color tileSurface,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_isSearchOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: widget.accent,
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: TextStyle(
                    color: widget.accent.withValues(alpha: 0.50),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: widget.accent,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: tileSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_query.isNotEmpty && _matchingShortcuts.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _matchingShortcuts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final s = _matchingShortcuts[index];
                    return M3SpringButton(
                      onTap: () => widget.onShortcutTap?.call(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tileSurface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 15,
                              color: widget.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.displayLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
          ],
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                widget.dockHeight + 88,
              ),
              physics: widget.isExpanded
                  ? const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    )
                  : const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: apps.length,
              itemBuilder: (context, index) =>
                  _buildAppIconTile(apps[index], tileSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleButton({
    required IconData icon,
    required bool active,
    required Color inactiveSurface,
    required VoidCallback onTap,
  }) {
    return M3SpringButton(
      onTap: onTap,
      pressedScale: 0.90,
      child: AnimatedContainer(
        duration: M3Motion.fastEffects.duration,
        curve: M3Motion.fastEffects,
        width: 42,
        height: 36,
        decoration: BoxDecoration(
          color: active ? widget.accent : inactiveSurface,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: active ? LauncherColors.readableOn(widget.accent) : widget.accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayApps = _sortedAndFilteredApps;
    final cardSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.12),
      const Color(0xFF0A120D),
    );
    final tileSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: 0.16),
      const Color(0xFF132219),
    );

    final showAllApps = !_isCategorized || _isSearchOpen;

    return ColoredBox(
      color: LauncherColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final headerHeight =
              (constraints.maxHeight * 0.21).clamp(132.0, 200.0);

          return Stack(
            children: [
              // Top radial accent glow in the upper 22% header area
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight + 80,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -1.05),
                        radius: 0.95,
                        colors: [
                          widget.accent.withValues(alpha: 0.34),
                          widget.accent.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              Column(
                children: [
                  // Top ~22% Header: Title + App Count (tap to collapse)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onExpandedChanged(false),
                    child: SizedBox(
                      height: headerHeight,
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.only(top: topPadding + 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: M3Motion.fastEffects.duration,
                              child: Text(
                                showAllApps ? 'All Apps' : 'Apps',
                                key: ValueKey(showAllApps),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${displayApps.length}',
                              style: GoogleFonts.plusJakartaSans(
                                color: widget.accent,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right-aligned Categorized / All Apps mode toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildModeToggleButton(
                          icon: Icons.filter_list_rounded,
                          active: !showAllApps,
                          inactiveSurface: cardSurface,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isCategorized = true;
                              _isSearchOpen = false;
                              _query = '';
                              _searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildModeToggleButton(
                          icon: Icons.grid_view_rounded,
                          active: showAllApps,
                          inactiveSurface: cardSurface,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isCategorized = false);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Bottom ~75-78% Apps Container
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) {
                        _dragDownDistance = 0;
                        _expandedTriggeredThisDrag = false;
                      },
                      onPointerMove: (event) {
                        if (_expandedTriggeredThisDrag) return;
                        if (widget.isExpanded) {
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
                          if (notification is OverscrollNotification &&
                              widget.isExpanded &&
                              notification.overscroll < -12) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && widget.isExpanded) {
                                widget.onExpandedChanged(false);
                              }
                            });
                          }
                          return false;
                        },
                        child: AnimatedSwitcher(
                          duration: M3Motion.fastEffects.duration,
                          switchInCurve: M3Motion.fastEffects,
                          switchOutCurve: M3Motion.fastEffects,
                          child: showAllApps
                              ? KeyedSubtree(
                                  key: const ValueKey('all-apps-body'),
                                  child: _buildAllAppsBody(
                                    displayApps,
                                    cardSurface,
                                    tileSurface,
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('categorized-body'),
                                  child: _buildCategorizedBody(
                                    displayApps,
                                    cardSurface,
                                    tileSurface,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Floating Search Button (bottom-right)
              Positioned(
                right: 22,
                bottom: widget.dockHeight + 18,
                child: M3SpringButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (_isSearchOpen) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _searchFocusNode.requestFocus();
                        });
                      } else {
                        _query = '';
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                      }
                    });
                  },
                  pressedScale: 0.90,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      color: LauncherColors.readableOn(widget.accent),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
