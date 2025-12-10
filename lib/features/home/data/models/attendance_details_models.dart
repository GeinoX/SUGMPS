import '../../domain/entities/attendance_details.dart';

class AttendanceDetailsModels extends Attendancedetails {
  AttendanceDetailsModels({
    required super.day,
    required super.sessionId,
    required super.status,
  });

  factory AttendanceDetailsModels.fromJson(Map<String, dynamic> json) {
    return AttendanceDetailsModels(
      day: json['day'],
      sessionId: json['sessionId'],
      status: json['status'],
    );
  }
}
