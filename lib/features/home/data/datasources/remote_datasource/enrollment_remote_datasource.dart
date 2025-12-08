import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/course_model.dart';
import '../abstract_classes.dart';

class EnrollmentRemoteDatasourceImpl implements EnrollmentRemoteDatasource {
  final http.Client client;

  EnrollmentRemoteDatasourceImpl({required this.client});

  @override
  Future<List<CourseModel>> getEnrollments() async {
    final response = await client.get(Uri.parse(""));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.map(CourseModel.fromjson).toList();
    } else {
      throw Exception('Failed to load enrolled courses');
    }
  }
}
