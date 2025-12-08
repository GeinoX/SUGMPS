import '../../domain/repositories/addenrollment_repository.dart';
import '../datasources/abstract_classes.dart';
import '../models/addenrollment_model.dart';

class AddenrollmentRepositoryImpl implements AddenrollmentRepository {
  final AddenrollmentDataSource dataSource;

  AddenrollmentRepositoryImpl({required this.dataSource});

  @override
  Future<List<AddenrollmentModel>> addEnrollment() async {
    final data = await dataSource.addEnrollment();
    return data;
  }
}
