import 'package:flutter/services.dart';

import 'widgets.dart';

const _channel = MethodChannel('vn_badminton/calendar');

/// Opens the phone's calendar app on a new event, filled in (MainActivity.kt). Without a calendar app that
/// takes it, Google Calendar's "new event" page on the web.
Future<void> addToCalendar({
  required String title,
  required DateTime start,
  required DateTime end,
  required String location,
  required String description,
}) async {
  try {
    final opened = await _channel.invokeMethod<bool>('insertEvent', {
      'title': title,
      'begin': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'location': location,
      'description': description,
    });
    if (opened == true) return;
  } on PlatformException {
    // Falls back to the web page below.
  } on MissingPluginException {
    // Not on Android.
  }
  await openLink(googleCalendarUrl(title: title, start: start, end: end, location: location, description: description));
}

/// Google Calendar's "new event" page (times in UTC: 20261020T110000Z).
String googleCalendarUrl({
  required String title,
  required DateTime start,
  required DateTime end,
  required String location,
  required String description,
}) {
  String utc(DateTime time) => '${time.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${utc(start)}/${utc(end)}',
    'details': description,
    'location': location,
  }).toString();
}
