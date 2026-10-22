import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings_screen.dart';

/// Opens the sign-in screen when nobody is signed in. True when someone is signed in afterwards.
Future<bool> ensureSignedIn(BuildContext context) async {
  if (AppScope.read(context).signedIn) return true;
  final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SignInScreen()));
  return result == true;
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).signIn(_login.text, _password.text);
      if (mounted) await _done();
    } catch (error) {
      if (mounted) setState(() => _error = S.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _done() async {
    await askForNotifications(context);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _signUp() async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SignUpScreen()));
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String? required(String? value) => (value ?? '').trim().isEmpty ? s.required : null;

    return Scaffold(
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(title: s.signIn, subtitle: s.welcomeText, actions: const [_Logo()]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _login,
                    decoration: InputDecoration(
                      labelText: s.login,
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(labelText: s.password, prefixIcon: const Icon(Icons.lock_rounded)),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: required,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(label: s.signIn, busy: _busy, onPressed: _submit),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _busy ? null : _signUp, child: Text(s.noAccount)),
                  GoogleSignInButton(onSignedIn: _done),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_fullName, _phone, _email, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    if (!_form.currentState!.validate()) return;
    if (!_consent) return setState(() => _error = s.privacyRequired);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context)
          .register(fullName: _fullName.text, phone: _phone.text, email: _email.text, password: _password.text);
      if (!mounted) return;
      showMessage(context, s.verificationSent);
      await _done();
    } catch (error) {
      if (mounted) setState(() => _error = s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _done() async {
    await askForNotifications(context);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String? required(String? value) => (value ?? '').trim().isEmpty ? s.required : null;

    return Scaffold(
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(title: s.signUp, subtitle: s.welcomeText, actions: const [_Logo()]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: InputDecoration(labelText: s.fullName, prefixIcon: const Icon(Icons.person_rounded)),
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    decoration: InputDecoration(labelText: s.phone, prefixIcon: const Icon(Icons.phone_rounded)),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(labelText: s.email, prefixIcon: const Icon(Icons.email_rounded)),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: s.password,
                      helperText: s.passwordHint,
                      prefixIcon: const Icon(Icons.lock_rounded),
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: required,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (value) => setState(() => _consent = value ?? false),
                    title: Text(s.privacyConsent),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: () => openLink('$apiUrl/privacy'), child: Text(s.readPrivacy)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  GradientButton(label: s.signUp, busy: _busy, onPressed: _submit),
                  const SizedBox(height: 8),
                  GoogleSignInButton(onSignedIn: _done),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sign in with Google" under the sign-in and sign-up forms (AP-05 on the server): Google's account picker, then
/// the account is signed in, or someone new adds their phone number (GoogleSignupScreen). [onSignedIn] once signed in.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    final s = S.of(context);
    final state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signup = await state.signInWithGoogle();
      if (!mounted) return;
      if (signup != null) {
        final done = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => GoogleSignupScreen(signup: signup)));
        if (done != true) return;
      }
      // Still signed out: the account picker was closed.
      if (state.signedIn && mounted) await widget.onSignedIn();
    } on ApiError catch (error) {
      if (mounted) setState(() => _error = s.error(error));
    } catch (_) {
      if (mounted) setState(() => _error = s.googleFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(s.or, style: const TextStyle(color: AppColors.muted)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signIn,
          icon: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.g_mobiledata_rounded, size: 30),
          label: Text(s.signInWithGoogle),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

/// Someone new signed in with Google: name (from Google, can be changed), phone number and the privacy consent, as
/// the normal sign-up asks (TK-01). The email is Google's, already verified.
class GoogleSignupScreen extends StatefulWidget {
  const GoogleSignupScreen({super.key, required this.signup});

  final GoogleSignup signup;

  @override
  State<GoogleSignupScreen> createState() => _GoogleSignupScreenState();
}

class _GoogleSignupScreenState extends State<GoogleSignupScreen> {
  final _form = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.signup.name);
  final _phone = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    if (!_form.currentState!.validate()) return;
    if (!_consent) return setState(() => _error = s.privacyRequired);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).registerWithGoogle(widget.signup, fullName: _fullName.text, phone: _phone.text);
      if (!mounted) return;
      await askForNotifications(context);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String? required(String? value) => (value ?? '').trim().isEmpty ? s.required : null;

    return Scaffold(
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(title: s.googleSignupTitle, subtitle: s.googleSignupText(widget.signup.email)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: InputDecoration(labelText: s.fullName, prefixIcon: const Icon(Icons.person_rounded)),
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    decoration: InputDecoration(labelText: s.phone, prefixIcon: const Icon(Icons.phone_rounded)),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: required,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (value) => setState(() => _consent = value ?? false),
                    title: Text(s.privacyConsent),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: () => openLink('$apiUrl/privacy'), child: Text(s.readPrivacy)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  GradientButton(label: s.signUp, busy: _busy, onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The venue's logo on a white circle, in the corner of the sign-in header.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
    child: Image.asset('assets/logo.png', width: 48, height: 48),
  );
}
