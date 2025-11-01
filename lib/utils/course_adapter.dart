import 'package:hive/hive.dart';

part 'course_adapter.g.dart'; // flutter pub run build_runner build

@HiveType(typeId: 0)
class Course extends HiveObject {
  @HiveField(0)
  final String courseId;

  @HiveField(1)
  final String courseName;

  @HiveField(2)
  final int credits;

  @HiveField(3)
  final String status;

  @HiveField(4)
  final String level;

  Course({
    required this.courseId,
    required this.courseName,
    required this.credits,
    required this.status,
    required this.level,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['course_id'] as String,
      courseName: json['course_name'] as String,
      credits: json['credits'] as int,
      status: json['status'] as String,
      level: json['level'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'course_name': courseName,
      'credits': credits,
      'status': status,
      'level': level,
    };
  }
}
