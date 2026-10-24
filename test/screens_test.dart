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

  group('tournaments (GD-01..07)', () {
    const token = 'Ab12Cd34Ef56Gh78';
    User an() => User.fromJson({'id': 1, 'full_name': 'Nguyễn An', 'email': 'an@example.com'});
    Map<String, Object?> side(int id, String name) => {'id': id, 'name': name};
    Map<String, Object?> tournament({
      String status = 'setup',
      bool creator = true,
      List<String> players = const ['An'],
      List<Object> matches = const [],
      String? champion,
    }) => {
      'token': token,
      'title': 'Giải cuối tuần',
      'description': 'Giải nhất: 1 hộp cầu',
      'event': 'Đơn',
      'discipline': 'singles',
      'play_format': 'knockout',
      'date': '2026-11-01',
      'status': status,
      'created_by': 'Nguyễn An',
      'creator': creator,
      'organizer': creator,
      'share_path': '/tournaments/$token',
      'champion': champion,
      'redrawable': false,
      'entries': [
        for (final (index, name) in players.indexed)
          {'id': index + 1, 'name': name, 'partner_name': null, 'seed': null},
      ],
      'bookings': <Object>[],
      'courts': <Object>[],
      'linkable_bookings': <Object>[],
      'organizer_path': creator ? '/tournaments/$token/organize/Zz98Yy76Xx54Ww32' : null,
      'organizers': <Object>[],
      'groups': <Object>[],
      'matches': matches,
    };
    Map<String, Object?> finalMatch({List<Object> scores = const [], int? winner}) => {
      'id': 9,
      'stage': 'knockout',
      'round': 1,
      'round_name': 'Chung kết',
      'position': 1,
      'a': side(1, 'An'),
      'b': side(2, 'Bình'),
      'winner_id': winner,
      'scores': scores,
      'walkover': false,
      'bye': false,
      'court': null,
      'court_id': null,
      'editable': true,
      'ready': winner == null,
    };

    testWidgets('signed out, the list asks to sign in; signed in, it lists the ones they run', (tester) async {
      await pumpScreen(tester, const Scaffold(body: TournamentList()));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập để tạo và quản lý giải đấu của bạn.'), findsOneWidget);

      final server = FakeServer({
        'GET /tournaments': (
          200,
          {
            'tournaments': [tournament(creator: false)],
          },
        ),
      });
      final state = fakeState(server: server)..user = an();
      await pumpScreen(
        tester,
        const Scaffold(body: TournamentList(key: ValueKey('in'))),
        state: state,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tạo giải mới'), findsOneWidget);
      expect(find.text('Giải cuối tuần'), findsOneWidget);
      expect(find.text('Bạn giúp Nguyễn An nhập tỉ số'), findsOneWidget);
    });

    testWidgets('the creator adds players (errors shown), makes the draw and enters the result', (tester) async {
      final server = FakeServer({
        'GET /tournaments/$token': (200, tournament()),
        'POST /tournaments/$token/entries': (
          422,
          {
            'error': 'invalid',
            'messages': ['Dòng 2: Tên quá dài'],
          },
        ),
      });
      tester.view.physicalSize = const Size(1080, 4800);
      addTearDown(tester.view.reset);
      final state = fakeState(server: server)..user = an();
      await pumpScreen(tester, const TournamentScreen(token: token), state: state);
      await tester.pumpAndSettle();
      expect(find.text('Người chơi (1)'), findsOneWidget);
      expect(find.text('Giải nhất: 1 hộp cầu'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Bình\nChi');
      await tester.tap(find.text('Thêm vào danh sách'));
      await tester.pumpAndSettle();
      expect(find.text('Dòng 2: Tên quá dài'), findsOneWidget);
      expect(jsonDecode(server.requests.last.body), {'list': 'Bình\nChi'});

      server.routes['POST /tournaments/$token/entries'] = (201, tournament(players: ['An', 'Bình', 'Chi']));
      await tester.tap(find.text('Thêm vào danh sách'));
      await tester.pumpAndSettle();
      expect(find.text('Người chơi (3)'), findsOneWidget);

      server.routes['POST /tournaments/$token/draw'] = (
        200,
        tournament(status: 'in_progress', players: ['An', 'Bình'], matches: [finalMatch()]),
      );
      await tester.tap(find.text('Bốc thăm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bốc thăm').last);
      await tester.pumpAndSettle();
      expect(server.requests.last.method, 'POST');
      expect(server.requests.last.url.path, '/api/v1/tournaments/$token/draw');
      expect(find.text('Sơ đồ loại trực tiếp'), findsOneWidget);
      expect(find.text('Thêm vào danh sách'), findsNothing);

      server.routes['PATCH /tournaments/$token/matches/9'] = (
        200,
        tournament(
          status: 'finished',
          champion: 'An',
          matches: [
            finalMatch(
              winner: 1,
              scores: [
                [21, 15],
                [21, 18],
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Bình'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập kết quả'), findsOneWidget);
      final fields = find.byType(TextField);
      for (final (index, points) in ['21', '15', '21', '18'].indexed) {
        await tester.enterText(fields.at(index), points);
      }
      await tester.tap(find.text('Lưu kết quả'));
      await tester.pumpAndSettle();
      expect(jsonDecode(server.requests.last.body), {
        'scores': [
          [21, 15],
          [21, 18],
        ],
      });
      expect(find.text('Vô địch'), findsOneWidget);
      expect(find.text('21 21'), findsOneWidget);
    });

    testWidgets('anyone with the link sees the page, without the tools', (tester) async {
      final server = FakeServer({
        'GET /tournaments/$token': (
          200,
          tournament(status: 'in_progress', creator: false, players: ['An', 'Bình'], matches: [finalMatch()]),
        ),
      });
      tester.view.physicalSize = const Size(1080, 4800);
      addTearDown(tester.view.reset);
      await pumpScreen(tester, const TournamentScreen(token: token), server: server);
      await tester.pumpAndSettle();
      expect(find.text('Tổ chức bởi Nguyễn An'), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.text('CHUNG KẾT'), findsOneWidget);
      for (final tool in ['Thêm người chơi', 'Người nhập tỉ số', 'Sân thi đấu']) {
        expect(find.text(tool), findsNothing, reason: tool);
      }
      await tester.tap(find.text('Bình'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập kết quả'), findsNothing);
    });

    testWidgets('the organizer link: accepting opens the page with the organizer tools', (tester) async {
      final server = FakeServer({
        'GET /tournaments/$token': (200, tournament(creator: false)),
        'POST /tournaments/$token/organize': (200, {...tournament(creator: false), 'organizer': true}),
      });
      final state = fakeState(server: server)..user = an();
      await pumpScreen(
        tester,
        const OrganizeTournamentScreen(token: token, organizerToken: 'Zz98Yy76Xx54Ww32'),
        state: state,
      );
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn An mời bạn cùng nhập tỉ số cho giải này.'), findsOneWidget);

      await tester.tap(find.text('Nhận quyền nhập tỉ số'));
      await tester.pumpAndSettle();
      expect(jsonDecode(server.requests.last.body), {'organizer_token': 'Zz98Yy76Xx54Ww32'});
      expect(find.text('Tổ chức bởi Nguyễn An'), findsOneWidget);
    });
  });
}
