import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/models.dart';
import 'package:vn_badminton_mobile/screens/payment_screen.dart';
import 'package:vn_badminton_mobile/screens/tournaments_screen.dart';
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

  testWidgets("a tournament's page: the bracket with the winner, and entering a doubles event with a partner", (
    tester,
  ) async {
    Map<String, Object?> tournament({Map<String, Object?>? mine, List<Object> matches = const []}) => {
      'id': 7,
      'title': 'Giải đôi tháng 11',
      'event': 'Đôi nam nữ',
      'discipline': 'mixed_doubles',
      'play_format': 'knockout',
      'courts': ['Sân 1'],
      'starts_at': '2026-11-01T08:00:00+07:00',
      'ends_at': '2026-11-01T12:00:00+07:00',
      'registration_closes_at': '2026-10-31T20:00:00+07:00',
      'max_entries': 8,
      'spots_left': 6,
      'fee_vnd': 0,
      'status': matches.isEmpty ? 'open' : 'finished',
      'registration_open': matches.isEmpty,
      'my_entry': mine,
      'champion': matches.isEmpty ? null : 'An / Chi',
      'entries': [
        {'id': 1, 'name': 'An / Chi'},
        {'id': 2, 'name': 'Bình / Dung'},
      ],
      'groups': <Object>[],
      'matches': matches,
    };
    final server = FakeServer({
      'GET /tournaments/7': (200, tournament()),
      'POST /tournaments/7/entries': (
        201,
        tournament(
          mine: {'id': 3, 'name': 'Nguyễn An / Lê Chi', 'status': 'confirmed', 'amount_vnd': 0, 'can_cancel': true},
        ),
      ),
    });
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.reset);
    final state = await pumpScreen(tester, const TournamentScreen(id: 7), server: server);
    state.user = User.fromJson({'id': 1, 'full_name': 'Nguyễn An', 'email': 'an@example.com', 'gender': 'male'});
    await tester.pumpAndSettle();
    expect(find.text('Danh sách thi đấu (2)'), findsOneWidget);

    await tester.tap(find.text('Đăng ký thi đấu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Họ tên đồng đội'), 'Lê Chi');
    await tester.enterText(find.widgetWithText(TextFormField, 'Số điện thoại đồng đội'), '0933 000 111');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nữ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký thi đấu').last);
    await tester.pumpAndSettle();
    final sent = jsonDecode(server.requests.last.body) as Map<String, dynamic>;
    expect(sent['partner'], {'name': 'Lê Chi', 'phone': '0933 000 111', 'gender': 'female'});
    expect(find.text('Bạn đã có suất: Nguyễn An / Lê Chi'), findsOneWidget);

    server.routes['GET /tournaments/7'] = (
      200,
      tournament(
        matches: [
          {
            'id': 9,
            'stage': 'knockout',
            'round': 1,
            'round_name': 'Chung kết',
            'position': 1,
            'a': {'id': 1, 'name': 'An / Chi'},
            'b': {'id': 2, 'name': 'Bình / Dung'},
            'winner_id': 1,
            'scores': [
              [21, 15],
              [21, 18],
            ],
            'walkover': false,
            'bye': false,
          },
        ],
      ),
    );
    await pumpScreen(tester, const TournamentScreen(key: ValueKey('again'), id: 7), server: server);
    await tester.pumpAndSettle();
    expect(find.text('Sơ đồ loại trực tiếp'), findsOneWidget);
    expect(find.text('CHUNG KẾT'), findsOneWidget);
    expect(find.text('21 21'), findsOneWidget);
    expect(find.text('Vô địch'), findsOneWidget);
  });
}
