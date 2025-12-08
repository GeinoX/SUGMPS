import '../../data/models/timetable_model.dart';

abstract class TimetableDatasource {
  Future<List<TimetableModel>> getTimetable();
}
