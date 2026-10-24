import 'package:intl/intl.dart';

/// The venue is in Vietnam (UTC+7, no daylight saving): times are shown in the venue's time whatever the
/// phone's time zone.
const venueOffset = Duration(hours: 7);

DateTime venueTime(DateTime time) => time.toUtc().add(venueOffset);

/// "2026-10-20T18:00:00+07:00", as the API expects.
String venueIso(DateTime time) => '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(venueTime(time))}+07:00';

/// "2026-10-20": the venue's date of a time, as the API's ?date= wants it.
String venueDate(DateTime time) => DateFormat('yyyy-MM-dd').format(venueTime(time));

String hhmm(DateTime time) => DateFormat('HH:mm').format(venueTime(time));

String timeRange(DateTime from, DateTime to) => '${hhmm(from)}–${hhmm(to)}';

/// "Thứ 3, 20/10/2026" (vi) or "Tue, 20/10/2026" (en).
String longDate(DateTime time, String locale) => DateFormat('EEE, dd/MM/yyyy', locale).format(venueTime(time));

/// "Thứ 3" (vi) or "Tue" (en), and "20", for a date the API gives as "2026-10-20".
String weekdayShort(String isoDate, String locale) => DateFormat('EEE', locale).format(DateTime.parse(isoDate));

String dayOfMonth(String isoDate) => DateFormat('dd').format(DateTime.parse(isoDate));

/// 1080 -> "18:00" (minutes since midnight, as the API gives opening times).
String minuteLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

/// "2026-11-03" -> "03/11/2026".
String isoDateLabel(String isoDate) => DateFormat('dd/MM/yyyy').format(DateTime.parse(isoDate));

String vnd(int amount) => '${NumberFormat.decimalPattern('vi').format(amount)} đ';

String countdown(Duration left) {
  if (left.isNegative) return '00:00';
  final minutes = left.inMinutes.toString().padLeft(2, '0');
  final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
