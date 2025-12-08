import '../../domain/entities/addenrollment.dart';

class AddenrollmentModel extends Addenrollment {
  AddenrollmentModel({
    required super.courseName,
    required super.period,
    required super.year,
  });

  factory AddenrollmentModel.fromjson(Map<String, dynamic> json) {
    return AddenrollmentModel(
      courseName: json['courseName'],
      period: json['period'],
      year: json['year'],
    );
  }
}
