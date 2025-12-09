import '../models/course_model.dart';
import '../models/semester_model.dart';
import '../models/user_model.dart';
import '../models/addenrollment_model.dart';
import '../models/attendance_info_models.dart';

abstract class EnrollmentRemoteDatasource {
  Future<List<CourseModel>> getEnrollments();
}

abstract class SemesterRemoteDatasource {
  Future<List<SemesterModel>> getSemester();
}

abstract class UserRemoteDataSource {
  Future<List<UserModel>> getUserInfo();
}

abstract class CourseDataSource {
  Future<List<CourseModel>> fetchCourses();
}

abstract class AddenrollmentDataSource {
  Future<List<AddenrollmentModel>> addEnrollment();
}

abstract class AttendanceInfoDataSource {
  Future<List<AttendanceInfoModels>> fetchAttendanceInfo();
}
