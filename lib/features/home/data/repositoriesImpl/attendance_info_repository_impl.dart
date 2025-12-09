import '../../domain/repositories/attendance_info_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/attendance_info.dart';

class AttendanceInfoRepositoryImpl implements AttendanceInfoRepository {
  final AttendanceInfoDataSource datasource;

  AttendanceInfoRepositoryImpl({required this.datasource});

  @override
  Future<List<Attendanceinfo>> attendanceInfo() async {
    final data = await datasource.fetchAttendanceInfo();
    return data;
  }
}
