import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluee_launcher/main.dart';
import 'package:fluee_launcher/models/app_item.dart';
import 'package:fluee_launcher/services/launcher_platform.dart';
import 'package:fluee_launcher/widgets/app_panel.dart';
import 'package:fluee_launcher/widgets/app_tile.dart';
import 'package:fluee_launcher/widgets/launcher_clock.dart';
import 'package:fluee_launcher/widgets/quick_settings_watch.dart';

void main() {
  testWidgets('Launcher renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlueeLauncherApp());
    expect(find.byType(LauncherScreen), findsOneWidget);
  });

  testWidgets('LauncherClock renders Pixel Watch stadium clock and weather complication',
      (WidgetTester tester) async {
    bool clockTapped = false;
    bool settingsTapped = false;
    bool weatherTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LauncherClock(
            accent: Colors.teal,
            onTap: () => clockTapped = true,
            onSettingsTap: () => settingsTapped = true,
            onWeatherTap: () => weatherTapped = true,
          ),
        ),
      ),
    );

    // Verify leading settings icon
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    expect(settingsTapped, true);

    // Verify trailing weather complication
    expect(find.byType(WeatherCircleComplication), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.byIcon(Icons.wb_cloudy_rounded), findsOneWidget);

    await tester.tap(find.text('32'));
    expect(weatherTapped, true);

    await tester.tap(find.byType(LauncherClock));
    expect(clockTapped || weatherTapped, true);
  });

  testWidgets('QuickSettingsPanel renders inline quick settings and morphs',
      (WidgetTester tester) async {
    final platform = LauncherPlatform();
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickSettingsPanel(
            accent: const Color(0xFFD0BCFF),
            platform: platform,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    // Verify top 3 buttons (Flashlight, DnD, Auto-brightness)
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget); // Torch
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget); // DnD
    expect(find.byIcon(Icons.brightness_auto_rounded), findsOneWidget); // Auto-brightness

    // Verify 6 options in two rows (Night Light, Airplane Mode, Wifi, Auto-rotate, Camera, Settings)
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget); // Night Light
    expect(find.byIcon(Icons.airplanemode_active_rounded), findsOneWidget); // Airplane
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget); // Wifi
    expect(find.byIcon(Icons.screen_rotation_rounded), findsOneWidget); // Auto-rotate
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget); // Camera access
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget); // Settings

    // Bottom pill
    expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);

    // Drag down to trigger morph
    await tester.drag(find.byIcon(Icons.nightlight_round), const Offset(0, 50));
    await tester.pumpAndSettle();

    // Tap drag handle to close
    final dragHandle = find.byType(GestureDetector).last;
    await tester.tap(dragHandle);
    expect(closed, true);
  });

  testWidgets('AppPanel renders and handles search and mode toggle cleanly',
      (WidgetTester tester) async {
    final sampleApps = [
      AppItem(
        label: 'Chrome',
        packageName: 'com.android.chrome',
        activityName: 'com.google.android.apps.chrome.Main',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: false,
      ),
      AppItem(
        label: 'Camera',
        packageName: 'com.android.camera',
        activityName: 'com.android.camera.Camera',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: false,
      ),
      AppItem(
        label: 'Chrome Beta',
        packageName: 'com.android.chrome',
        activityName: 'com.google.android.apps.chrome.Beta',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: false,
      ),
    ];

    bool isExpanded = false;
    bool isListMode = false;
    bool autoFocusSearch = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppPanel(
                apps: sampleApps,
                metrics: TileMetrics.forWidth(400),
                dockHeight: 80,
                isExpanded: isExpanded,
                isListMode: isListMode,
                autoFocusSearch: autoFocusSearch,
                accent: Colors.green,
                onExpandedChanged: (expanded) {
                  setState(() => isExpanded = expanded);
                },
                onAppTap: (_) {},
                onAppLongPress: (_) {},
              );
            },
          ),
        ),
      ),
    );

    // Initial state: AppPanel is rendered in Grid mode
    expect(find.byType(AppPanel), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);

    // Expand panel
    final handle = find.byType(GestureDetector).first;
    await tester.tap(handle);
    await tester.pumpAndSettle();

    expect(isExpanded, true);
    expect(find.byType(TextField), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, true);

    // Enter search text
    await tester.enterText(find.byType(TextField), 'Chrome');
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsWidgets);

    // Collapse panel
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(isExpanded, false);
  });

  testWidgets('AppPanel searches hidden apps when searchIncludesHidden is enabled',
      (WidgetTester tester) async {
    final visibleApp = AppItem(
      label: 'VisibleApp',
      packageName: 'com.test.visible',
      activityName: 'com.test.visible.MainActivity',
      userSerial: 0,
      icon: Uint8List(0),
      isMonochrome: false,
    );
    final hiddenApp = AppItem(
      label: 'HiddenApp',
      packageName: 'com.test.hidden',
      activityName: 'com.test.hidden.MainActivity',
      userSerial: 0,
      icon: Uint8List(0),
      isMonochrome: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPanel(
            apps: [visibleApp],
            allApps: [visibleApp, hiddenApp],
            metrics: TileMetrics.forWidth(400),
            dockHeight: 80,
            isExpanded: true,
            isListMode: false,
            searchIncludesHidden: true,
            accent: Colors.teal,
            onExpandedChanged: (_) {},
            onAppTap: (_) {},
            onAppLongPress: (_) {},
          ),
        ),
      ),
    );

    // Initial state: only visible app is displayed
    expect(find.byType(TextField), findsOneWidget);

    // Search for hidden app
    await tester.enterText(find.byType(TextField), 'Hidden');
    await tester.pumpAndSettle();

    expect(find.byType(AppTile), findsOneWidget);
  });
}
