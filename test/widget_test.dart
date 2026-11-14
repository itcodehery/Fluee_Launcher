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
import 'package:fluee_launcher/theme/app_shapes.dart';
import 'package:fluee_launcher/widgets/app_panel.dart';
import 'package:fluee_launcher/widgets/app_tile.dart';
import 'package:fluee_launcher/widgets/ambient_lock_keypad.dart';
import 'package:fluee_launcher/widgets/launcher_clock.dart';
import 'package:fluee_launcher/widgets/launcher_dock.dart';
import 'package:fluee_launcher/widgets/profile_dashboard.dart';
import 'package:fluee_launcher/widgets/quick_apps_panel.dart';
import 'package:fluee_launcher/widgets/quick_tasks_bar.dart';

void main() {
  testWidgets('Launcher renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlueeLauncherApp());
    expect(find.byType(LauncherScreen), findsOneWidget);
  });

  testWidgets('LauncherClock renders Pixel Watch stadium clock and battery complication',
      (WidgetTester tester) async {
    bool clockTapped = false;
    bool dateTapped = false;
    bool batteryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LauncherClock(
            accent: Colors.teal,
            leadingValue: '12 Dec',
            batteryLevel: 49,
            isCharging: false,
            onTap: () => clockTapped = true,
            onDateTap: () => dateTapped = true,
            onSettingsTap: () {},
            onBatteryTap: () => batteryTapped = true,
          ),
        ),
      ),
    );

    // Verify trailing date complication (day and month stacked, e.g. "12" and "Dec")
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Dec'), findsOneWidget);
    await tester.tap(find.text('12'));
    expect(dateTapped, true);

    // Verify leading battery complication
    expect(find.byType(BatteryCircleComplication), findsOneWidget);
    expect(find.text('49%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_full_rounded), findsOneWidget);

    await tester.tap(find.text('49%'));
    expect(batteryTapped, true);

    await tester.tap(find.byType(LauncherClock));
    expect(clockTapped || batteryTapped, true);
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

    // Initial state: AppPanel is rendered in Categorized mode
    expect(find.byType(AppPanel), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    // Switch to All Apps mode
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text('All Apps'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);

    // Open search via Search FAB
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, true);

    // Enter search text
    await tester.enterText(find.byType(TextField), 'Chrome');
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsWidgets);
    expect(isExpanded, isFalse);
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

    // Open search via Search FAB
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    // Search for hidden app
    await tester.enterText(find.byType(TextField), 'Hidden');
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('drawer-tile-${hiddenApp.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('drawer-tile-${visibleApp.id}')), findsNothing);
  });

  testWidgets('AppPanel renders categorized cards and expands on tap',
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
            accent: Colors.teal,
            onExpandedChanged: (_) {},
            onAppTap: (_) {},
            onAppLongPress: (_) {},
          ),
        ),
      ),
    );

    // Categorized mode renders category cards
    expect(find.text('Apps'), findsOneWidget);
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);

    // Expand Internet category to reveal Chrome
    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('drawer-tile-${sampleApps.first.id}')), findsOneWidget);
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

  test('AppIconShape deterministically assigns varied Material shapes', () {
    final shapes = {
      appShapeForId('com.google.android.youtube/Main'),
      appShapeForId('com.google.android.dialer/Main'),
      appShapeForId('com.google.android.apps.photos/Main'),
      appShapeForId('com.android.chrome/Main'),
      appShapeForId('com.google.android.apps.tasks/Main'),
      appShapeForId('com.google.android.apps.nbu.paisa.user/Main'),
      appShapeForId('com.spotify.music/Main'),
      appShapeForId('com.whatsapp/Main'),
    };
    expect(shapes.length, greaterThan(1));
    expect(
      appShapeForId('com.android.chrome/Main'),
      appShapeForId('com.android.chrome/Main'),
    );
  });

  test('LauncherPreferences persists up to 2 pinned quick tasks', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await LauncherPreferences.load();

    await prefs.setPinnedQuickTasks([
      const PinnedQuickTask(
        packageName: 'com.google.android.apps.tasks',
        shortcutId: 'new_task',
        label: 'New Task',
      ),
      const PinnedQuickTask(
        packageName: 'com.google.android.apps.nbu.paisa.user',
        shortcutId: 'scan_qr',
        label: 'Scan QR',
      ),
      const PinnedQuickTask(
        packageName: 'com.android.chrome',
        shortcutId: 'new_tab',
        label: 'New Tab',
      ),
    ]);

    expect(prefs.pinnedQuickTasks.length, 2);
    expect(prefs.pinnedQuickTasks[0].label, 'New Task');
    expect(prefs.pinnedQuickTasks[1].label, 'Scan QR');

    final exported = prefs.exportBackupJson();
    SharedPreferences.setMockInitialValues({});
    final restored = await LauncherPreferences.load();
    expect(await restored.importBackupJson(jsonEncode(exported)), true);
    expect(restored.pinnedQuickTasks.length, 2);
    expect(restored.pinnedQuickTasks[1].shortcutId, 'scan_qr');
  });

  testWidgets('QuickTasksBar renders up to 2 pinned tasks and handles taps',
      (WidgetTester tester) async {
    PinnedQuickTask? tappedTask;
    int? longPressedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickTasksBar(
            tasks: const [
              PinnedQuickTask(
                packageName: 'com.google.android.apps.tasks',
                shortcutId: 'new_task',
                label: 'New Task',
              ),
              PinnedQuickTask(
                packageName: 'com.google.android.apps.nbu.paisa.user',
                shortcutId: 'scan_qr',
                label: 'Scan QR',
              ),
            ],
            shortcuts: const [],
            accent: Colors.teal,
            onTaskTap: (t) => tappedTask = t,
            onTaskLongPress: (i, _) => longPressedIndex = i,
            onAddTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('New Task'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);

    await tester.tap(find.text('Scan QR'));
    expect(tappedTask?.shortcutId, 'scan_qr');

    await tester.longPress(find.text('New Task'));
    expect(longPressedIndex, 0);
  });

  testWidgets('AppPanel All Apps mode renders 4-column grid and handles app tap',
      (WidgetTester tester) async {
    final apps = [
      AppItem(
        label: 'Calendar',
        packageName: 'com.google.android.calendar',
        activityName: 'Main',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: false,
      ),
      AppItem(
        label: 'Spotify',
        packageName: 'com.spotify.music',
        activityName: 'Main',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: false,
      ),
      AppItem(
        label: 'Arc',
        packageName: 'company.thebrowser.arc',
        activityName: 'Main',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: false,
      ),
    ];

    AppItem? tappedApp;
    final metrics = TileMetrics.forWidth(400);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPanel(
            apps: apps,
            metrics: metrics,
            dockHeight: 80,
            isExpanded: false,
            accent: Colors.teal,
            onExpandedChanged: (_) {},
            onAppTap: (a) => tappedApp = a,
            onAppLongPress: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text('All Apps'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Tooltip), findsNWidgets(3));

    await tester.tap(find.byKey(ValueKey('drawer-tile-${apps[1].id}')));
    expect(tappedApp?.packageName, 'com.spotify.music');
  });

  testWidgets('Expanded dashboard hides the clock and split clock collapses it',
      (WidgetTester tester) async {
    final controller = LauncherClockController();
    var collapseTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LauncherClock(
              accent: Colors.teal,
              batteryLevel: 56,
              controller: controller,
              onTap: () {},
              onSettingsTap: () {},
              dashboard: ProfileDashboard(
                accent: Colors.teal,
                platform: LauncherPlatform(),
                name: 'Hari',
                onCollapse: () {
                  collapseTaps++;
                  controller.collapse();
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining(':'));
    await tester.pumpAndSettle();

    expect(controller.isExpanded, isTrue);
    // Clock text is removed from the expanded card.
    expect(find.textContaining(':'), findsNothing);
    expect(find.text('Hey Hari,'), findsOneWidget);

    // Tapping the dashboard body must not collapse it.
    await tester.tap(find.text('Hey Hari,'));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    expect(collapseTaps, 0);

    // Tapping the split minute tile collapses the dashboard.
    final now = DateTime.now();
    final minStr = now.minute.toString().padLeft(2, '0');
    await tester.tap(find.text(minStr).last);
    await tester.pumpAndSettle();
    expect(collapseTaps, 1);
    expect(controller.isExpanded, isFalse);
    expect(find.textContaining(':'), findsOneWidget);
  });

  testWidgets('Expanded dashboard never overflows narrow screens',
      (WidgetTester tester) async {
    for (final width in [320.0, 360.0, 412.0, 432.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: LauncherClock(
                key: ValueKey(width),
                accent: Colors.teal,
                batteryLevel: 56,
                onTap: () {},
                onSettingsTap: () {},
                dashboard: ProfileDashboard(
                  accent: Colors.teal,
                  platform: LauncherPlatform(),
                  name: 'Hari',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.textContaining(':'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'clock overflowed at width $width');
      expect(tester.getSize(find.byType(LauncherClock)).width,
          lessThanOrEqualTo(width));
    }
  });

  testWidgets('Dashboard expands and collapses with a spring animation',
      (WidgetTester tester) async {
    final controller = LauncherClockController();
    tester.view.physicalSize = const Size(432, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: LauncherClock(
              accent: Colors.teal,
              batteryLevel: 56,
              controller: controller,
              onTap: () {},
              onSettingsTap: () {},
              dashboard: ProfileDashboard(
                accent: Colors.teal,
                platform: LauncherPlatform(),
                name: 'Hari',
                onCollapse: controller.collapse,
              ),
            ),
          ),
        ),
      ),
    );

    final collapsed = tester.getSize(find.byType(LauncherClock));

    await tester.tap(find.textContaining(':'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final midExpand = tester.getSize(find.byType(LauncherClock));
    await tester.pump(const Duration(milliseconds: 80));
    final overshoot = tester.getSize(find.byType(LauncherClock));
    await tester.pumpAndSettle();
    final expanded = tester.getSize(find.byType(LauncherClock));

    expect(midExpand.height, greaterThan(collapsed.height));
    expect(midExpand.height, lessThan(expanded.height));
    // Under-damped M3 spring overshoots the target while opening.
    expect(overshoot.height, greaterThan(expanded.height));

    controller.collapse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final midCollapse = tester.getSize(find.byType(LauncherClock));
    await tester.pumpAndSettle();
    final collapsedAgain = tester.getSize(find.byType(LauncherClock));

    // Collapse must animate too (previously the card snapped shut).
    expect(midCollapse.height, lessThan(expanded.height));
    expect(midCollapse.height, greaterThan(collapsedAgain.height));
    expect(collapsedAgain.height, collapsed.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppPanel search FAB opens and closes inline search field',
      (WidgetTester tester) async {
    AppItem app(String label, String pkg) => AppItem(
          label: label,
          packageName: pkg,
          activityName: 'Main',
          userSerial: 0,
          icon: Uint8List(0),
          isMonochrome: false,
        );

    final apps = [
      app('Calendar', 'com.google.android.calendar'),
      app('Camera', 'com.google.android.camera'),
      app('Chrome', 'com.android.chrome'),
      app('Spotify', 'com.spotify.music'),
      app('Arc', 'company.thebrowser.arc'),
    ];

    final metrics = TileMetrics.forWidth(400);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPanel(
            apps: apps,
            metrics: metrics,
            dockHeight: 80,
            isExpanded: true,
            accent: Colors.teal,
            onExpandedChanged: (_) {},
            onAppTap: (_) {},
            onAppLongPress: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('LauncherDock swipes through apps one by one with center highlight',
      (WidgetTester tester) async {
    AppItem app(String label, String pkg) => AppItem(
          label: label,
          packageName: pkg,
          activityName: 'Main',
          userSerial: 0,
          icon: Uint8List(0),
          isMonochrome: false,
        );

    final slots = List<AppItem?>.generate(
      maxDockApps,
      (i) => i < 8 ? app('App $i', 'com.example.app$i') : null,
    );
    slots[2] = app('Phone', 'com.android.dialer');
    slots[3] = app('Messages', 'com.android.messaging');

    AppItem? tapped;
    int? emptySlot;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LauncherDock(
              slots: slots,
              accent: Colors.teal,
              onAppTap: (a) => tapped = a,
              onAppLongPress: (_, _) {},
              onEmptySlotTap: (i) => emptySlot = i,
            ),
          ),
        ),
      ),
    );

    // Slot 2 ('Phone') starts centered and largest (82x82).
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Messages'), findsNothing);

    await tester.tap(find.byIcon(Icons.apps_rounded).at(2));
    expect(tapped?.packageName, 'com.android.dialer');

    // Swipe left by 1 item (0.20 * 800 = 160px) to move slot 3 ('Messages') to center.
    await tester.drag(find.byType(PageView), const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);

    // Tap the '+' slot to verify empty slot callback.
    await tester.drag(find.byType(PageView), const Offset(-640, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    expect(emptySlot, isNotNull);
  });

  testWidgets('LauncherClock bigClock ambient style shrinks hour smaller than minute for keypad',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LauncherClock(
              accent: Colors.teal,
              batteryLevel: 49,
              isIdle: true,
              ambientStyle: AmbientStyle.bigClock,
              isCompactForKeypad: true,
              onTap: () {},
              onSettingsTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final use24h = MediaQuery.alwaysUse24HourFormatOf(
      tester.element(find.byType(LauncherClock)),
    );
    final h = use24h ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    final hourStr = h.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');

    final hourBox = tester.getSize(find.text(hourStr).first);
    final minBox = tester.getSize(find.text(minStr).last);
    expect(hourBox.height, lessThan(minBox.height));
  });

  testWidgets('AmbientLockKeypad unlocks when expected PIN is entered',
      (WidgetTester tester) async {
    var unlocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AmbientLockKeypad(
              accent: Colors.teal,
              expectedPin: '1234',
              onUnlocked: () => unlocked = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(unlocked, isFalse);
    expect(find.byKey(const ValueKey('pin-shape-0')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
    expect(find.byKey(const ValueKey('pin-shape-0')), findsNothing);
  });

  testWidgets('LauncherClock ambient pillsGlow mode shows all three pills',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LauncherClock(
              accent: Colors.teal,
              batteryLevel: 49,
              isIdle: true,
              ambientStyle: AmbientStyle.pillsGlow,
              onTap: () {},
              onSettingsTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('49%'), findsOneWidget);
    expect(find.textContaining(':'), findsOneWidget);
    expect(find.byType(BatteryCircleComplication), findsOneWidget);
  });

  testWidgets('ProfileDashboard displays pinned app tasks and handles taps',
      (WidgetTester tester) async {
    PinnedQuickTask? tappedTask;
    const tasks = [
      PinnedQuickTask(
        packageName: 'com.google.android.apps.tasks',
        shortcutId: 'new_task',
        label: 'New Task',
      ),
      PinnedQuickTask(
        packageName: 'com.google.zxing',
        shortcutId: 'scan_qr',
        label: 'Scan QR',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileDashboard(
            accent: Colors.teal,
            platform: LauncherPlatform(),
            name: 'Hari',
            batteryLevel: 56,
            pinnedTasks: tasks,
            onTaskTap: (t) => tappedTask = t,
          ),
        ),
      ),
    );

    expect(find.text('Hey Hari,'), findsOneWidget);
    expect(find.text('New Task'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);

    await tester.tap(find.text('Scan QR'));
    await tester.pumpAndSettle();
    expect(tappedTask?.shortcutId, 'scan_qr');
  });

  testWidgets('AppPanel allows only one category open at a time',
      (WidgetTester tester) async {
    final sampleApps = [
      AppItem(
        label: 'Chrome',
        packageName: 'com.android.chrome',
        activityName: 'Main',
        userSerial: 0,
        icon: Uint8List(0),
        isMonochrome: true,
      ),
      AppItem(
        label: 'Camera',
        packageName: 'com.android.camera',
        activityName: 'Main',
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
            accent: Colors.teal,
            onExpandedChanged: (_) {},
            onAppTap: (_) {},
            onAppLongPress: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('drawer-tile-${sampleApps[0].id}')), findsOneWidget);
    expect(find.byKey(ValueKey('drawer-tile-${sampleApps[1].id}')), findsNothing);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('drawer-tile-${sampleApps[0].id}')), findsNothing);
    expect(find.byKey(ValueKey('drawer-tile-${sampleApps[1].id}')), findsOneWidget);
  });

  test('LauncherPreferences persists ambientTimeoutSeconds', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await LauncherPreferences.load();
    expect(prefs.ambientTimeoutSeconds, 15);
    await prefs.setAmbientTimeoutSeconds(30);
    expect(prefs.ambientTimeoutSeconds, 30);
  });
}
