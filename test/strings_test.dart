import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/api.dart';
import 'package:vn_badminton_mobile/strings.dart';

void main() {
  test('every text is written in Vietnamese and English (none left empty)', () {
    // Each text is one _(vi, en) call, so both languages always have the same texts; only an empty one can slip in.
    final source = File('lib/strings.dart').readAsStringSync();
    expect(RegExp(r"_\(\s*''\s*,").hasMatch(source), isFalse, reason: 'empty Vietnamese text');
    expect(RegExp(r",\s*''\s*,?\s*\)").hasMatch(source), isFalse, reason: 'empty English text');
  });

  test('Vietnamese by default, English when chosen', () {
    expect(const S('vi').exportData, 'Tải dữ liệu của tôi');
    expect(const S('en').exportData, 'Download my data');
    expect(const S('fr').tabBook, const S('vi').tabBook);
  });

  test("errors show the server's message, or a network / generic one", () {
    const s = S('en');
    expect(s.error(ApiError(429, 'rate_limited', ['Too many attempts.'])), 'Too many attempts.');
    expect(s.error(ApiError(0, 'network')), s.networkError);
    expect(s.error(StateError('x')), s.unknownError);
  });
}
