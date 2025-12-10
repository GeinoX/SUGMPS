import 'package:sugmps/features/home/data/models/attendance_details_models.dart';

import '../../domain/repositories/attendance_details_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/attendance_details.dart';

class AttendanceDetailsRepositoryImpl implements AttendanceDetailsRepository {
  final AttendanceDetailsDataSource datasource;

  AttendanceDetailsRepositoryImpl({required this.datasource});

  @override
  Future<List<AttendanceDetailsModels>> attendanceDetails() async {
    final data = await datasource.fetchAttendanceDetails();
    return data;
  }
}
