import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// "Nhóm chơi" (NH-01..03): the customer's groups, their members and the bookings shared with each one (with
/// each player's share); creating a group, joining one with its code, inviting friends, leaving.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group>? _groups;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/groups');
      if (mounted) setState(() => _groups = [for (final g in json['groups'] as List) Group.fromJson(g)]);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<String?> _ask(String title, String label, {bool code = false}) async {
    final controller = TextEditingController();
    final s = S.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: code ? 6 : 50,
          textCapitalization: code ? TextCapitalization.characters : TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(s.confirm)),
        ],
      ),
    );
    controller.dispose();
    return (value ?? '').isEmpty ? null : value;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _load();
    } catch (error) {
      if (mounted) showMessage(context, S.of(context).error(error));
    }
  }

  Future<void> _create() async {
    final s = S.of(context);
    final name = await _ask(s.newGroup, s.groupName);
    if (name == null || !mounted) return;
    _run(() => AppScope.read(context).api.post('/groups', {'name': name}));
  }

  Future<void> _join() async {
    final s = S.of(context);
    final code = await _ask(s.joinGroup, s.groupCode, code: true);
    if (code == null || !mounted) return;
    _run(() => AppScope.read(context).api.post('/groups/join', {'code': code}));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = _groups;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: s.groups,
            subtitle: s.groupsIntro,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      icon: const Icon(Icons.group_add_rounded),
                      label: Text(s.newGroup),
                      onPressed: _create,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      icon: const Icon(Icons.vpn_key_rounded),
                      label: Text(s.joinGroup),
                      onPressed: _join,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: groups == null
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (groups.isEmpty) EmptyState(icon: Icons.groups_2_rounded, text: s.noGroups),
                        for (final group in groups) _card(s, group),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(S s, Group group) {
    final locale = AppScope.of(context).locale;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.groups_2_rounded, AppColors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      s.membersCount(group.members.length),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.share_rounded, size: 16),
                label: Text(group.inviteCode, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(text: s.inviteText(group.name, group.inviteCode))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final member in group.members)
                StatusPill(
                  member.name,
                  member.owner ? AppColors.orange : AppColors.primary,
                  icon: member.owner ? Icons.star_rounded : null,
                ),
            ],
          ),
          if (group.shares.isNotEmpty) ...[
            const Divider(height: 24),
            Text(s.sharedBookings, style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final share in group.shares)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    DateTile(share.startsAt, locale),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${share.court} · ${timeRange(share.startsAt, share.endsAt)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            s.sharedBy(share.sharedBy),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                          Text(
                            '${vnd(share.totalVnd)} · ${s.perPerson(vnd(share.perPlayerVnd))}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ),
                    if (share.mine || group.owner)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                        onPressed: () =>
                            _run(() => AppScope.read(context).api.delete('/groups/${group.id}/shares/${share.id}')),
                      ),
                  ],
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.rose),
              onPressed: () => _run(
                () => group.owner && group.members.length == 1
                    ? AppScope.read(context).api.delete('/groups/${group.id}')
                    : AppScope.read(context).api.delete('/groups/${group.id}/leave'),
              ),
              child: Text(group.owner && group.members.length == 1 ? s.deleteGroup : s.leaveGroup),
            ),
          ),
        ],
      ),
    );
  }
}
