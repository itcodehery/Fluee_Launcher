import 'dart:typed_data';

class AppShortcut {
  const AppShortcut({
    required this.id,
    required this.packageName,
    required this.shortLabel,
    this.longLabel,
    required this.icon,
  });

  final String id;
  final String packageName;
  final String shortLabel;
  final String? longLabel;
  final Uint8List icon;

  String get displayLabel =>
      (longLabel != null && longLabel!.isNotEmpty) ? longLabel! : shortLabel;

  factory AppShortcut.fromMap(Map<dynamic, dynamic> map) {
    final rawIcon = map['icon'];
    Uint8List iconBytes;
    if (rawIcon is Uint8List) {
      iconBytes = rawIcon;
    } else if (rawIcon is List<int>) {
      iconBytes = Uint8List.fromList(rawIcon);
    } else if (rawIcon is List) {
      iconBytes = Uint8List.fromList(rawIcon.cast<int>());
    } else {
      iconBytes = Uint8List(0);
    }

    return AppShortcut(
      id: map['id'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      shortLabel: map['shortLabel'] as String? ?? '',
      longLabel: map['longLabel'] as String?,
      icon: iconBytes,
    );
  }
}
