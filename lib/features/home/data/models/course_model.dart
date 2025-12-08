import '../../domain/entities/course.dart';

class CourseModel extends Course {
  CourseModel({
    required super.courseId,
    required super.courseName,
    required super.credits,
    required super.status,
    required super.level,
  });
  factory CourseModel.fromjson(Map<String, dynamic> json) {
    return CourseModel(
      courseId: json['courseId'],
      courseName: json['courseName'],
      credits: json['credits'],
      status: json['status'],
      level: json['level'],
    );
  }
}
