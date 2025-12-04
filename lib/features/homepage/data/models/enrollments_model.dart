import '../../domain/entities/enrollment.dart';

class EnrollmentsModel extends Enrollments {
  EnrollmentsModel({
    required super.courseId,
    required super.courseName,
    required super.credits,
    required super.status,
    required super.level,
  });
  factory EnrollmentsModel.fromjson(Map<String, dynamic> json) {
    return EnrollmentsModel(
      courseId: json['courseId'],
      courseName: json['courseName'],
      credits: json['credits'],
      status: json['status'],
      level: json['level'],
    );
  }
}
