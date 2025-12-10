import '../../domain/repositories/addenrollment_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/addenrollment.dart';

class AddenrollmentRepositoryImpl implements AddenrollmentRepository {
  final AddenrollmentDataSource dataSource;

  AddenrollmentRepositoryImpl({required this.dataSource});

  @override
  Future<List<Addenrollment>> addEnrollment() async {
    final data = await dataSource.addEnrollment();
    return data;
  }
}
