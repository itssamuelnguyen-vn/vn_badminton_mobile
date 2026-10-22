import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/deep_links.dart';
import 'package:vn_badminton_mobile/screens/auth_screens.dart';
import 'package:vn_badminton_mobile/screens/settings_screen.dart';

import 'helpers.dart';

const user = {
  'id': 4,
  'full_name': 'Nguyễn An',
  'email': 'an@example.com',
  'phone': '+84901234567',
  'email_verified': true,
};

Map<String, dynamic> bodyOf(FakeServer server, String method, String path) => jsonDecode(
  server.requests.lastWhere((request) => request.method == method && request.url.path == '/api/v1$path').body,
);

List<String> calls(FakeServer server) => [
  for (final request in server.requests) '${request.method} ${request.url.path.replaceFirst('/api/v1', '')}',
];

void main() {
  test("the phone's token goes to the server after signing in and on refresh, and is removed on sign-out", () async {
    final server = FakeServer({
      'POST /session': (201, {'token': 'api-token', 'user': user}),
      'POST /device_tokens': (204, null),
      'DELETE /device_tokens': (204, null),
      'DELETE /session': (204, null),
    });
    final push = FakePush();
    final state = fakeState(server: server, push: push);
    await state.startPush(channelName: 'Lượt đặt và nhắc lịch', onOpen: (_) {});

    await state.signIn('an@example.com', 'password123');
    await pumpEventQueue();
    expect(bodyOf(server, 'POST', '/device_tokens'), containsPair('token', 'fcm-token-1'));
    expect(bodyOf(server, 'POST', '/device_tokens'), containsPair('platform', 'android'));

    push.currentToken = 'fcm-token-2';
    push.refreshes.add('fcm-token-2');
    await pumpEventQueue();
    expect(bodyOf(server, 'POST', '/device_tokens')['token'], 'fcm-token-2');

    await state.signOut();
    expect(calls(server).sublist(calls(server).length - 2), ['DELETE /device_tokens', 'DELETE /session']);
    expect(bodyOf(server, 'DELETE', '/device_tokens'), {'token': 'fcm-token-2'});
    expect(state.signedIn, isFalse);
  });

  test('nothing is sent with notifications turned off', () async {
    final server = FakeServer({
      'POST /session': (201, {'token': 'api-token', 'user': user}),
    });
    final state = fakeState(server: server)..notifications = false;
    await state.signIn('an@example.com', 'password123');
    await pumpEventQueue();
    expect(calls(server), ['POST /session']);
  });

  test('a notification tapped opens its page like a link', () {
    openPath('/bookings/K7Q2M9XA');
    expect(pendingLink.value, const DeepLink(LinkTarget.booking, 'K7Q2M9XA'));
    openPath('/payments/abc_123');
    expect(pendingLink.value, const DeepLink(LinkTarget.payment, 'abc_123'));
    openPath('/');
    expect(pendingLink.value, const DeepLink(LinkTarget.home));
    pendingLink.value = null;
  });

  testWidgets('the Notifications switch removes the token from the server and puts it back', (tester) async {
    final server = FakeServer({
      'POST /session': (201, {'token': 'api-token', 'user': user}),
      'POST /device_tokens': (204, null),
      'DELETE /device_tokens': (204, null),
    });
    final push = FakePush();
    final state = fakeState(server: server, push: push);
    await tester.runAsync(() => state.signIn('an@example.com', 'password123'));
    await pumpScreen(tester, const SettingsScreen(), state: state);

    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(state.notifications, isFalse);
    expect(calls(server).last, 'DELETE /device_tokens');

    // Refused in Android's question: stays off and says where to turn them on.
    push.granted = false;
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(state.notifications, isFalse);
    expect(find.textContaining('Bật lại trong Cài đặt của điện thoại'), findsOneWidget);

    push.granted = true;
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(state.notifications, isTrue);
    expect(calls(server).last, 'POST /device_tokens');
  });

  testWidgets('Google sign-in for someone new asks the phone number and the consent, then signs in', (tester) async {
    final server = FakeServer({
      'POST /session/google': (
        200,
        {'needs_phone': true, 'signup_token': 'signed-token', 'name': 'Trần Bình', 'email': 'binh@gmail.com'},
      ),
      'POST /registration/google': (
        422,
        {
          'error': 'invalid',
          'messages': ['Số điện thoại đã được sử dụng'],
        },
      ),
    });
    final push = FakePush(granted: false);
    final state = fakeState(server: server, push: push);
    await pumpScreen(tester, const SignInScreen(), state: state);

    await tester.ensureVisible(find.text('Đăng nhập với Google'));
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(bodyOf(server, 'POST', '/session/google'), {'id_token': 'google-id-token', 'device_name': 'Android'});
    expect(find.text('Hoàn tất đăng ký'), findsOneWidget);
    expect(find.textContaining('binh@gmail.com'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Trần Bình'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Số điện thoại'), '0901 234 567');
    await tester.ensureVisible(find.text('Đăng ký'));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Cần đồng ý với chính sách bảo mật để đăng ký.'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Số điện thoại đã được sử dụng'), findsOneWidget);
    expect(bodyOf(server, 'POST', '/registration/google'), {
      'signup_token': 'signed-token',
      'full_name': 'Trần Bình',
      'phone': '0901 234 567',
      'privacy_consent': true,
      'locale': 'vi',
      'device_name': 'Android',
    });

    server.routes['POST /registration/google'] = (201, {'token': 'api-token', 'user': user});
    server.routes['POST /device_tokens'] = (204, null);
    server.routes['DELETE /device_tokens'] = (204, null);
    await tester.tap(find.text('Đăng ký'));
    // Not pumpAndSettle: the buttons keep spinning behind the question.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.signedIn, isTrue);

    // Asked once whether to get notifications; "Not now" turns them off.
    expect(find.text('Nhận thông báo?'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect([state.notifications, state.notificationsAsked], [false, true]);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('an account Google knows signs in at once; a closed picker does nothing', (tester) async {
    final server = FakeServer({
      'POST /session/google': (201, {'token': 'api-token', 'user': user}),
      'POST /device_tokens': (204, null),
    });
    final google = FakeGoogle()..answer = null;
    final state = fakeState(server: server, google: google);
    await pumpScreen(tester, const SignInScreen(), state: state);

    await tester.ensureVisible(find.text('Đăng nhập với Google'));
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(server.requests, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);

    google.answer = 'google-id-token';
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(state.signedIn, isTrue);
    expect(calls(server), ['POST /session/google', 'POST /device_tokens']);
  });
}
