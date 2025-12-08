import '../entities/timetable.dart';
import '../repositories/timetable_repository.dart';

class GetTimetableUsecase {
  final TimetableRepository repository;

  GetTimetableUsecase({required this.repository});

  Future<List<Timetable>> getTimetable() async {
    final data = await repository.timetableInfo();
    return data;
  }
}
