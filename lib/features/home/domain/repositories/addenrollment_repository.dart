import '../entities/addenrollment.dart';

abstract class AddenrollmentRepository {
  Future<List<Addenrollment>> addEnrollment();
}
