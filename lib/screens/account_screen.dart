import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'groups_screen.dart';
import 'home_shell.dart';
import 'packages_screen.dart';
import 'profile_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'waitlist_screen.dart';
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

    final directions = venue == null
        ? null
        : () => openLink('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(venue.address)}');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: s.tabAccount,
            child: user == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.welcome,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(s.welcomeText, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryDark,
                                ),
                                onPressed: () => ensureSignedIn(context),
                                child: Text(s.signIn),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 1.5),
                                ),
                                onPressed: () => push(const SignUpScreen()),
                                child: Text(s.signUp),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () => push(const ProfileScreen()),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.5)),
                          child: Avatar(user: user, radius: 34),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                user.email,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                              ),
                              if (user.skillLevel != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.lime,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    s.skillLabel(user.skillLevel!),
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2)),
                          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                          onPressed: () => push(const ProfileScreen()),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (user != null) const _LoyaltyCard(),
                if (user != null && !user.emailVerified)
                  SoftCard(
                    child: Row(
                      children: [
                        const IconBadge(Icons.mark_email_unread_rounded, AppColors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.notVerified, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        TextButton(onPressed: () => _resendVerification(context), child: Text(s.resendVerification)),
                      ],
                    ),
                  ),
                if (user?.bookingLockedUntil != null && user!.bookingLockedUntil!.isAfter(DateTime.now()))
                  SoftCard(
                    child: Row(
                      children: [
                        const IconBadge(Icons.lock_clock_rounded, AppColors.rose),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.bookingLocked(longDate(user.bookingLockedUntil!, state.locale)))),
                      ],
                    ),
                  ),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user != null)
                        _QuickAction(
                          Icons.event_note_rounded,
                          s.myBookings,
                          AppColors.primary,
                          () => HomeShell.showTab(context, 1),
                        ),
                      if (directions != null)
                        _QuickAction(Icons.directions_rounded, s.directions, AppColors.blue, directions),
                      if (links['phone'] != null)
                        _QuickAction(Icons.call_rounded, s.call, AppColors.orange, () => openLink(links['phone']!)),
                      if (links['zalo'] != null)
                        _QuickAction(Icons.chat_rounded, 'Zalo', AppColors.zalo, () => openLink(links['zalo']!)),
                      if (links['messenger'] != null)
                        _QuickAction(
                          Icons.forum_rounded,
                          'Messenger',
                          AppColors.violet,
                          () => openLink(links['messenger']!),
                        ),
                    ],
                  ),
                ),
                if (user != null) ...[
                  SectionTitle(s.activity),
                  _group([
                    _tile(Icons.groups_2_rounded, AppColors.blue, s.groups, () => push(const GroupsScreen())),
                    _tile(Icons.inventory_2_rounded, AppColors.violet, s.packages, () => push(const PackagesScreen())),
                    _tile(Icons.repeat_rounded, AppColors.primary, s.regularBookings, () => push(const SeriesScreen())),
                    _tile(
                      Icons.notifications_active_rounded,
                      AppColors.orange,
                      s.waitlist,
                      () => push(const WaitlistScreen()),
                    ),
                  ]),
                ],
                if (venue != null) ...[
                  SectionTitle(s.contactVenue),
                  SoftCard(
                    onTap: directions,
                    child: Row(
                      children: [
                        const IconBadge(Icons.location_on_rounded, AppColors.rose),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(venue.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(venue.address, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                      ],
                    ),
                  ),
                ],
                SectionTitle(s.system),
                _group([
                  _tile(Icons.settings_rounded, AppColors.muted, s.settings, () => push(const SettingsScreen())),
                  _tile(
                    Icons.info_rounded,
                    AppColors.blue,
                    s.versionInfo,
                    () => _showVersion(context),
                    trailing: false,
                  ),
                  _tile(
                    Icons.policy_rounded,
                    AppColors.teal,
                    s.terms,
                    () => openLink('$apiUrl/privacy'),
                    external: true,
                  ),
                  _tile(Icons.auto_awesome_rounded, AppColors.violet, s.whatsNew, () => push(const WhatsNewScreen())),
                ]),
                if (user != null) ...[
                  const SizedBox(height: 16),
                  _group([
                    _tile(Icons.logout_rounded, AppColors.muted, s.signOut, state.signOut, trailing: false),
                    _tile(
                      Icons.delete_forever_rounded,
                      AppColors.rose,
                      s.deleteAccount,
                      () => _deleteAccount(context),
                      trailing: false,
                      danger: true,
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(List<Widget> tiles) => SoftCard(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        for (final (i, tile) in tiles.indexed) ...[if (i > 0) const Divider(indent: 68, endIndent: 16), tile],
      ],
    ),
  );

  Widget _tile(
    IconData icon,
    Color color,
    String title,
    VoidCallback onTap, {
    bool trailing = true,
    bool external = false,
    bool danger = false,
  }) => ListTile(
    leading: IconBadge(icon, color, size: 38),
    title: Text(title, style: danger ? const TextStyle(color: AppColors.rose) : null),
    trailing: external
        ? const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.muted)
        : trailing
        ? const Icon(Icons.chevron_right_rounded, color: AppColors.muted)
        : null,
    onTap: onTap,
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.deleteExplain),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: s.password),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
              ],
            ],
          ),
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
    showMessage(
      context,
      deletedAfter.isEmpty ? s.accountDeleted : s.deletedAfter(longDate(DateTime.parse(deletedAfter), state.locale)),
    );
  }
}

/// A round coloured shortcut with its label under it, in the row at the top of the account tab.
class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                ),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The member tier (UD-01): name, discount, hours played and how far the next tier is.
class _LoyaltyCard extends StatefulWidget {
  const _LoyaltyCard();

  @override
  State<_LoyaltyCard> createState() => _LoyaltyCardState();
}

class _LoyaltyCardState extends State<_LoyaltyCard> {
  @override
  void initState() {
    super.initState();
    // Played hours change after each session: fresh each time the account tab is built.
    AppScope.read(context).refreshUser().catchError((_) {});
  }

  static const _colors = {
    'bronze': [Color(0xFFB45309), Color(0xFFF59E0B)],
    'silver': [Color(0xFF64748B), Color(0xFFCBD5E1)],
    'gold': [Color(0xFFCA8A04), Color(0xFFFDE047)],
    'diamond': [Color(0xFF4F46E5), Color(0xFF22D3EE)],
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final loyalty = AppScope.of(context).loyalty;
    if (loyalty == null || !loyalty.enabled) return const SizedBox.shrink();
    final colors = _colors[loyalty.tier] ?? _colors['bronze']!;
    final next = loyalty.nextHours;
    final hoursText = loyalty.hours == loyalty.hours.roundToDouble()
        ? '${loyalty.hours.round()}'
        : loyalty.hours.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.memberTier, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                    Text(
                      loyalty.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loyalty.percent > 0 ? s.tierDiscount(loyalty.percent) : s.noTierDiscount,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (next != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (loyalty.hours / next).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            [
              s.hoursPlayed(hoursText),
              if (next != null) s.toNextTier('${(next - loyalty.hours).ceil()}', loyalty.nextName ?? ''),
            ].join(' · '),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
