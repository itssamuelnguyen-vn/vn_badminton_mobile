import 'package:flutter/material.dart';

import '../app_lock.dart';
import '../app_state.dart';
import '../strings.dart';
import '../widgets.dart';

/// Language and the fingerprint lock. (Notifications come with push.)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleBiometric(BuildContext context, bool value) async {
    final s = S.of(context);
    final state = AppScope.read(context);
    if (value) {
      // Asked once now, so a phone without a fingerprint or screen lock cannot lock the customer out.
      if (!await AppLock.available()) {
        if (context.mounted) showMessage(context, s.biometricUnavailable);
        return;
      }
      if (!await AppLock.authenticate(s.unlockReason)) return;
    }
    await state.setBiometricLock(value);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(s.language),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'vi', label: Text('Tiếng Việt')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {state.locale},
            showSelectedIcon: false,
            onSelectionChanged: (value) => state.setLocale(value.first),
          ),
        ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: Text(s.biometric),
          subtitle: Text(s.biometricHint),
          value: state.biometricLock,
          onChanged: (value) => _toggleBiometric(context, value),
        ),
      ]),
    );
  }
}
