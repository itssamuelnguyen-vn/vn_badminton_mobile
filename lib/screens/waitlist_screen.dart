import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// The times the customer waits for (TI-04): added by tapping a taken cell of the schedule, removed here.
class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  List<WaitlistEntry>? _entries;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/waitlist');
      if (mounted) setState(() => _entries = [for (final e in json['entries'] as List) WaitlistEntry.fromJson(e)]);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _remove(WaitlistEntry entry) async {
    try {
      await AppScope.read(context).api.delete('/waitlist/${entry.id}');
      _load();
    } catch (error) {
      if (mounted) showMessage(context, S.of(context).error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = AppScope.of(context).locale;
    final entries = _entries;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(title: s.waitlist, subtitle: s.notifyHint),
          Expanded(
            child: entries == null
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (entries.isEmpty) EmptyState(icon: Icons.notifications_none_rounded, text: s.waitlistEmpty),
                        for (final entry in entries)
                          SoftCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                DateTile(entry.startsAt, locale),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        timeRange(entry.startsAt, entry.endsAt),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      Text(
                                        longDate(entry.startsAt, locale),
                                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(onPressed: () => _remove(entry), child: Text(s.remove)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
