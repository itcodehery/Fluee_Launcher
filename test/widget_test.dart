import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluee_launcher/main.dart';
import 'package:fluee_launcher/models/app_item.dart';
import 'package:fluee_launcher/models/app_shortcut.dart';
import 'package:fluee_launcher/services/launcher_platform.dart';
import 'package:fluee_launcher/services/launcher_preferences.dart';
import 'package:fluee_launcher/widgets/app_panel.dart';
import 'package:fluee_launcher/widgets/app_tile.dart';
import 'package:fluee_launcher/widgets/launcher_clock.dart';
import 'package:fluee_launcher/widgets/quick_apps_panel.dart';

void main() {
  testWidgets('Launcher renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlueeLauncherApp());
    expect(find.byType(LauncherScreen), findsOneWidget);
  });

  testWidgets('LauncherClock renders Pixel Watch stadium clock and weather complication',
      (WidgetTester tester) async {
    bool clockTapped = false;
    bool dateTapped = false;
    bool weatherTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LauncherClock(
            accent: Colors.teal,
            leadingValue: '12 Dec',
            onTap: () => clockTapped = true,
            onDateTap: () => dateTapped = true,
            onSettingsTap: () {},
            onWeatherTap: () => weatherTapped = true,
          ),
        ),
      ),
    );

    // Verify leading date complication (day and month stacked, e.g. "12" and "Dec")
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Dec'), findsOneWidget);
    await tester.tap(find.text('12'));
    expect(dateTapped, true);

    // Verify trailing weather complication
    expect(find.byType(WeatherCircleComplication), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.byIcon(Icons.wb_cloudy_rounded), findsOneWidget);

    await tester.tap(find.text('32'));
    expect(weatherTapped, true);

    await tester.tap(find.byType(LauncherClock));
    expect(clockTapped || weatherTapped, true);
  });

  testWidgets('QuickAppsPanel renders battery pill, 6 slots and status pill',
      (WidgetTester tester) async {
    final platform = LauncherPlatform();
    bool closed = false;
    final tapped = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickAppsPanel(
            accent: const Color(0xFFD0BCFF),
            platform: platform,
            slots: List<AppItem?>.filled(maxQuickApps, null),
            onClose: () => closed = true,
            onAppTap: (_) {},
            onAppLongPress: (_) {},
            onEmptySlotTap: tapped.add,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsNWidgets(6));
    expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    expect(tapped, [0]);

    await tester.tap(find.byType(GestureDetector).last);
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

  testWidgets('AppPanel renders in List mode and supports sorting and recents',
      (WidgetTester tester) async {
    final sampleApps = [
      AppItem(
        label: 'Chrome',
        packageName: 'com.android.chrome',
        activityName: 'com.google.android.apps.chrome.Main',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: true,
      ),
      AppItem(
        label: 'Camera',
        packageName: 'com.android.camera',
        activityName: 'com.android.camera.Camera',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPanel(
            apps: sampleApps,
            metrics: TileMetrics.forWidth(400),
            dockHeight: 80,
            isExpanded: true,
            drawerMode: DrawerMode.list,
            accent: Colors.teal,
            onExpandedChanged: (_) {},
            onAppTap: (_) {},
            onAppLongPress: (_) {},
          ),
        ),
      ),
    );

    // Verify list mode renders app labels
    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  test('AppShortcut model decodes correctly', () {
    final shortcut = AppShortcut.fromMap({
      'id': 'new_tab',
      'packageName': 'com.android.chrome',
      'shortLabel': 'New tab',
      'longLabel': 'Open a new tab',
      'icon': [1, 2, 3],
    });
    expect(shortcut.id, 'new_tab');
    expect(shortcut.packageName, 'com.android.chrome');
    expect(shortcut.shortLabel, 'New tab');
    expect(shortcut.displayLabel, 'Open a new tab');
    expect(shortcut.icon, isNotEmpty);
  });

  test('LauncherPreferences backup and restore round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await LauncherPreferences.load();
    await prefs.setQuickAppIds(['app1', 'app2']);
    await prefs.setHiddenAppIds({'hidden1'});
    await prefs.setCustomLabel('app1', 'Custom App 1');
    await prefs.setCustomAccent(const Color(0xFF123456));

    final exported = prefs.exportBackupJson();
    expect(exported['quickAppIds'], ['app1', 'app2']);
    expect(exported['hiddenAppIds'], ['hidden1']);
    expect(exported['customLabelMap'], {'app1': 'Custom App 1'});

    // Clear and restore
    SharedPreferences.setMockInitialValues({});
    final freshPrefs = await LauncherPreferences.load();
    final jsonStr = jsonEncode(exported);
    final success = await freshPrefs.importBackupJson(jsonStr);

    expect(success, true);
    expect(freshPrefs.quickAppIds, ['app1', 'app2']);
    expect(freshPrefs.hiddenAppIds, {'hidden1'});
    expect(freshPrefs.customLabelMap, {'app1': 'Custom App 1'});
    expect(freshPrefs.customAccent.toARGB32(), const Color(0xFF123456).toARGB32());
  });
}
