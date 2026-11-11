import 'dart:typed_data';

class AppItem {
  const AppItem({
    required this.label,
    required this.packageName,
    required this.activityName,
    required this.userSerial,
    required this.icon,
    required this.isMonochrome,
  });

  final String label;
  final String packageName;
  final String activityName;
  final int userSerial;
  final Uint8List icon;
  final bool isMonochrome;

  String get id => '$packageName/$activityName#$userSerial';

  AppItem copyWith({
    String? label,
    String? packageName,
    String? activityName,
    int? userSerial,
    Uint8List? icon,
    bool? isMonochrome,
  }) {
    return AppItem(
      label: label ?? this.label,
      packageName: packageName ?? this.packageName,
      activityName: activityName ?? this.activityName,
      userSerial: userSerial ?? this.userSerial,
      icon: icon ?? this.icon,
      isMonochrome: isMonochrome ?? this.isMonochrome,
    );
  }

  factory AppItem.fromMap(Map<Object?, Object?> map) {
    return AppItem(
      label: (map['label'] as String?) ?? '',
      packageName: (map['packageName'] as String?) ?? '',
      activityName: (map['activityName'] as String?) ?? '',
      userSerial: (map['userSerial'] as num?)?.toInt() ?? 0,
      icon: (map['icon'] as Uint8List?) ?? Uint8List(0),
      isMonochrome: (map['monochrome'] as bool?) ?? false,
    );
  }
}
