import 'dart:convert';
import 'package:http/http.dart' as http;
import '../abstract_classes.dart';
import '../../models/addenrollment_model.dart';

class AddenrollmentRemoteDatasource implements AddenrollmentDataSource {
  final http.Client client;

  AddenrollmentRemoteDatasource({required this.client});

  @override
  Future<List<AddenrollmentModel>> addEnrollment() async {
    final response = await client.post(Uri.parse("uri"));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.map(AddenrollmentModel.fromjson).toList();
    } else {
      throw Exception("Failed to add enrollmets");
    }
  }
}
