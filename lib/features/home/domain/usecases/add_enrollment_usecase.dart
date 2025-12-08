import '../entities/addenrollment.dart';
import '../repositories/addenrollment_repository.dart';

class AddEnrollmentUsecase {
  final AddenrollmentRepository repository;

  AddEnrollmentUsecase({required this.repository});

  Future<List<Addenrollment>> addCourseEnrollment() async {
    final data = await repository.addEnrollment();
    return data;
  }
}
