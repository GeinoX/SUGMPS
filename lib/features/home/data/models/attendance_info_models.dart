import '../../domain/entities/attendance_info.dart';

class AttendanceInfoModels extends Attendanceinfo {
  AttendanceInfoModels({
    required super.studentId,
    required super.attendanceCount,
    required super.totalSessions,
    required super.lastAttended,
  });

  factory AttendanceInfoModels.fromjson(Map<String, dynamic> json) {
    return AttendanceInfoModels(
      studentId: json['studentId'],
      attendanceCount: json['attendanceCount'],
      totalSessions: json['totalSessions'],
      lastAttended: json['lastAttended'],
    );
  }
}
