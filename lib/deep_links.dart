import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

/// Where a link of the server's emails or a push notification leads in the app (Android App Links, see
/// docs/app-links.md; push.dart).
enum LinkTarget { payment, booking, bookings, tournament, home }

class DeepLink {
  const DeepLink(this.target, [this.value]);

  final LinkTarget target;

  /// The payment token, the booking code or the tournament's id.
  final String? value;

  @override
  bool operator ==(Object other) => other is DeepLink && other.target == target && other.value == value;

  @override
  int get hashCode => Object.hash(target, value);

  @override
  String toString() => 'DeepLink($target, $value)';
}

/// The web page a link opens, as a screen of the app: `/payments/<token>`, `/bookings/<code>`, `/bookings` and
/// `/tournaments/<id>`,
/// with or without the /en prefix of the English pages. Any other page of the server opens the home screen; links
/// to another host are ignored (null).
DeepLink? parseDeepLink(Uri uri, {String? host}) {
  if (host != null && host.isNotEmpty && uri.host != host) return null;
  var segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.isNotEmpty && segments.first == 'en') segments = segments.sublist(1);

  if (segments.length == 2 && segments[0] == 'payments' && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segments[1])) {
    return DeepLink(LinkTarget.payment, segments[1]);
  }
  // Booking codes are upper-case letters and digits; /bookings/new and the like are web pages only.
  if (segments.length == 2 && segments[0] == 'bookings' && RegExp(r'^[A-Z0-9]{4,16}$').hasMatch(segments[1])) {
    return DeepLink(LinkTarget.booking, segments[1]);
  }
  if (segments.length == 1 && segments[0] == 'bookings') return const DeepLink(LinkTarget.bookings);
  if (segments.length == 2 && segments[0] == 'tournaments' && RegExp(r'^\d+$').hasMatch(segments[1])) {
    return DeepLink(LinkTarget.tournament, segments[1]);
  }
  return const DeepLink(LinkTarget.home);
}

/// The last link the app was opened with, until the home screen shows it (it may arrive before the screen is
/// built, e.g. while the app lock asks for the fingerprint).
final pendingLink = ValueNotifier<DeepLink?>(null);

/// The page of a push notification tapped (`data.path`, e.g. `/bookings/K7Q2M9XA`), opened like a link.
void openPath(String path) {
  final uri = Uri.tryParse(path);
  if (uri != null) pendingLink.value = parseDeepLink(Uri(path: uri.path));
}

StreamSubscription<Uri>? _links;

/// Listens to the links that open the app, at start-up and while it runs.
void listenToLinks() {
  final host = Uri.tryParse(apiUrl)?.host;
  _links ??= AppLinks().uriLinkStream.listen((uri) {
    final link = parseDeepLink(uri, host: host);
    if (link != null) pendingLink.value = link;
  }, onError: (_) {});
}
