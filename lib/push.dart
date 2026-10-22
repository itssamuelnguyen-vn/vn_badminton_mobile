import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'theme.dart';

/// Push notifications (Firebase Cloud Messaging) on this phone. The server sends them where the customer already
/// gets an email (booking confirmed, reminder, changes made by the venue...); each one carries the page to open
/// (`data.path`, like the links of the emails, deep_links.dart). AppState sends the token to the server.
///
/// Replaced by a fake in the tests (Firebase needs the phone).
abstract class PushService {
  /// False when push is not set up in this build (no google-services.json, docs/firebase.md) or Firebase fails.
  Future<bool> start();

  /// The phone's FCM registration token, null when it cannot be had (e.g. no Google Play services).
  Future<String?> token();

  Stream<String> get onTokenRefresh;

  /// Android 13+ asks the customer; before that notifications are allowed unless turned off in the phone's settings.
  Future<bool> permissionGranted();

  /// Shows Android's question (Android 13+). True when allowed.
  Future<bool> requestPermission();

  /// Shows the notifications that arrive while the app is open, and calls [onOpen] with the path of a notification
  /// tapped (app open, in the background or closed). [channelName] is the channel's name in the phone's settings.
  Future<void> listen({required String channelName, required void Function(String path) onOpen});

  /// The channel's name after the app's language changed.
  Future<void> renameChannel(String channelName);
}

class FirebasePush implements PushService {
  /// Also the server's channel (Push::Fcm::CHANNEL_ID) and AndroidManifest.xml's default channel.
  static const channelId = 'updates';
  static const _icon = 'ic_notification';

  final _local = FlutterLocalNotificationsPlugin();
  Future<bool>? _started;

  @override
  Future<bool> start() => _started ??= _start();

  Future<bool> _start() async {
    try {
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    if (!await start()) return null;
    try {
      // The registration token the server sends to (FCM HTTP v1 "token"). firebase_messaging 17 prefers the new
      // Installation IDs (register / onRegistered); the server would need another send target for them.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<bool> permissionGranted() async {
    if (!await start()) return false;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  @override
  Future<bool> requestPermission() async {
    if (!await start()) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  @override
  Future<void> listen({required String channelName, required void Function(String path) onOpen}) async {
    if (!await start()) return;
    void open(String? path) {
      if (path != null && path.isNotEmpty) onOpen(path);
    }

    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)),
      onDidReceiveNotificationResponse: (response) => open(response.payload),
    );
    await renameChannel(channelName);

    // Android shows nothing by itself while the app is open: shown here, in the same channel.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        id: message.messageId.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            icon: _icon,
            color: AppColors.primary,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['path'] as String?,
      );
    });
    // Tapped while the app was in the background, or closed.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => open(message.data['path'] as String?));
    open((await FirebaseMessaging.instance.getInitialMessage())?.data['path'] as String?);
    // Shown by the app (above), tapped after the app was closed.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) open(launch!.notificationResponse?.payload);
  }

  @override
  Future<void> renameChannel(String channelName) async {
    if (!await start()) return;
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(channelId, channelName, importance: Importance.high));
  }
}
