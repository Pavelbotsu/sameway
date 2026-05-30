import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

// Android emulator → host machine localhost. Change to your server URL for production.
const kApiBase = 'https://ibuprofen-dolly-prison.ngrok-free.dev';
const _base = kApiBase;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final TokenStorage _storage;
  ApiClient(this._storage);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final res = await http.put(
      Uri.parse('$_base$path'),
      headers: await _headers(auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<dynamic> get(String path, {bool auth = false}) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: await _headers(auth),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = false,
  }) async {
    final res = await http.delete(
      Uri.parse('$_base$path'),
      headers: await _headers(auth),
    );
    return _parse(res);
  }

  Future<Map<String, String>> _headers(bool auth) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Map<String, dynamic> _parse(http.Response res) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(data['error']?.toString() ?? 'Request failed');
    }
    return data;
  }
}
