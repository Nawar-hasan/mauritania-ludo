import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'session_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._store);
  final SessionStore _store;
  Future<bool>? _refreshing;

  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration uploadTimeout = Duration(seconds: 30);

  Future<dynamic> get(String path, {bool authenticated = true}) => _request('GET', path, authenticated: authenticated);
  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool authenticated = true}) =>
      _request('POST', path, body: body, authenticated: authenticated);
  Future<dynamic> patch(String path, {Map<String, dynamic>? body, bool authenticated = true}) =>
      _request('PATCH', path, body: body, authenticated: authenticated);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    try {
      final token = authenticated ? await _store.accessToken : null;
      final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'));
      request.headers['Accept'] = 'application/json';
      request.headers['Content-Type'] = 'application/json';
      if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);

      final streamed = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _request(method, path, body: body, authenticated: authenticated, retryAfterRefresh: false);
        }
      }
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('NETWORK_TIMEOUT');
    } on http.ClientException {
      throw const ApiException('NETWORK_UNREACHABLE');
    }
  }

  Future<bool> _refreshAccessToken() {
    return _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _performRefresh() async {
    final refresh = await _store.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final result = await post('/auth/refresh', body: {'refreshToken': refresh}, authenticated: false) as Map<String, dynamic>;
      await _store.saveTokens(
        accessToken: result['accessToken'] as String,
        refreshToken: result['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _store.clearTokens();
      return false;
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath, {
    String field = 'file',
    bool retryAfterRefresh = true,
  }) async {
    try {
      final token = await _store.accessToken;
      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
      request.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(field, filePath));
      final streamed = await request.send().timeout(uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 && retryAfterRefresh && await _refreshAccessToken()) {
        return uploadFile(path, filePath, field: field, retryAfterRefresh: false);
      }
      return (_decode(response) as Map).cast<String, dynamic>();
    } on TimeoutException {
      throw const ApiException('NETWORK_TIMEOUT');
    } on http.ClientException {
      throw const ApiException('NETWORK_UNREACHABLE');
    }
  }


  Future<Map<String, dynamic>> uploadBytes(
    String path,
    Uint8List bytes,
    String filename, {
    String field = 'file',
    bool retryAfterRefresh = true,
  }) async {
    try {
      final token = await _store.accessToken;
      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
      request.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
      final streamed = await request.send().timeout(uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 && retryAfterRefresh && await _refreshAccessToken()) {
        return uploadBytes(path, bytes, filename, field: field, retryAfterRefresh: false);
      }
      return (_decode(response) as Map).cast<String, dynamic>();
    } on TimeoutException {
      throw const ApiException('NETWORK_TIMEOUT');
    } on http.ClientException {
      throw const ApiException('NETWORK_UNREACHABLE');
    }
  }

  dynamic _decode(http.Response response) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body);
      } catch (_) {
        payload = response.body;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed (${response.statusCode})';
      if (payload is Map && payload['message'] != null) {
        final raw = payload['message'];
        message = raw is List ? raw.join('\n') : raw.toString();
      } else if (payload is String && payload.isNotEmpty) {
        message = payload;
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
    return payload;
  }
}
