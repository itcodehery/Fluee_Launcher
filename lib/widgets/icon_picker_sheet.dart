import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../services/launcher_platform.dart';
import '../theme/launcher_colors.dart';
import 'm3_spring_button.dart';

class IconPickerSheet extends StatefulWidget {
  const IconPickerSheet({
    super.key,
    required this.app,
    required this.accent,
    required this.platform,
    required this.availableIconPacks,
    required this.onSelectIcon,
    required this.onResetIcon,
  });

  final AppItem app;
  final Color accent;
  final LauncherPlatform platform;
  final List<IconPackInfo> availableIconPacks;
  final void Function(String packPackage, String drawableName) onSelectIcon;
  final VoidCallback onResetIcon;

  @override
  State<IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<IconPickerSheet> {
  String? _selectedPack;
  List<IconPackDrawable> _drawables = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.availableIconPacks.isNotEmpty) {
      _selectedPack = widget.availableIconPacks.first.packageName;
      _loadDrawables(_selectedPack!);
    }
  }

  Future<void> _loadDrawables(String packPackage) async {
    setState(() {
      _isLoading = true;
      _selectedPack = packPackage;
    });
    final drawables = await widget.platform.getIconPackDrawables(packPackage);
    if (!mounted) return;
    setState(() {
      _drawables = drawables;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: LauncherColors.sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Icon for ${widget.app.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pick an icon from any installed icon pack',
                          style: TextStyle(
                            color: LauncherColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: LauncherColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x22FFFFFF), height: 1),

            if (widget.availableIconPacks.isEmpty) ...[
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style_outlined, color: Colors.white38, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'No icon packs found',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Install compatible icon packs from the Google Play Store to pick individual icons.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: LauncherColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Pack Selector Chips
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: widget.availableIconPacks.length,
                  itemBuilder: (context, index) {
                    final pack = widget.availableIconPacks[index];
                    final isSelected = pack.packageName == _selectedPack;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(pack.label),
                        selectedColor: widget.accent,
                        backgroundColor: LauncherColors.tileBackground,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? LauncherColors.readableOn(widget.accent)
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => _loadDrawables(pack.packageName),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Color(0x18FFFFFF), height: 1),

              // Drawables Grid
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _drawables.length,
                        itemBuilder: (context, index) {
                          final item = _drawables[index];
                          return M3SpringButton(
                            onTap: () {
                              if (_selectedPack != null) {
                                widget.onSelectIcon(_selectedPack!, item.drawableName);
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: LauncherColors.tileBackground,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: item.icon.isNotEmpty
                                  ? Image.memory(
                                      item.icon,
                                      fit: BoxFit.contain,
                                      color: Colors.white,
                                      colorBlendMode: BlendMode.srcIn,
                                    )
                                  : const Icon(Icons.apps, color: Colors.white54),
                            ),
                          );
                        },
                      ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    widget.onResetIcon();
                    Navigator.pop(context);
                  },
                  child: const Text('Reset to Default App Icon', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
