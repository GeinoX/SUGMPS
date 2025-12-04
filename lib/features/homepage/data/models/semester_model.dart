import '../../domain/entities/semester.dart';

class SemesterModel extends Semester {
  SemesterModel({required super.period, required super.year});

  factory SemesterModel.fromjson(Map<String, dynamic> json) {
    return SemesterModel(period: json['period'], year: json['year']);
  }
}
