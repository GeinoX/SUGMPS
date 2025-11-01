import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:sugmps/utils/course_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/routes.dart';

class CourseService {
  final String baseUrl;

  CourseService({required this.baseUrl});

  Future<void> fetchAndSync(Box<Course> box) async {
    final url = Uri.parse('${AppRoutes.url}/umsapp/enrollfilter');

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      // clear old data
      await box.clear();

      // save new data
      for (var item in data) {
        final course = Course.fromJson(item);
        await box.add(course);
      }
    } else {
      throw Exception('Failed to fetch courses: ${response.statusCode}');
    }
  }
}
