import 'package:flutter/material.dart';

abstract final class LauncherColors {
  static const background = Color(0xFF000000);
  static const tileBackground = Color(0xFF2E2E2E);
  static const tileIcon = Color(0xFFCCCCCC);
  static const dragHandle = Color(0xFF3A3A3A);
  static const sheetBackground = Color(0xFF1A1A1A);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const danger = Color(0xFFF38BA8);

  /// Mint green from the reference screenshot.
  static const defaultAccent = Color(0xFF3ECB8B);

  static const List<Color> accentPresets = [
    Color(0xFF3ECB8B), // mint
    Color(0xFFA3F4A0), // pastel green
    Color(0xFF4DABF7), // blue
    Color(0xFF89B4FA), // periwinkle
    Color(0xFFB197FC), // violet
    Color(0xFFF783AC), // pink
    Color(0xFFFF6B6B), // red
    Color(0xFFFFA94D), // orange
    Color(0xFFFFD43B), // yellow
    Color(0xFF3BC9DB), // cyan
    Color(0xFFE9ECEF), // white
    Color(0xFF495057), // graphite
  ];

  /// Returns near-black or white depending on which has better contrast on [background].
  static Color readableOn(Color background) =>
      background.computeLuminance() > 0.45
          ? const Color(0xFF0B0B0B)
          : Colors.white;
}
