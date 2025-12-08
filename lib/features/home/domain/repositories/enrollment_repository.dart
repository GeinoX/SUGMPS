import '../entities/course.dart';

abstract class EnrollmentRepository {
  Future<List<Course>> enrollmentsInfo();
}
