import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/models.dart';
import 'package:vn_badminton_mobile/screens/payment_screen.dart';
import 'package:vn_badminton_mobile/screens/waitlist_screen.dart';
import 'package:vn_badminton_mobile/screens/whats_new_screen.dart';

import 'helpers.dart';

void main() {
  test("the newest release of What's new is the version of pubspec.yaml", () {
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(releases.first.version, version);
    for (final release in releases) {
      expect(release.vi.length, release.en.length, reason: release.version);
    }
  });

  testWidgets("What's new lists the releases in the app's language", (tester) async {
    await pumpScreen(tester, const WhatsNewScreen(), locale: 'en');
    expect(find.text(releases.first.en.first, findRichText: true), findsWidgets);
    expect(find.text(releases.first.vi.first, findRichText: true), findsNothing);
  });

  testWidgets('the waitlist shows the times waited for, and the server error with a retry', (tester) async {
    final server = FakeServer({
      'GET /waitlist': (
        200,
        {
          'entries': [
            {'id': 1, 'starts_at': '2026-10-20T18:00:00+07:00', 'ends_at': '2026-10-20T19:30:00+07:00'},
          ],
        },
      ),
    });
    await pumpScreen(tester, const WaitlistScreen(), server: server);
    await tester.pumpAndSettle();
    expect(find.text('18:00–19:30'), findsOneWidget);

    server.routes['GET /waitlist'] = (
      500,
      {
        'error': 'oops',
        'messages': ['Lỗi máy chủ'],
      },
    );
    await pumpScreen(tester, const WaitlistScreen(key: ValueKey('again')), server: server);
    await tester.pumpAndSettle();
    expect(find.text('Lỗi máy chủ'), findsOneWidget);
  });

  testWidgets('the customer cancels an order still waiting for the transfer, after confirming', (tester) async {
    Map<String, Object?> payment(String status, {bool canCancel = false}) => {
      'token': 'tok',
      'code': 'VNBUCS88T2F',
      'status': status,
      'open': status == 'awaiting',
      'can_cancel': canCancel,
      'amount_vnd': 4000,
      'received_vnd': 0,
      'remaining_vnd': 4000,
      'expires_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      'purpose': 'bookings',
      'bank': {'code': 'VPBank', 'account_number': '0123', 'account_name': 'VN BADMINTON'},
      'bookings': <Object>[],
    };
    final server = FakeServer({
      'GET /payments/tok': (200, payment('awaiting', canCancel: true)),
      'PATCH /payments/tok/cancel': (200, payment('cancelled')),
    });
    // A tall screen, so the whole transfer page is built at once.
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      PaymentScreen(token: 'tok', initial: Payment.fromJson(payment('awaiting', canCancel: true))),
      server: server,
    );

    await tester.tap(find.text('Huỷ đặt sân'));
    await tester.pump();
    await tester.tap(find.text('Không huỷ'));
    await tester.pump();
    expect(server.requests.where((request) => request.method == 'PATCH'), isEmpty);

    await tester.tap(find.text('Huỷ đặt sân'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Huỷ đặt sân'));
    await tester.pump();
    await tester.pump();
    expect(server.requests.last.url.path, '/api/v1/payments/tok/cancel');
    expect(find.text('Đơn này đã bị huỷ.'), findsOneWidget);
    expect(find.text('Huỷ đặt sân'), findsNothing);
  });
}
