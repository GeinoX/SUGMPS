import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  /// Registers a user
  Future<Map<String, dynamic>> register({
    required String name,
    required String schoolEmail,
    required String otherEmail,
    required String matricule,
    required int phone,
    required String password,
    required String gender,
    required String program, // NEW
    required File profileImage, // make it required
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/umsapp/students/register/');

      // Always use multipart since image is compulsory
      var request = http.MultipartRequest('POST', uri);

      request.fields['name'] = name;
      request.fields['school_email'] = schoolEmail;
      request.fields['email'] = otherEmail;
      request.fields['matricule'] = matricule;
      request.fields['phone'] = phone.toString();
      request.fields['password'] = password;
      request.fields['gender'] = gender;
      request.fields['program'] = program; // NEW

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
    final uri = Uri.parse('$baseUrl/umsapp/students/token/refresh/');
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
