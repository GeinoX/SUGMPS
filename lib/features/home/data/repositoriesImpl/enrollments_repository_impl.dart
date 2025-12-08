import '../../domain/repositories/enrollment_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/course.dart';

class EnrollmentsRepositoryImpl implements EnrollmentRepository {
  final EnrollmentRemoteDatasource remoteDatasource;

  EnrollmentsRepositoryImpl({required this.remoteDatasource});

  @override
  Future<List<Course>> enrollmentsInfo() async {
    final data = await remoteDatasource.getEnrollments();
    return data;
  }
}
