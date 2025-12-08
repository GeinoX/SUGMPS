import '../../domain/repositories/semester_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/semester.dart';

class SemesterRepositoryImpl implements SemesterRepository {
  final SemesterRemoteDatasource remoteDatasource;

  SemesterRepositoryImpl({required this.remoteDatasource});

  @override
  Future<List<Semester>> semesterInfo() async {
    final data = await remoteDatasource.getSemester();
    return data;
  }
}
