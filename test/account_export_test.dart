import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/screens/account_screen.dart';

import 'helpers.dart';

void main() {
  final user = {
    'id': 4,
    'full_name': 'Nguyễn An',
    'email': 'an@example.com',
    'phone': '+84901234567',
    'email_verified': true,
  };

  testWidgets('"Tải dữ liệu của tôi" asks the password and shows the server refusal', (tester) async {
    final server = FakeServer({
      'GET /account': (200, {'user': user, 'loyalty': null}),
      'POST /account/export': (
        403,
        {
          'error': 'wrong_password',
          'messages': ['Mật khẩu không đúng.'],
        },
      ),
    });
    final state = await pumpScreen(tester, const AccountScreen(), server: server);
    await state.refreshUser();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tải dữ liệu của tôi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải dữ liệu của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wrong-one');
    await tester.tap(find.text('Tải file dữ liệu (JSON)'));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu không đúng.'), findsOneWidget);
    final export = server.requests.lastWhere((request) => request.url.path == '/api/v1/account/export');
    expect(export.body, '{"password":"wrong-one"}');
  });
}
