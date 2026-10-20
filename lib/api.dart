import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The address of the Rails server, given at build time:
///   flutter run --dart-define-from-file=config/dev.json
/// (`start-tunnel` writes the tunnel URL into that file).
const apiUrl = String.fromEnvironment('API_URL');

/// The full address of a file on the server, e.g. User.avatarPath.
String serverUrl(String path) => '$apiUrl$path';

/// An error answered by the API ({ "error": "<code>", "messages": [...] }), or `network` when the server
/// could not be reached.
class ApiError implements Exception {
  ApiError(this.status, this.code, [this.messages = const []]);

  final int status;
  final String code;
  final List<String> messages;

  bool get isNetwork => code == 'network';

  @override
  String toString() => messages.isNotEmpty ? messages.join('\n') : code;
}

/// The JSON API of the server (`/api/v1`, see docs/api.md in the web app).
class Api {
  Api(this.baseUrl);

  final String baseUrl;
  final _client = http.Client();

  String? token;
  String locale = 'vi';

  /// Called when a signed-in request is answered 401 (token revoked or expired).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) => _send('DELETE', path, body: body);

  /// Sends a file as multipart/form-data (the profile photo).
  Future<dynamic> upload(String method, String path, String field, String filePath) async {
    final request = http.MultipartRequest(method, Uri.parse('$baseUrl/api/v1$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Accept-Language': locale,
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..files.add(await http.MultipartFile.fromPath(field, filePath));
    return _receive(() => _client.send(request).timeout(const Duration(seconds: 60)));
  }

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Accept-Language': locale,
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    return _receive(() => _client.send(request).timeout(const Duration(seconds: 20)));
  }

  Future<dynamic> _receive(Future<http.StreamedResponse> Function() send) async {
    final http.Response response;
    try {
      response = await http.Response.fromStream(await send());
    } on SocketException {
      throw ApiError(0, 'network');
    } on TimeoutException {
      throw ApiError(0, 'network');
    } on http.ClientException {
      throw ApiError(0, 'network');
    }

    final text = utf8.decode(response.bodyBytes);
    final json = text.isEmpty ? null : _decode(text);
    if (response.statusCode < 400) return json;

    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    final error = json is Map ? json : const {};
    throw ApiError(
      response.statusCode,
      error['error']?.toString() ?? 'http_${response.statusCode}',
      [for (final message in (error['messages'] as List? ?? const [])) message.toString()],
    );
  }

  dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
