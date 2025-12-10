import '../repositories/attendance_details_repository.dart';
import '../entities/attendance_details.dart';

class ClassName {
  final AttendanceDetailsRepository repository;

  ClassName({required this.repository});

  Future<List<Attendancedetails>> getAttendanceDetails() async {
    final data = await repository.attendanceDetails();
    return data;
  }
}
