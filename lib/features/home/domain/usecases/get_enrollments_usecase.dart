import '../repositories/enrollment_repository.dart';
import '../entities/course.dart';

class GetEnrollmentsUsecase {
  final EnrollmentRepository repository;

  GetEnrollmentsUsecase({required this.repository});

  Future<List<Course>> getEnrollmentInfo() async {
    final data = await repository.enrollmentsInfo();
    return data;
  }
}
