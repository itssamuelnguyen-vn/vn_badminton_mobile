import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'payment_screen.dart';

/// The tournaments part of the "Giao lưu" tab (GD-01..09): coming, running and recent tournaments; a tap opens
/// the tournament's page.
class TournamentList extends StatefulWidget {
  const TournamentList({super.key});

  @override
  State<TournamentList> createState() => _TournamentListState();
}

class _TournamentListState extends State<TournamentList> {
  List<Tournament>? _tournaments;
  Object? _error;
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = AppScope.of(context).user?.id;
    if (_tournaments == null || userId != _userId) {
      _userId = userId;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/tournaments');
      if (mounted) setState(() => _tournaments = [for (final t in json['tournaments'] as List) Tournament.fromJson(t)]);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tournaments = _tournaments;
    if (tournaments == null) {
      return _error != null
          ? ErrorView(message: s.error(_error!), onRetry: _load)
          : const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (tournaments.isEmpty) EmptyState(icon: Icons.emoji_events_rounded, text: s.noTournaments),
          for (final tournament in tournaments) _card(s, tournament),
        ],
      ),
    );
  }

  Widget _card(S s, Tournament tournament) {
    final locale = AppScope.of(context).locale;
    return SoftCard(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentScreen(id: tournament.id)));
        _load();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateTile(tournament.startsAt, locale),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  '${tournament.event} · ${s.formatLabel(tournament.playFormat)} · ${timeRange(tournament.startsAt, tournament.endsAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    tournamentStatusPill(s, tournament),
                    StatusPill(
                      tournament.feeVnd > 0 ? s.fee(vnd(tournament.feeVnd), tournament.doubles) : s.free,
                      AppColors.primary,
                    ),
                    if (tournament.myEntry != null) StatusPill(s.entered, AppColors.blue),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Where the tournament is: places left while registering, running, the champion, cancelled.
Widget tournamentStatusPill(S s, Tournament tournament) => switch (tournament.status) {
  'open' when tournament.registrationOpen && tournament.spotsLeft > 0 => StatusPill(
    s.spotsLeft(tournament.spotsLeft, tournament.maxEntries),
    AppColors.blue,
  ),
  'open' when tournament.registrationOpen => StatusPill(s.full, AppColors.rose),
  'open' => StatusPill(s.registrationClosed, AppColors.muted),
  'in_progress' => StatusPill(s.inProgress, AppColors.orange),
  'finished' => StatusPill(s.finishedLabel, AppColors.orange),
  _ => StatusPill(s.cancelledLabel, AppColors.rose),
};

