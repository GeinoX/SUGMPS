import '../../models/attendance_info_models.dart';
import '../abstract_classes.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceInfoRemoteDatasource implements AttendanceInfoDataSource {
  final http.Client client;

  AttendanceInfoRemoteDatasource({required this.client});

  @override
  Future<List<AttendanceInfoModels>> fetchAttendanceInfo() async {
    final response = await client.get(Uri.parse("uri"));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.map(AttendanceInfoModels.fromjson).toList();
    } else {
      throw Exception("Failed to load attendance information");
    }
  }
}
