import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'token_storage.dart';

const kApiBase = 'https://ibuprofen-dolly-prison.ngrok-free.dev';
const _base = kApiBase;

// Single blanket timeout per Phase A3 — every outbound HTTP call must complete
// within this window or fail with ApiException('timeout'). The server-side
// matching algorithm has no operations expected to exceed it.
const _kStandardTimeout = Duration(seconds: 120);

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final TokenStorage _storage;
  final Uuid _uuid = const Uuid();
  ApiClient(this._storage);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: await _headers(auth, mutating: true),
            body: jsonEncode(body),
          )
          .timeout(_kStandardTimeout);
      return _parse(res);
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base$path'),
            headers: await _headers(auth, mutating: true),
            body: jsonEncode(body),
          )
          .timeout(_kStandardTimeout);
      return _parse(res);
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<dynamic> get(String path, {bool auth = false}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_base$path'),
            headers: await _headers(auth, mutating: false),
          )
          .timeout(_kStandardTimeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = false,
  }) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base$path'),
            headers: await _headers(auth, mutating: true),
          )
          .timeout(_kStandardTimeout);
      return _parse(res);
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<Map<String, String>> _headers(bool auth, {required bool mutating}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    if (mutating) {
      h['X-Idempotency-Key'] = _uuid.v4();
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
