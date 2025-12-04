import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<List<UserModel>> getUserInfo();
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final http.Client client;

  UserRemoteDataSourceImpl({required this.client});

  @override
  Future<List<UserModel>> getUserInfo() async {
    final response = await client.get(Uri.parse("uri"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data.map(UserModel.fromjson).toList();
    } else {
      throw Exception("Failed to load user information");
    }
  }
}
