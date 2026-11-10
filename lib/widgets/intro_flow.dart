import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/launcher_colors.dart';

class IntroFlow extends StatefulWidget {
  const IntroFlow({
    super.key,
    required this.initialAccent,
    required this.wallpaperAccent,
    required this.onComplete,
    required this.onOpenHomeSettings,
  });

  final Color initialAccent;
  final Color? wallpaperAccent;
  final ValueChanged<Color> onComplete;
  final VoidCallback onOpenHomeSettings;

  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late Color _selectedAccent;
  bool _isWallpaperSelected = false;

  @override
  void initState() {
    super.initState();
    _selectedAccent = widget.initialAccent;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LauncherColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top indicator bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _selectedAccent
                              : LauncherColors.dragHandle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _pageController.animateToPage(
                          2,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: LauncherColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildAccentPickerPage(),
                  _buildCompletionPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Logo Badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _selectedAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedAccent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.home_outlined,
              color: _selectedAccent,
              size: 38,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Meet Fluee',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'A distraction-free, ultra-minimal home screen tailored for focus, speed, and elegance.',
            style: TextStyle(
              color: LauncherColors.textSecondary,
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 36),

          _buildFeatureRow(
            icon: Icons.schedule_outlined,
            title: 'Distraction-Free Clock',
            subtitle: 'Minimal time and alarm shortcut with zero clutter.',
          ),
          const SizedBox(height: 20),
          _buildFeatureRow(
            icon: Icons.grid_view_rounded,
            title: 'Uniform App Grid',
            subtitle: 'Clean monochrome tiles that look cohesive on any wallpaper.',
          ),
          const SizedBox(height: 20),
          _buildFeatureRow(
            icon: Icons.palette_outlined,
            title: 'Customizable Accent Dock',
            subtitle: 'Pin your top 4 essentials with your personalized accent.',
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAccent,
                foregroundColor: LauncherColors.readableOn(_selectedAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _nextPage,
              child: const Text(
                'Next: Pick Accent Color',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: LauncherColors.tileBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: LauncherColors.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccentPickerPage() {
    final fg = LauncherColors.readableOn(_selectedAccent);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick your accent color',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This color will style your bottom dock and interactive highlights.',
            style: TextStyle(
              color: LauncherColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Live Interactive Dock Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DOCK PREVIEW',
                      style: TextStyle(
                        color: LauncherColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '#${_selectedAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: TextStyle(
                        color: _selectedAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildPreviewTile(Icons.phone_rounded, fg),
                    const SizedBox(width: 8),
                    _buildPreviewTile(Icons.message_rounded, fg),
                    const SizedBox(width: 8),
                    _buildPreviewTile(Icons.camera_alt_rounded, fg),
                    const SizedBox(width: 8),
                    _buildPreviewTile(Icons.public_rounded, fg),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Swatches
          const Text(
            'Color Presets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (widget.wallpaperAccent != null)
                _buildColorSwatch(
                  color: widget.wallpaperAccent!,
                  isSelected: _isWallpaperSelected,
                  isWallpaper: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isWallpaperSelected = true;
                      _selectedAccent = widget.wallpaperAccent!;
                    });
                  },
                ),
              for (final preset in LauncherColors.accentPresets)
                _buildColorSwatch(
                  color: preset,
                  isSelected: !_isWallpaperSelected &&
                      preset.toARGB32() == _selectedAccent.toARGB32(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isWallpaperSelected = false;
                      _selectedAccent = preset;
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAccent,
                foregroundColor: LauncherColors.readableOn(_selectedAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _nextPage,
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPreviewTile(IconData icon, Color fg) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _selectedAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: fg, size: 26),
        ),
      ),
    );
  }

  Widget _buildColorSwatch({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool isWallpaper = false,
  }) {
    final fg = LauncherColors.readableOn(color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 3.5)
              : Border.all(color: Colors.transparent, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isSelected
            ? Icon(Icons.check, color: fg, size: 20)
            : (isWallpaper
                ? Icon(Icons.auto_awesome, color: fg, size: 20)
                : null),
      ),
    );
  }

  Widget _buildCompletionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _selectedAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: _selectedAccent,
              size: 40,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Ready to launch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Set Fluee Launcher as your default home app to make it open whenever you swipe up or press the home button.',
            style: TextStyle(
              color: LauncherColors.textSecondary,
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),

          // Default launcher helper card
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onOpenHomeSettings();
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: LauncherColors.tileBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF383838)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      color: _selectedAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set as Default Launcher',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Tap to open Android settings',
                          style: TextStyle(
                            color: LauncherColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: LauncherColors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAccent,
                foregroundColor: LauncherColors.readableOn(_selectedAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onComplete(_selectedAccent);
              },
              child: const Text(
                'Enter Fluee Launcher',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
