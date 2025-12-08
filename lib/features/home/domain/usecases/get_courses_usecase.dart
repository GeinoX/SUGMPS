import '../repositories/course_repository.dart';
import '../entities/course.dart';

class GetCourseUsecase {
  final CourseRepository repository;

  GetCourseUsecase({required this.repository});

  Future<List<Course>> getCourseInfo() async {
    final data = await repository.coursesInfo();
    return data;
  }
}
