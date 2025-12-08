import '../../domain/repositories/course_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/course.dart';

class CourseRepositoryImpl implements CourseRepository {
  final CourseDataSource dataSource;

  CourseRepositoryImpl({required this.dataSource});

  @override
  Future<List<Course>> coursesInfo() async {
    final data = await dataSource.fetchCourses();
    return data;
  }
}
