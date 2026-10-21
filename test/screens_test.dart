import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
