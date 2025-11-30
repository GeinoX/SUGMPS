import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  Future<Map<String, dynamic>> register({
    required String name,
    required String schoolEmail,
    required String otherEmail,
    required int phone,
    required String matricule,
    required String password,
    required String gender,
    required String program,
    required File profileImage,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/umsapp/students/register/'),
      );

      // Add fields
      request.fields['name'] = name;
      request.fields['school_email'] = schoolEmail;
      request.fields['other_email'] = otherEmail;
      request.fields['phone'] = phone.toString();
      request.fields['matricule'] = matricule;
      request.fields['password'] = password;
      request.fields['gender'] = gender;
      request.fields['program'] = program;

      // Add image file
      if (profileImage.path.isNotEmpty && await profileImage.exists()) {
        var imageFile = await http.MultipartFile.fromPath(
          'profile_image',
          profileImage.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(imageFile);
      }

      var response = await request.send();
      var responseString = await response.stream.bytesToString();

      print('🎯 Registration Response: $responseString');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(responseString);
        print('✅ Registration successful!');
        return responseData;
      } else {
        final errorData = jsonDecode(responseString);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('❌ Registration error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String schoolEmail,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/umsapp/token/');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': schoolEmail, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        if (kDebugMode) {
          print('Failed to login: ${response.body}');
        }
        throw HttpException(
          'Failed to login. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in AuthService.login: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final uri = Uri.parse('$baseUrl/umsapp/token/refresh/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to refresh token');
    }
  }
}
