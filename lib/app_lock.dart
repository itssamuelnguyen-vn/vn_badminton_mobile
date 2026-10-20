import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'app_state.dart';
import 'strings.dart';

/// Asks for the fingerprint, the face or the screen lock when the app opens, and again when it comes back
/// after a few minutes in the background, if the customer turned it on in Settings.
class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.child});

  final Widget child;

  static const relockAfter = Duration(minutes: 5);

  static Future<bool> authenticate(String reason) async {
    try {
      return await LocalAuthentication().authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      // No fingerprint or screen lock set up, or the prompt failed: stays locked, the button can retry.
      return false;
    }
  }

  static Future<bool> available() async {
    try {
      return await LocalAuthentication().isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  late bool _locked = _shouldLock;
  DateTime? _pausedAt;
  bool _asking = false;

  bool get _shouldLock {
    final state = AppScope.read(context);
    return state.biometricLock && state.signedIn;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // The prompt itself sends the app to the background: only real absences count.
    if (lifecycle == AppLifecycleState.paused && !_asking) _pausedAt = DateTime.now();
    if (lifecycle == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away >= AppLock.relockAfter && _shouldLock) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final ok = await AppLock.authenticate(S(AppScope.read(context).locale).unlockReason);
    _asking = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final s = S.of(context);
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(s.locked, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.fingerprint), label: Text(s.unlock), onPressed: _unlock),
        ]),
      ),
    );
  }
}
