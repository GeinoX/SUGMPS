import '../abstract_classes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/course_model.dart';

class CourseRemoteDataSourceImpl implements CourseDataSource {
  final http.Client client;

  CourseRemoteDataSourceImpl({required this.client});

  @override
  Future<List<CourseModel>> fetchCourses() async {
    final response = await client.get(Uri.parse(""));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.map(CourseModel.fromjson).toList();
    } else {
      throw Exception("Failed to fetch course infformation.");
    }
  }
}
