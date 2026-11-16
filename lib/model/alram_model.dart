import 'package:flutter/material.dart';

class AlarmModel {
  final int? id;
  String title;
  TimeOfDay time;
  List<String> days;
  bool isActive;
  List<Color> gradientColors;
  bool isQRAlarm;
  String? customRingtone;
  bool requireUniqueQR;  // NEW: If true, only unique QR works, if false, any QR works

  AlarmModel({
    this.id,
    required this.title,
    required this.time,
    required this.days,
    this.isActive = true,
    required this.gradientColors,
    this.isQRAlarm = false,
    this.customRingtone,
    this.requireUniqueQR = false,  // NEW: Default is false (any QR works)
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': '${time.hour}:${time.minute}',
      'days': days.join(','),
      'isActive': isActive ? 1 : 0,
      'gradientColorStart': gradientColors[0].value.toString(),
      'gradientColorEnd': gradientColors[1].value.toString(),
      'isQRAlarm': isQRAlarm ? 1 : 0,
      'customRingtone': customRingtone,
      'requireUniqueQR': requireUniqueQR ? 1 : 0,  // NEW
    };
  }

  static AlarmModel fromMap(Map<String, dynamic> map) {
    final timeParts = map['time'].toString().split(':');
    final colorStart = Color(int.parse(map['gradientColorStart']));
    final colorEnd = Color(int.parse(map['gradientColorEnd']));

    return AlarmModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      days: (map['days'] as String).split(','),
      isActive: map['isActive'] == 1,
      gradientColors: [colorStart, colorEnd],
      isQRAlarm: (map['isQRAlarm'] ?? 0) == 1,
      customRingtone: map['customRingtone'] as String?,
      requireUniqueQR: (map['requireUniqueQR'] ?? 0) == 1,  // NEW
    );
  }

  AlarmModel copy({
    int? id,
    String? title,
    TimeOfDay? time,
    List<String>? days,
    bool? isActive,
    List<Color>? gradientColors,
    bool? isQRAlarm,
    String? customRingtone,
    bool? requireUniqueQR,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      days: days ?? this.days,
      isActive: isActive ?? this.isActive,
      gradientColors: gradientColors ?? this.gradientColors,
      isQRAlarm: isQRAlarm ?? this.isQRAlarm,
      customRingtone: customRingtone ?? this.customRingtone,
      requireUniqueQR: requireUniqueQR ?? this.requireUniqueQR,  // NEW
    );
  }
}