/// One tournament: details, the customer's entry (pay, withdraw) or the form to enter, then the entries, the group
/// tables and the knockout bracket, and the champion once finished. Opened from the list or a push notification.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key, required this.id});

  final int id;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  Tournament? _tournament;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/tournaments/${widget.id}');
      if (mounted) setState(() => _tournament = Tournament.fromJson(json));
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

  Future<void> _enter(Tournament tournament) async {
    final s = S.of(context);
    if (!await ensureSignedIn(context) || !mounted) return;
    Map<String, String>? partner;
    if (tournament.doubles) {
      partner = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PartnerSheet(tournament: tournament),
      );
      if (partner == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final json = await AppScope.read(context).api
          .post('/tournaments/${tournament.id}/entries', {'partner': ?partner});
      if (!mounted) return;
      if (json['token'] != null) {
        final payment = Payment.fromJson(json);
        await _openPayment(payment.token, payment);
      } else {
        setState(() => _tournament = Tournament.fromJson(json));
        showMessage(context, s.enteredFree);
      }
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(TournamentEntry entry) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.withdrawEntry),
        content: Text(s.withdrawConfirm(entry.status == 'confirmed' && entry.amountVnd > 0)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.keep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.withdrawEntry),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final json = await AppScope.read(context).api.delete('/tournament_entries/${entry.id}');
      if (mounted) setState(() => _tournament = Tournament.fromJson(json));
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tournament = _tournament;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(title: tournament?.title ?? s.tabTournaments, subtitle: tournament?.event),
          Expanded(
            child: tournament == null
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: _content(s, tournament),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(S s, Tournament tournament) {
    final locale = AppScope.of(context).locale;
    final mine = tournament.myEntry;
    final knockout = tournament.matches.where((match) => match.stage == 'knockout').toList();
    return [
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                tournamentStatusPill(s, tournament),
                StatusPill(s.formatLabel(tournament.playFormat), AppColors.primaryDark),
                StatusPill(
                  tournament.feeVnd > 0 ? s.fee(vnd(tournament.feeVnd), tournament.doubles) : s.free,
                  AppColors.primary,
                ),
                StatusPill(s.levelLabel(tournament.level), AppColors.skill(tournament.level ?? '')),
              ],
            ),
            const SizedBox(height: 10),
            InfoRow(
              longDate(tournament.startsAt, locale),
              '${timeRange(tournament.startsAt, tournament.endsAt)} · ${tournament.courts.join(', ')}',
            ),
            if (tournament.status == 'open')
              Text(
                s.registrationCloses(
                  '${hhmm(tournament.registrationClosesAt)} ${longDate(tournament.registrationClosesAt, locale)}',
                ),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            if ((tournament.description ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(tournament.description!)),
          ],
        ),
      ),
      if (tournament.champion != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.champion,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      tournament.champion!,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (mine != null) _myEntry(s, mine),
      if (mine == null && tournament.registrationOpen && tournament.spotsLeft > 0) ...[
        if (tournament.byGender && !const ['male', 'female'].contains(AppScope.of(context).user?.gender))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.genderNeeded,
              style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600),
            ),
          ),
        GradientButton(
          label: s.enterTournament,
          icon: Icons.emoji_events_rounded,
          onPressed: _busy ? null : () => _enter(tournament),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(
            s.namesPublic,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
      if (tournament.matches.isEmpty) ...[
        SectionTitle(s.entriesTitle(tournament.entries.length)),
        if (tournament.entries.isEmpty) Text(s.noEntries, style: const TextStyle(color: AppColors.muted)),
        for (final entry in tournament.entries)
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
      if (tournament.groups.isNotEmpty) ...[
        SectionTitle(tournament.playFormat == 'round_robin' ? s.standingsTitle : s.groupStage),
        for (final group in tournament.groups) _group(s, tournament, group, mine?.id),
      ],
      if (knockout.isNotEmpty) ...[SectionTitle(s.bracket), _Bracket(matches: knockout, mineId: mine?.id)],
    ];
  }

  Widget _myEntry(S s, TournamentEntry entry) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        const Icon(Icons.confirmation_number_rounded, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.status == 'confirmed' ? s.entryConfirmed(entry.name) : s.entryPending(entry.name),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
          ),
        ),
        if (entry.paymentToken != null)
          TextButton(onPressed: () => _openPayment(entry.paymentToken!), child: Text(s.payNow)),
        if (entry.canCancel)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            onPressed: () => _withdraw(entry),
            child: Text(s.withdrawEntry),
          ),
      ],
    ),
  );

  Widget _group(S s, Tournament tournament, TournamentGroup group, int? mineId) {
    final matches = tournament.matches.where((match) => match.stage == 'group' && match.group == group.number);
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tournament.playFormat == 'round_robin' ? s.standingsTitle : s.groupLetter(group.letter),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(s.standingsHeader, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          for (final (index, row) in group.rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1}. ${row.entry.name}',
                      style: TextStyle(fontWeight: row.entry.id == mineId ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${row.played} · ${row.won} · ${row.gamesFor}-${row.gamesAgainst} · ${row.pointDifference > 0 ? '+' : ''}${row.pointDifference}',
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          for (final match in matches)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${match.a?.name ?? '…'} – ${match.b?.name ?? '…'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    match.walkover
                        ? s.walkoverLabel
                        : match.scores.isNotEmpty
                        ? match.scores.map((game) => '${game[0]}-${game[1]}').join(', ')
                        : (match.court != null ? s.onCourt(match.court!) : '—'),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The knockout bracket: one column per round, scrolled sideways; the winner highlighted.
class _Bracket extends StatelessWidget {
  const _Bracket({required this.matches, this.mineId});

  final List<TournamentMatch> matches;
  final int? mineId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final rounds = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      rounds.putIfAbsent(match.round, () => []).add(match);
    }
    final keys = rounds.keys.toList()..sort();
    final firstRound = rounds[keys.first]!.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: firstRound * 104.0 + 28,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final round in keys)
              SizedBox(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rounds[round]!.first.roundName.toUpperCase(),
                        style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final match in rounds[round]!..sort((x, y) => x.position.compareTo(y.position)))
                              _match(s, match),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _match(S s, TournamentMatch match) {
    final mine = mineId != null && (match.a?.id == mineId || match.b?.id == mineId);
    Widget side(TournamentSide? entry, int index) {
      final won = entry != null && entry.id == match.winnerId;
      return Container(
        color: won ? AppColors.mint : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry?.name ?? (match.bye ? s.byeLabel : '…'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: won ? FontWeight.w800 : FontWeight.w500, fontSize: 13),
              ),
            ),
            if (!match.walkover && match.scores.isNotEmpty)
              Text(match.scores.map((game) => game[index]).join(' '), style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mine ? AppColors.blue : const Color(0x1A0F172A), width: mine ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          side(match.a, 0),
          const Divider(height: 1),
          side(match.b, 1),
          if (match.walkover)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(s.walkoverLabel, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            )
          else if (!match.finished && match.court != null)
            Container(
              color: const Color(0xFFFFEDD5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(s.onCourt(match.court!), style: const TextStyle(color: AppColors.orange, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

/// The partner of a doubles entry: name, phone, and gender for gendered events.
class _PartnerSheet extends StatefulWidget {
  const _PartnerSheet({required this.tournament});

  final Tournament tournament;

  @override
  State<_PartnerSheet> createState() => _PartnerSheetState();
}

class _PartnerSheetState extends State<_PartnerSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String? required(String? value) => (value ?? '').trim().isEmpty ? s.required : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.partner, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: s.partnerName),
              textCapitalization: TextCapitalization.words,
              validator: required,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: s.partnerPhone, hintText: '0901 234 567'),
              keyboardType: TextInputType.phone,
              validator: required,
            ),
            if (widget.tournament.byGender) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: InputDecoration(labelText: s.partnerGender),
                items: [
                  for (final gender in const ['male', 'female'])
                    DropdownMenuItem(value: gender, child: Text(s.genderLabel(gender))),
                ],
                onChanged: (value) => setState(() => _gender = value),
                validator: required,
              ),
            ],
            const SizedBox(height: 6),
            Text(s.partnerHint, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 14),
            GradientButton(
              label: s.enterTournament,
              icon: Icons.emoji_events_rounded,
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'gender': ?_gender});
              },
            ),
          ],
        ),
      ),
    );
  }
}
