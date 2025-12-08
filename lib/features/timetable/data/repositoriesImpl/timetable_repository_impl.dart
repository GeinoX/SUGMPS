import '../../domain/repositories/timetable_repository.dart';
import '../datasources/abstractclasses.dart';
import '../../domain/entities/timetable.dart';

class TimetableRepositoryImpl implements TimetableRepository {
  final TimetableDatasource datasource;

  TimetableRepositoryImpl({required this.datasource});

  @override
  Future<List<Timetable>> timetableInfo() async {
    final data = await datasource.getTimetable();
    return data;
  }
}
