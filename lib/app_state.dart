import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Who is signed in, the app's language and the venue, shared by every screen (AppScope.of(context)).
class AppState extends ChangeNotifier {
  AppState({Api? api}) : api = api ?? Api(apiUrl) {
    this.api.onUnauthorized = () => _forget();
  }

  final Api api;
  final _secure = const FlutterSecureStorage();

  User? user;
  Venue? venue;

  /// The member tier (UD-01), with the account.
  Loyalty? loyalty;
  String locale = 'vi';

  /// "Open the app with a fingerprint or the face" (Settings), kept on the phone.
  bool biometricLock = false;

  bool get signedIn => user != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    locale = prefs.getString('locale') ?? 'vi';
    biometricLock = prefs.getBool('biometric_lock') ?? false;
    api.locale = locale;
    api.token = await _secure.read(key: 'token');
    if (api.token != null) {
      try {
        await refreshUser();
      } on ApiError catch (error) {
        // Offline: stay signed in, the next request will tell.
        if (!error.isNetwork) await _forget();
      }
    }
    loadVenue();
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
    try {
      await api.delete('/session');
    } on ApiError {
      // Forgotten on the phone anyway.
    }
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
  }

  Future<void> _forget() async {
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
