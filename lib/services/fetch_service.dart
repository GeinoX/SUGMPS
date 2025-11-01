import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:sugmps/utils/attendancetemp_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/routes.dart';

class ApiService {
  static const String baseUrl = "${AppRoutes.url}/umsapp/courses/";

  // Fetch courses for a given level+semester (e.g., "l2s4")
  static Future<List<dynamic>> fetchCourses(String levelSem) async {
    final url = Uri.parse("$baseUrl$levelSem");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load courses: ${response.statusCode}");
    }
  }
}

Future<void> fetchAttendance(
  String courseId,
  String token,
  Box<Attendance> box,
) async {
  final response = await http.get(
    Uri.parse("https://your-api.com/api/student/attendance/$courseId/"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);

    await box.clear();

    for (var item in data) {
      final attendance = Attendance.fromJson(item);
      await box.add(attendance);
    }
  } else {
    throw Exception("Failed to load attendance");
  }
}
