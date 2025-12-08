import '../entities/timetable.dart';

abstract class TimetableRepository {
  Future<List<Timetable>> timetableInfo();
}
