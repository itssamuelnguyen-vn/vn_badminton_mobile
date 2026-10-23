import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/deep_links.dart';

void main() {
  const host = 'court.example.vn';
  DeepLink? parse(String url) => parseDeepLink(Uri.parse(url), host: host);

  test('payment pages, in Vietnamese and English', () {
    expect(parse('https://court.example.vn/payments/aBc-123_xyz'), const DeepLink(LinkTarget.payment, 'aBc-123_xyz'));
    expect(
      parse('https://court.example.vn/en/payments/aBc-123_xyz/'),
      const DeepLink(LinkTarget.payment, 'aBc-123_xyz'),
    );
  });

  test('a booking and the bookings list', () {
    expect(parse('https://court.example.vn/bookings/K7MPX2QA'), const DeepLink(LinkTarget.booking, 'K7MPX2QA'));
    expect(parse('https://court.example.vn/en/bookings/K7MPX2QA?x=1'), const DeepLink(LinkTarget.booking, 'K7MPX2QA'));
    expect(parse('https://court.example.vn/bookings'), const DeepLink(LinkTarget.bookings));
    expect(parse('https://court.example.vn/en/bookings'), const DeepLink(LinkTarget.bookings));
  });

  test("a tournament's page (push notifications of the tournament)", () {
    expect(parse('https://court.example.vn/tournaments/12'), const DeepLink(LinkTarget.tournament, '12'));
    expect(parse('https://court.example.vn/tournaments'), const DeepLink(LinkTarget.home));
    expect(parse('https://court.example.vn/tournaments/x'), const DeepLink(LinkTarget.home));
  });

  test('other pages of the server open the home screen', () {
    for (final url in [
      'https://court.example.vn/',
      'https://court.example.vn/en',
      'https://court.example.vn/bookings/new',
      'https://court.example.vn/payments/abc/qr',
      'https://court.example.vn/privacy',
    ]) {
      expect(parse(url), const DeepLink(LinkTarget.home), reason: url);
    }
  });

  test('links to another host are ignored; without a known host every host is taken', () {
    expect(parse('https://evil.example.com/payments/abc'), isNull);
    expect(
      parseDeepLink(Uri.parse('https://any.trycloudflare.com/payments/abc')),
      const DeepLink(LinkTarget.payment, 'abc'),
    );
  });
}
