import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> enroll(String accessToken) async {
  final url = Uri.parse('https://yourapi.com/protected-endpoint');

  final body = jsonEncode({'field1': 'value1', 'field2': 'value2'});

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken', // <-- access token
      'Content-Type': 'application/json',
    },
    body: body,
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    print('Success: ${response.body}');
  } else {
    print('Error: ${response.statusCode}, ${response.body}');
  }
}
