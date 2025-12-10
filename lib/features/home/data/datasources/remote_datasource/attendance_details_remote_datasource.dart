import 'dart:convert';
import 'package:http/http.dart' as http;
import '../abstract_classes.dart';
import '../../models/attendance_details_models.dart';

class AttendanceDetailsRemoteDatasource implements AttendanceDetailsDataSource {
  final http.Client client;

  AttendanceDetailsRemoteDatasource({required this.client});

  @override
  Future<List<AttendanceDetailsModels>> fetchAttendanceDetails() async {
    final response = await client.get(Uri.parse('url'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((item) => AttendanceDetailsModels.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to load ModelName');
    }
  }
}
