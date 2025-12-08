import '../../domain/entities/timetable.dart';

class TimetableModel extends Timetable {
  TimetableModel({
    required super.courseName,
    required super.day,
    required super.startTime,
    required super.endTime,
    required super.hall,
  });

  factory TimetableModel.fromjson(Map<String, dynamic> json) {
    return TimetableModel(
      courseName: json['courseName'],
      day: json['day'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      hall: json['hall'],
    );
  }
}
