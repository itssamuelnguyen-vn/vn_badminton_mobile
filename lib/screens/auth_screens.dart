import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../strings.dart';
import '../widgets.dart';

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
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = S.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      appBar: AppBar(title: Text(s.signIn)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _login,
            decoration: InputDecoration(labelText: s.login),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
            validator: required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(labelText: s.password),
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
          FilledButton(onPressed: _busy ? null : _submit, child: Text(s.signIn)),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : _signUp, child: Text(s.noAccount)),
        ]),
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
      await AppScope.read(context).register(
        fullName: _fullName.text,
        phone: _phone.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      showMessage(context, s.verificationSent);
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: Text(s.signUp)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _fullName,
            decoration: InputDecoration(labelText: s.fullName),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            validator: required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            decoration: InputDecoration(labelText: s.phone),
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            decoration: InputDecoration(labelText: s.email),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(labelText: s.password, helperText: s.passwordHint),
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
          FilledButton(onPressed: _busy ? null : _submit, child: Text(s.signUp)),
        ]),
      ),
    );
  }
}
