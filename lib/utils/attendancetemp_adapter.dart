import 'package:hive/hive.dart';

part 'attendancetemp_adapter.g.dart'; // flutter pub run build_runner build

@HiveType(typeId: 1)
class Attendance extends HiveObject {
  @HiveField(0)
  final int day;

  @HiveField(1)
  final String session_id;

  @HiveField(2)
  final String status;

  Attendance({
    required this.day,
    required this.session_id,
    required this.status,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      day: json['day'],
      session_id: json['session_id'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'day': day, 'session_id': session_id, 'status': status};
  }
}
