import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/enrollments_model.dart';

abstract class EnrollmentRemoteDatasource {
  Future<List<EnrollmentsModel>> getEnrollments();
}

class EnrollmentRemoteDatasourceImpl implements EnrollmentRemoteDatasource {
  final http.Client client;

  EnrollmentRemoteDatasourceImpl({required this.client});

  @override
  Future<List<EnrollmentsModel>> getEnrollments() async {
    final response = await client.get(Uri.parse(""));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.map(EnrollmentsModel.fromjson).toList();
    } else {
      throw Exception('Failed to load enrolled courses');
    }
  }
}
