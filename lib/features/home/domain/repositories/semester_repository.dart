import '../entities/semester.dart';

abstract class SemesterRepository {
  Future<List<Semester>> semesterInfo();
}
