import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vn_badminton_mobile/api.dart';
import 'package:vn_badminton_mobile/app_state.dart';

/// A fake server: answers "METHOD /path" (without /api/v1) with [routes] as JSON, 404 for anything else.
/// Every request is kept in [requests].
class FakeServer {
  FakeServer(this.routes);

  final Map<String, (int, Object?)> routes;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path.replaceFirst('/api/v1', '')}';
    final (status, body) = routes[key] ?? (404, {'error': 'not_found', 'messages': <String>[]});
    return http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// Builds [screen] in the app's scope, with an AppState talking to [server].
Future<AppState> pumpScreen(WidgetTester tester, Widget screen, {FakeServer? server, String locale = 'vi'}) async {
  await initializeDateFormatting('vi');
  await initializeDateFormatting('en');
  final state = AppState(api: Api('https://court.example.vn', client: (server ?? FakeServer({})).client))
    ..locale = locale;
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(home: screen),
    ),
  );
  return state;
}
