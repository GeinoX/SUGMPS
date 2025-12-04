import '../../domain/repositories/semester_repository.dart';
import '../datasources/semester_remote_datasource.dart';
import '../../domain/entities/semester.dart';

class SemesterRepositoryImpl extends SemesterRepository {
  final SemesterRemoteDatasource remoteDatasource;

  SemesterRepositoryImpl({required this.remoteDatasource});

  @override
  Future<List<Semester>> semesterInfo() async {
    final data = await remoteDatasource.getSemester();
    return data;
  }
}
