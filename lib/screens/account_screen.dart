import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../strings.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'home_shell.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'whats_new_screen.dart';

/// The account tab: profile card, shortcuts, contact and directions, settings and the app's information.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final user = state.user;
    final venue = state.venue;
    final links = venue?.contactLinks ?? const {};
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: Text(s.tabAccount)),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        if (user == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(child: FilledButton(onPressed: () => ensureSignedIn(context), child: Text(s.signIn))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(onPressed: () => push(const SignUpScreen()), child: Text(s.signUp))),
            ]),
          )
        else ...[
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Avatar(user: user),
              title: Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
              subtitle: Text(
                [user.email, if (user.skillLevel != null) s.skillLabel(user.skillLevel!)].join('\n'),
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => push(const ProfileScreen()),
            ),
          ),
          if (!user.emailVerified)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined, color: Colors.orange),
                title: Text(s.notVerified),
                trailing: TextButton(onPressed: () => _resendVerification(context), child: Text(s.resendVerification)),
              ),
            ),
          if (user.bookingLockedUntil != null && user.bookingLockedUntil!.isAfter(DateTime.now()))
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_clock),
                title: Text(s.bookingLocked(longDate(user.bookingLockedUntil!, state.locale))),
              ),
            ),
          _section(context, s.activity),
          _group([
            ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(s.myBookings),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => HomeShell.showTab(context, 1),
            ),
          ]),
        ],
        if (venue != null) ...[
          _section(context, s.contactVenue),
          _group([
            ListTile(
              leading: const Icon(Icons.directions),
              title: Text(s.directions),
              subtitle: Text(venue.address),
              onTap: () => openLink('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(venue.address)}'),
            ),
            if (links['phone'] != null) ListTile(leading: const Icon(Icons.call), title: Text(s.call), onTap: () => openLink(links['phone']!)),
            if (links['zalo'] != null) ListTile(leading: const Icon(Icons.chat), title: const Text('Zalo'), onTap: () => openLink(links['zalo']!)),
            if (links['messenger'] != null)
              ListTile(leading: const Icon(Icons.message), title: const Text('Messenger'), onTap: () => openLink(links['messenger']!)),
          ]),
        ],
        _section(context, s.system),
        _group([
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(s.settings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const SettingsScreen()),
          ),
          ListTile(leading: const Icon(Icons.info_outline), title: Text(s.versionInfo), onTap: () => _showVersion(context)),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: Text(s.terms),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openLink('$apiUrl/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: Text(s.whatsNew),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const WhatsNewScreen()),
          ),
        ]),
        if (user != null) ...[
          const SizedBox(height: 16),
          _group([
            ListTile(leading: const Icon(Icons.logout), title: Text(s.signOut), onTap: state.signOut),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              title: Text(s.deleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _deleteAccount(context),
            ),
          ]),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );

  Widget _group(List<Widget> tiles) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: ListTile.divideTiles(tiles: tiles, color: Colors.black12).toList()),
      );

  Future<void> _showVersion(BuildContext context) async {
    final s = S.of(context);
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'VN Badminton',
      applicationVersion: s.version(info.version, info.buildNumber),
      applicationIcon: Image.asset('assets/logo.png', width: 56, height: 56),
    );
  }

  Future<void> _resendVerification(BuildContext context) async {
    final s = S.of(context);
    try {
      await AppScope.read(context).api.post('/account/resend_verification');
      if (context.mounted) showMessage(context, s.resent);
    } catch (error) {
      if (context.mounted) showMessage(context, s.error(error));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final password = TextEditingController();
    String? error;

    final Map<String, dynamic> account;
    try {
      account = await state.api.get('/account');
    } catch (e) {
      if (context.mounted) showMessage(context, s.error(e));
      return;
    }
    if (!context.mounted) return;
    if (account['can_delete'] != true) return showMessage(context, s.deleteNotAllowed);

    final deletedAfter = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(s.deleteAccount),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.deleteExplain),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: s.password)),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
              onPressed: () async {
                try {
                  final json = await state.api.delete('/account', {'password': password.text});
                  if (dialogContext.mounted) Navigator.pop(dialogContext, (json['deleted_after'] as String?) ?? '');
                } catch (e) {
                  setDialogState(() => error = s.error(e));
                }
              },
              child: Text(s.deleteAccount),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    if (deletedAfter == null) return;

    await state.forget();
    if (!context.mounted) return;
    showMessage(context,
        deletedAfter.isEmpty ? s.accountDeleted : s.deletedAfter(longDate(DateTime.parse(deletedAfter), state.locale)));
  }
}
