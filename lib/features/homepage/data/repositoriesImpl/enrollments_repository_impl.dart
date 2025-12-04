import '../../domain/repositories/enrollment_repository.dart';
import '../datasources/enrollment_remote_datasource.dart';
import '../../domain/entities/enrollment.dart';

class EnrollmentsRepositoryImpl extends EnrollmentRepository {
  final EnrollmentRemoteDatasource remoteDatasource;

  EnrollmentsRepositoryImpl({required this.remoteDatasource});

  @override
  Future<List<Enrollments>> enrollmentsInfo() async {
    final data = await remoteDatasource.getEnrollments();
    return data;
  }
}
