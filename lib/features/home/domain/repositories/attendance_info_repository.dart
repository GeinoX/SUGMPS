import '../entities/attendance_info.dart';

abstract class AttendanceInfoRepository {
  Future<List<Attendanceinfo>> attendanceInfo();
}
