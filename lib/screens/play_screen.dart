import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'payment_screen.dart';
import 'tournaments_screen.dart';

/// The "Giao lưu" tab: open play (GL-01..03: coming sessions, places left, the customer's places; joining one
/// opens the transfer page) and, with the switch in the header, the customer's own tournaments (TournamentList).
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  List<PlaySession>? _sessions;
  Object? _error;
  int? _userId;
  bool _tournaments = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = AppScope.of(context).user?.id;
    if (_sessions == null || userId != _userId) {
      _userId = userId;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/play_sessions');
      if (mounted) setState(() => _sessions = [for (final s in json['sessions'] as List) PlaySession.fromJson(s)]);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _openPayment(String token, [Payment? initial]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(token: token, initial: initial),
      ),
    );
    _load();
  }

  Future<void> _join(PlaySession session) async {
    final s = S.of(context);
    if (!await ensureSignedIn(context) || !mounted) return;
    final quantity = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        var count = 1;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(session.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(s.howManyPlayers, style: const TextStyle(color: AppColors.muted)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: count > 1 ? () => setSheetState(() => count--) : null,
                      ),
                      Text('$count', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                        onPressed: count < session.seatsLeft && count < 10 ? () => setSheetState(() => count++) : null,
                      ),
                    ],
                  ),
                  Text(
                    vnd(session.priceVnd * count),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: s.joinSession,
                    icon: Icons.qr_code_2_rounded,
                    onPressed: () => Navigator.pop(context, count),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (quantity == null || !mounted) return;
    try {
      final json = await AppScope.read(context).api
          .post('/play_sessions/${session.id}/tickets', {'quantity': quantity});
      if (!mounted) return;
      final payment = Payment.fromJson(json);
      _openPayment(payment.token, payment);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
      _load();
    }
  }

  Future<void> _giveBack(Ticket ticket) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.givePlacesBack),
        content: Text(s.givePlacesBackConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.keep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.givePlacesBack),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AppScope.read(context).api.delete('/tickets/${ticket.id}');
      _load();
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sessions = _sessions;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: _tournaments ? s.tabTournaments : s.playTitle,
            subtitle: _tournaments ? s.tournamentsIntro : s.playIntro,
            child: _switch(s),
          ),
          Expanded(
            child: _tournaments
                ? const TournamentList()
                : sessions == null
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (sessions.isEmpty) EmptyState(icon: Icons.groups_rounded, text: s.noPlaySessions),
                        for (final session in sessions) _card(s, session),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Open play | Tournaments.
  Widget _switch(S s) => Container(
    margin: const EdgeInsets.only(top: 12, right: 12),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
    child: Row(
      children: [
        for (final (tournaments, label) in [(false, s.tabPlay), (true, s.tabTournaments)])
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tournaments = tournaments),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _tournaments == tournaments ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _tournaments == tournaments ? AppColors.primaryDark : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _card(S s, PlaySession session) {
    final locale = AppScope.of(context).locale;
    final taken = session.capacity - session.seatsLeft;
    final mine = session.myTickets;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DateTile(session.startsAt, locale),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      '${timeRange(session.startsAt, session.endsAt)} · ${session.courts.join(', ')}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(s.levelLabel(session.level), AppColors.skill(session.level ?? '')),
                        StatusPill(s.perPlayer(vnd(session.priceVnd)), AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((session.description ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(session.description!)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: session.capacity == 0 ? 0 : taken / session.capacity,
              minHeight: 8,
              backgroundColor: AppColors.mint,
              color: session.seatsLeft == 0 ? AppColors.rose : AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.seatsLeft == 0 ? s.full : s.seatsLeft(session.seatsLeft, session.capacity),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: session.seatsLeft == 0 ? AppColors.rose : AppColors.primaryDark,
            ),
          ),
          for (final ticket in mine)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_rounded, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s.yourPlaces(ticket.quantity)} · ${ticket.status == 'confirmed' ? s.ticketConfirmed : s.ticketPending}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ),
                  if (ticket.paymentToken != null)
                    TextButton(onPressed: () => _openPayment(ticket.paymentToken!), child: Text(s.payNow)),
                  if (ticket.canCancel)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.rose),
                      onPressed: () => _giveBack(ticket),
                      child: Text(s.givePlacesBack),
                    ),
                ],
              ),
            ),
          if (session.bookable && session.seatsLeft > 0) ...[
            const SizedBox(height: 12),
            GradientButton(label: s.joinSession, icon: Icons.sports_tennis_rounded, onPressed: () => _join(session)),
          ],
        ],
      ),
    );
  }
}
