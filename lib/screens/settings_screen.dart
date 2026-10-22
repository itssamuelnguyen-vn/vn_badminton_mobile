import 'package:flutter/material.dart';

import '../app_lock.dart';
import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// After signing in (and at start for those signed in before): asks once, with a word on what they are for, to allow
/// notifications. Nothing to ask when they are already allowed (before Android 13) or push is not set up.
Future<void> askForNotifications(BuildContext context) async {
  final state = AppScope.read(context);
  if (state.notificationsAsked || !state.signedIn || !state.notifications) return;
  if (!await state.push.start() || await state.push.permissionGranted()) return;
  if (!context.mounted) return;
  await state.markNotificationsAsked();
  if (!context.mounted) return;
  final s = S.of(context);
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
      title: Text(s.notificationsAskTitle),
      content: Text(s.notificationsAskText),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.notLater)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.notificationsAllow)),
      ],
    ),
  );
  // "Not now" or refused in Android's question: the switch in Settings shows them off, where to turn them on later.
  if (allow != true || !await state.setNotifications(true)) await state.setNotifications(false);
}

/// Language, notifications and the fingerprint lock.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleNotifications(BuildContext context, bool value) async {
    final s = S.of(context);
    final state = AppScope.read(context);
    if (value && !await state.push.start()) {
      if (context.mounted) showMessage(context, s.notificationsUnavailable);
      return;
    }
    if (!await state.setNotifications(value) && context.mounted) showMessage(context, s.notificationsDenied);
  }

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
                    secondary: const IconBadge(Icons.notifications_rounded, AppColors.primary),
                    title: Text(s.notifications),
                    subtitle: Text(s.notificationsHint),
                    value: state.signedIn && state.notifications,
                    onChanged: state.signedIn ? (value) => _toggleNotifications(context, value) : null,
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
