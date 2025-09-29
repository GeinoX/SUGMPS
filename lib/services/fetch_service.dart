import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl =
      "https://2574fc5179bd.ngrok-free.app/umsapp/courses/";

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
