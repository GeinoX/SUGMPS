import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/semester_model.dart';

abstract class SemesterRemoteDatasource {
  Future<List<SemesterModel>> getSemester();
}

class SemesterRemoteDataSourceImpl implements SemesterRemoteDatasource {
  final http.Client client;

  SemesterRemoteDataSourceImpl({required this.client});

  @override
  Future<List<SemesterModel>> getSemester() async {
    final response = await client.get(Uri.parse("uri"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data.map(SemesterModel.fromjson).toList();
    } else {
      throw Exception("Failed to load semester info");
    }
  }
}
