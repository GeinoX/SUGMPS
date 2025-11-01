import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TeacherAuthService {
  final String baseUrl;

  TeacherAuthService({required this.baseUrl});

  /// Registers a user
  Future<Map<String, dynamic>> register({
    required String name,
    required String otherEmail,
    required String employee_id,
    required int phone,
    required String password,
    required String gender,
    required File profileImage, // make it required
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/umsapp/teacher/register/');

      // Always use multipart since image is compulsory
      var request = http.MultipartRequest('POST', uri);

      request.fields['name'] = name;
      request.fields['email'] = otherEmail;
      request.fields['employee_id'] = employee_id;
      request.fields['phone'] = phone.toString();
      request.fields['password'] = password;
      request.fields['gender'] = gender;

      request.files.add(
        await http.MultipartFile.fromPath('profile_image', profileImage.path),
      );

      var streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw HttpException(
          'Failed to register. Status code: ${response.statusCode}, body: ${response.body}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in AuthService.register: $e');
      }
      rethrow;
    }
  }
}
