import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../models/app_shortcut.dart';
import '../theme/launcher_colors.dart';
import 'app_tile.dart';
import 'm3_spring_button.dart';

/// Horizontal row of up to 2 pinned app quick tasks shown above the dock handle.
class QuickTasksBar extends StatelessWidget {
  const QuickTasksBar({
    super.key,
    required this.tasks,
    required this.shortcuts,
    required this.accent,
    required this.onTaskTap,
    required this.onTaskLongPress,
    required this.onAddTap,
  });

  final List<PinnedQuickTask> tasks;
  final List<AppShortcut> shortcuts;
  final Color accent;
  final ValueChanged<PinnedQuickTask> onTaskTap;
  final void Function(int index, PinnedQuickTask task) onTaskLongPress;
  final VoidCallback onAddTap;

  static const double barHeight = 44.0;

  AppShortcut? _findShortcut(PinnedQuickTask task) {
    for (final s in shortcuts) {
      if (s.packageName == task.packageName && s.id == task.shortcutId) {
        return s;
      }
    }
    return null;
  }

  Widget _buildTaskPill(BuildContext context, int index, PinnedQuickTask task) {
    final shortcut = _findShortcut(task);
    final hasIcon = shortcut != null && shortcut.icon.isNotEmpty;

    return Expanded(
      child: M3SpringButton(
        onTap: () => onTaskTap(task),
        onLongPress: () => onTaskLongPress(index, task),
        pressedScale: 0.95,
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (hasIcon)
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ]),
                  child: Image.memory(
                    shortcut.icon,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPill() {
    return Expanded(
      child: M3SpringButton(
        onTap: onAddTap,
        pressedScale: 0.95,
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 17,
                color: Colors.white.withValues(alpha: 0.48),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Pin task',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TileMetrics.margin),
      child: Row(
        children: [
          _buildTaskPill(context, 0, tasks[0]),
          const SizedBox(width: 8),
          if (tasks.length > 1)
            _buildTaskPill(context, 1, tasks[1])
          else
            _buildAddPill(),
        ],
      ),
    );
  }
}

/// Bottom sheet allowing the user to search and pick an app shortcut to pin.
class QuickTaskPickerSheet extends StatefulWidget {
  const QuickTaskPickerSheet({
    super.key,
    required this.shortcuts,
    required this.apps,
    required this.accent,
    required this.pinnedKeys,
    required this.onSelected,
  });

  final List<AppShortcut> shortcuts;
  final List<AppItem> apps;
  final Color accent;
  final Set<String> pinnedKeys;
  final ValueChanged<AppShortcut> onSelected;

  @override
  State<QuickTaskPickerSheet> createState() => _QuickTaskPickerSheetState();
}

class _QuickTaskPickerSheetState extends State<QuickTaskPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLabelByPkg = {
      for (final a in widget.apps) a.packageName: a.label,
    };

    final filtered = widget.shortcuts.where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final appName = (appLabelByPkg[s.packageName] ?? s.packageName).toLowerCase();
      return s.displayLabel.toLowerCase().contains(q) ||
          s.shortLabel.toLowerCase().contains(q) ||
          appName.contains(q);
    }).toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LauncherColors.dragHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pin quick task',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose an app action like Scan QR or New Task',
                style: TextStyle(
                  color: LauncherColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: widget.accent,
                decoration: InputDecoration(
                  hintText: 'Search tasks or apps...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF242424),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.shortcuts.isEmpty
                              ? 'No app quick tasks available'
                              : 'No matching tasks found',
                          style: const TextStyle(color: LauncherColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final s = filtered[index];
                          final appName = appLabelByPkg[s.packageName] ?? s.packageName;
                          final isPinned = widget.pinnedKeys.contains('${s.packageName}/${s.id}');
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF262C29),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: s.icon.isNotEmpty
                                  ? Image.memory(
                                      s.icon,
                                      width: 24,
                                      height: 24,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.bolt_rounded,
                                        color: widget.accent,
                                        size: 20,
                                      ),
                                    )
                                  : Icon(Icons.bolt_rounded, color: widget.accent, size: 20),
                            ),
                            title: Text(
                              s.displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: LauncherColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isPinned
                                ? Icon(Icons.push_pin_rounded, color: widget.accent, size: 18)
                                : null,
                            onTap: () => widget.onSelected(s),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
