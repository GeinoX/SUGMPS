import '../repositories/attendance_info_repository.dart';
import '../entities//attendance_info.dart';

class AttendanceInfoUsecase {
  final AttendanceInfoRepository repository;

  AttendanceInfoUsecase({required this.repository});

  Future<List<Attendanceinfo>> getAttendanceInfo() async {
    final data = await repository.attendanceInfo();
    return data;
  }
}
