import 'package:google_sign_in/google_sign_in.dart';

/// The web OAuth client of the Google Cloud project: Google gives the app an ID token for it, and the server checks
/// it (GOOGLE_WEB_CLIENT_ID there). Public; another one can be given at build time with
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` (docs/firebase.md).
const googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '644407501095-l2oe4an1g7j2ont7spmevspm1l0ea8f0.apps.googleusercontent.com',
);

/// "Sign in with Google" on the phone (the account picker of Android). Replaced by a fake in the tests.
abstract class GoogleAuth {
  /// The ID token of the account picked, null when the customer closed the picker.
  /// Throws [GoogleSignInException] when Google sign-in fails (no Play services, wrong setup...).
  Future<String?> idToken();

  /// Forgets the account picked, so the picker shows again next time.
  Future<void> signOut();
}

class PlatformGoogleAuth implements GoogleAuth {
  Future<void>? _initialized;

  Future<void> _initialize() => _initialized ??= GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);

  @override
  Future<String?> idToken() async {
    await _initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled || error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _initialize();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to forget.
    }
  }
}
