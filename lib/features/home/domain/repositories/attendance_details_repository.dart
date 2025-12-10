import '../entities/attendance_details.dart';

abstract class AttendanceDetailsRepository {
  Future<List<Attendancedetails>> attendanceDetails();
}
