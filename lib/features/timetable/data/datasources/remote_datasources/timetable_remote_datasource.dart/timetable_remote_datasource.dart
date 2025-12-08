import 'dart:convert';
import '../../../../data/models/timetable_model.dart';
import '../../abstractclasses.dart';
import 'package:http/http.dart' as http;

class TimetableRemoteDatasource implements TimetableDatasource {
  final http.Client client;

  TimetableRemoteDatasource({required this.client});

  @override
  Future<List<TimetableModel>> getTimetable() async {
    final response = await client.get(Uri.parse("uri"));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.map(TimetableModel.fromjson).toList();
    } else {
      throw Exception("Failed to load timetable.");
    }
  }
}
