import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'google_auth.dart';
import 'models.dart';
import 'push.dart';
import 'strings.dart';

/// Someone new signed in with Google: the server needs their phone number to create the account
/// (AppState.registerWithGoogle).
class GoogleSignup {
  const GoogleSignup({required this.signupToken, required this.name, required this.email});

  final String signupToken;
  final String name;
  final String email;
}

/// Who is signed in, the app's language and the venue, shared by every screen (AppScope.of(context)).
class AppState extends ChangeNotifier {
  AppState({Api? api, PushService? push, GoogleAuth? google})
    : api = api ?? Api(apiUrl),
      push = push ?? FirebasePush(),
      google = google ?? PlatformGoogleAuth() {
    this.api.onUnauthorized = () => _forget();
  }

  final Api api;
  final PushService push;
  final GoogleAuth google;
  final _secure = const FlutterSecureStorage();

  User? user;
  Venue? venue;

  /// The member tier (UD-01), with the account.
  Loyalty? loyalty;
  String locale = 'vi';

  /// "Open the app with a fingerprint or the face" (Settings), kept on the phone.
  bool biometricLock = false;

  /// "Notifications" (Settings), kept on the phone: on, the phone's FCM token is on the server (TB-01 there).
  bool notifications = true;

  /// Whether the customer was already asked to allow notifications (Android 13+), once.
  bool notificationsAsked = false;

  /// The token last sent to the server, to remove it again.
  String? _deviceToken;
  StreamSubscription<String>? _tokenRefresh;

  bool get signedIn => user != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    locale = prefs.getString('locale') ?? 'vi';
    biometricLock = prefs.getBool('biometric_lock') ?? false;
    notifications = prefs.getBool('notifications') ?? true;
    notificationsAsked = prefs.getBool('notifications_asked') ?? false;
    api.locale = locale;
    api.token = await _secure.read(key: 'token');
    if (api.token != null) {
      try {
        await refreshUser();
        // Each start: the token may have changed while the app was closed.
        unawaited(registerDevice());
      } on ApiError catch (error) {
        // Offline: stay signed in, the next request will tell.
        if (!error.isNetwork) await _forget();
      }
    }
    loadVenue();
  }

  /// Shows the push notifications and opens the page of the one tapped ([onOpen], deep_links.dart).
  Future<void> startPush({required String channelName, required void Function(String path) onOpen}) async {
    await push.listen(channelName: channelName, onOpen: onOpen);
    _tokenRefresh ??= (await push.start()) ? push.onTokenRefresh.listen((_) => registerDevice()) : null;
  }

  /// Sends the phone's FCM token to the server when signed in with notifications on. Failures are left for the
  /// next start: notifications are not worth an error message.
  Future<void> registerDevice() async {
    if (!signedIn || !notifications) return;
    try {
      final token = await push.token();
      if (token == null || !signedIn) return;
      await api.post('/device_tokens', {'token': token, 'platform': 'android', 'app_version': await _appVersion()});
      _deviceToken = token;
    } catch (_) {
      // Offline, or Firebase unavailable.
    }
  }

  Future<void> _unregisterDevice() async {
    final token = _deviceToken ?? await push.token();
    if (token == null) return;
    try {
      await api.delete('/device_tokens', {'token': token});
      _deviceToken = null;
    } on ApiError {
      // Signing out removes it on the server anyway.
    }
  }

  /// The "Notifications" switch: on asks Android's permission (false when refused), off removes the token from the server.
  Future<bool> setNotifications(bool value) async {
    if (value && !await push.permissionGranted() && !await push.requestPermission()) return false;
    notifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    value ? await registerDevice() : await _unregisterDevice();
    return true;
  }

  /// After asking once (the question after signing in), whatever the answer.
  Future<void> markNotificationsAsked() async {
    notificationsAsked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_asked', true);
  }

  Future<String?> _appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadVenue() async {
    try {
      venue = Venue.fromJson(await api.get('/venue'));
      notifyListeners();
    } on ApiError {
      // Shown again on the next try; the venue is only needed for the contact links and the policy.
    }
  }

  Future<void> refreshUser() async {
    final json = await api.get('/account');
    user = User.fromJson(json['user']);
    loyalty = json['loyalty'] is Map ? Loyalty.fromJson(json['loyalty'] as Map<String, dynamic>) : null;
    notifyListeners();
  }

  Future<void> signIn(String login, String password) async {
    final json = await api.post('/session', {'login': login.trim(), 'password': password, 'device_name': 'Android'});
    await _remember(json);
  }

  /// "Sign in with Google": null when signed in, or when the customer closed Google's account picker; a
  /// [GoogleSignup] when the account is new and needs a phone number.
  Future<GoogleSignup?> signInWithGoogle() async {
    final idToken = await google.idToken();
    if (idToken == null) return null;
    final json = await api.post('/session/google', {'id_token': idToken, 'device_name': 'Android'});
    if (json['needs_phone'] == true) {
      return GoogleSignup(
        signupToken: json['signup_token'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
    }
    await _remember(json);
    return null;
  }

  /// The end of a Google sign-in for someone new: their name, phone and privacy consent.
  Future<void> registerWithGoogle(GoogleSignup signup, {required String fullName, required String phone}) async {
    final json = await api.post('/registration/google', {
      'signup_token': signup.signupToken,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'privacy_consent': true,
      'locale': locale,
      'device_name': 'Android',
    });
    await _remember(json);
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final json = await api.post('/registration', {
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'password': password,
      'privacy_consent': true,
      'locale': locale,
      'device_name': 'Android',
    });
    await _remember(json);
  }

  Future<void> signOut() async {
    // The server also drops the token with the sign-in; said first in case the sign-in is already gone.
    await _unregisterDevice();
    try {
      await api.delete('/session');
    } on ApiError {
      // Forgotten on the phone anyway.
    }
    unawaited(google.signOut());
    await _forget();
  }

  /// After the account was deleted: the token no longer works.
  Future<void> forget() => _forget();

  Future<void> setLocale(String value) async {
    locale = value;
    api.locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', value);
    unawaited(push.renameChannel(S(value).notificationChannel));
    if (signedIn) {
      try {
        await api.patch('/account', {'locale': value});
      } on ApiError {
        // Emails keep the old language until the next change.
      }
    }
    loadVenue();
  }

  Future<void> setBiometricLock(bool value) async {
    biometricLock = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock', value);
  }

  /// Name, phone and the optional profile (TK-10); null clears a profile field.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    int? birthYear,
    String? gender,
    String? skillLevel,
  }) async {
    final json = await api.patch('/account', {
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'birth_year': birthYear,
      'gender': gender,
      'skill_level': skillLevel,
    });
    user = User.fromJson(json['user']);
    notifyListeners();
  }

  Future<void> uploadAvatar(String filePath) async {
    final json = await api.upload('PUT', '/account/avatar', 'avatar', filePath);
    user = User.fromJson(json['user']);
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    final json = await api.delete('/account/avatar');
    user = User.fromJson(json['user']);
    notifyListeners();
  }

  Future<void> _remember(dynamic json) async {
    api.token = json['token'] as String;
    await _secure.write(key: 'token', value: api.token);
    user = User.fromJson(json['user']);
    notifyListeners();
    unawaited(registerDevice());
  }

  Future<void> _forget() async {
    _deviceToken = null;
    api.token = null;
    user = null;
    loyalty = null;
    await _secure.delete(key: 'token');
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Without listening to changes (in callbacks).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
