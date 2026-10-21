import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vn_badminton_mobile/format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    await initializeDateFormatting('en');
  });

  // 18:00 at the venue (UTC+7), whatever the time zone of the machine running the test.
  final evening = DateTime.parse('2026-10-20T18:00:00+07:00');

  test('times and dates are the venue time (UTC+7)', () {
    expect(hhmm(evening), '18:00');
    expect(timeRange(evening, evening.add(const Duration(minutes: 90))), '18:00–19:30');
    expect(venueDate(DateTime.parse('2026-10-20T20:00:00Z')), '2026-10-21');
    expect(venueIso(DateTime.utc(2026, 10, 20, 11)), '2026-10-20T18:00:00+07:00');
  });

  test('long dates and weekdays in Vietnamese and English', () {
    expect(longDate(evening, 'vi'), 'Thứ 3, 20/10/2026');
    expect(longDate(evening, 'en'), 'Tue, 20/10/2026');
    expect(weekdayShort('2026-10-25', 'vi'), 'CN');
    expect(weekdayShort('2026-10-25', 'en'), 'Sun');
    expect(dayOfMonth('2026-11-03'), '03');
    expect(isoDateLabel('2026-11-03'), '03/11/2026');
  });

  test('amounts in VND', () {
    expect(vnd(208000), '208.000 đ');
    expect(vnd(0), '0 đ');
    expect(shortVnd(40000), '40k');
    expect(shortVnd(42500), '42.500');
    expect(shortVnd(500), '500');
  });

  test('minutes since midnight and the countdown', () {
    expect(minuteLabel(1080), '18:00');
    expect(minuteLabel(330), '05:30');
    expect(countdown(const Duration(minutes: 14, seconds: 5)), '14:05');
    expect(countdown(const Duration(seconds: -1)), '00:00');
  });
}
