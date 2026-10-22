import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vn_badminton_mobile/api.dart';
import 'package:vn_badminton_mobile/app_state.dart';
import 'package:vn_badminton_mobile/google_auth.dart';
import 'package:vn_badminton_mobile/push.dart';

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

/// Firebase on a phone where notifications are allowed (or not, [granted]); the FCM token is [currentToken].
class FakePush implements PushService {
  FakePush({this.granted = true});

  bool granted;
  String? currentToken = 'fcm-token-1';
  final refreshes = StreamController<String>.broadcast();
  int permissionRequests = 0;

  @override
  Future<bool> start() async => true;

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> listen({required String channelName, required void Function(String path) onOpen}) async {}

  @override
  Future<void> renameChannel(String channelName) async {}
}

/// Google's account picker: answers [idToken] (null: closed by the customer).
class FakeGoogle implements GoogleAuth {
  String? answer = 'google-id-token';
  int signOuts = 0;

  @override
  Future<String?> idToken() async => answer;

  @override
  Future<void> signOut() async => signOuts++;
}

/// An AppState talking to [server], with fake Firebase and Google, and empty storage on the "phone".
AppState fakeState({FakeServer? server, FakePush? push, FakeGoogle? google, String locale = 'vi'}) {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'VN Badminton',
    packageName: 'com.vnbadminton.vn_badminton_mobile',
    version: '0.7.0',
    buildNumber: '8',
    buildSignature: '',
  );
  return AppState(
    api: Api('https://court.example.vn', client: (server ?? FakeServer({})).client),
    push: push ?? FakePush(),
    google: google ?? FakeGoogle(),
  )..locale = locale;
}

/// Builds [screen] in the app's scope, with an AppState talking to [server].
Future<AppState> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  FakeServer? server,
  String locale = 'vi',
  AppState? state,
}) async {
  await initializeDateFormatting('vi');
  await initializeDateFormatting('en');
  state ??= fakeState(server: server, locale: locale);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(home: screen),
    ),
  );
  return state;
}
