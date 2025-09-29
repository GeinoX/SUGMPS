import 'dart:convert';

class JwtHelper {
  /// Decodes a JWT and returns its payload as Map
  static Map<String, dynamic> decodeJWT(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception("Invalid JWT");
    }

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return json.decode(payload) as Map<String, dynamic>;
  }

  /// Checks if a JWT is expired
  static bool isExpired(String token) {
    final payload = decodeJWT(token);
    final exp = payload['exp'] as int;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expiryDate);
  }
}
