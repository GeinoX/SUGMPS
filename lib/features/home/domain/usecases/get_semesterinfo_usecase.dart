import '../repositories/semester_repository.dart';
import '../entities/semester.dart';

class GetSemesterinfoUsecase {
  final SemesterRepository repository;

  GetSemesterinfoUsecase({required this.repository});

  Future<List<Semester>> getSemesterInfo() async {
    final data = await repository.semesterInfo();
    return data;
  }
}
