import 'package:hive/hive.dart';

part 'teacher_course_adapter.g.dart';

@HiveType(typeId: 10) // Make sure this typeId is unique
class TeacherCourse extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String teacherId;

  @HiveField(2)
  String teacherName;

  @HiveField(3)
  String courseId;

  @HiveField(4)
  String courseName;

  @HiveField(5)
  String semester;

  @HiveField(6)
  String year;

  @HiveField(7)
  String timestamp;

  TeacherCourse({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.courseId,
    required this.courseName,
    required this.semester,
    required this.year,
    required this.timestamp,
  });

  factory TeacherCourse.fromJson(Map<String, dynamic> json) {
    return TeacherCourse(
      id: json['id'].toString(),
      teacherId: json['teacher'] ?? '',
      teacherName: json['teacher_name'] ?? '',
      courseId: json['course_id'] ?? '',
      courseName: json['course_name'] ?? '',
      semester: json['semester'] ?? '',
      year: json['year'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher': teacherId,
      'teacher_name': teacherName,
      'course_id': courseId,
      'course_name': courseName,
      'semester': semester,
      'year': year,
      'timestamp': timestamp,
    };
  }
}
