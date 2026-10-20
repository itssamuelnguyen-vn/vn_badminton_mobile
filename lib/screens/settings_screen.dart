import 'package:flutter/material.dart';

import '../app_lock.dart';
import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(title: s.settings),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBadge(Icons.translate_rounded, AppColors.blue),
                          const SizedBox(width: 12),
                          Text(s.language, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'vi', label: Text('Tiếng Việt')),
                            ButtonSegment(value: 'en', label: Text('English')),
                          ],
                          selected: {state.locale},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) => state.setLocale(value.first),
                        ),
                      ),
                    ],
                  ),
                ),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SwitchListTile(
                    secondary: const IconBadge(Icons.fingerprint_rounded, AppColors.violet),
                    title: Text(s.biometric),
                    subtitle: Text(s.biometricHint),
                    value: state.biometricLock,
                    onChanged: (value) => _toggleBiometric(context, value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
