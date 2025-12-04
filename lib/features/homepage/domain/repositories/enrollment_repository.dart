import '../entities/enrollment.dart';

abstract class EnrollmentRepository {
  Future<List<Enrollments>> enrollmentsInfo();
}
