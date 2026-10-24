import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screens.dart';

/// The tournaments part of the "Giao lưu" tab (GD-01..07): the customer's own tournaments, the ones they created
/// or help organize, and the button to create one. Tournaments are a tool for their group; the venue takes no part.
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
      _tournaments = null;
      _error = null;
      if (userId != null) _load();
    }
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/tournaments');
      if (mounted) {
        setState(() {
          _tournaments = [for (final t in json['tournaments'] as List) Tournament.fromJson(t)];
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context)
        .push<Tournament>(MaterialPageRoute(builder: (_) => const TournamentFormScreen()));
    if (created == null || !mounted) return;
    _open(TournamentScreen(token: created.token, initial: created));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!AppScope.of(context).signedIn) {
      return Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.emoji_events_rounded,
            text: s.signInToSeeTournaments,
            action: SizedBox(
              width: 220,
              child: GradientButton(label: s.signIn, onPressed: () => ensureSignedIn(context)),
            ),
          ),
        ),
      );
    }
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
          GradientButton(label: s.newTournament, icon: Icons.add_rounded, onPressed: _create),
          const SizedBox(height: 12),
          if (tournaments.isEmpty) EmptyState(icon: Icons.emoji_events_rounded, text: s.noTournaments),
          for (final tournament in tournaments) _card(s, tournament),
        ],
      ),
    );
  }

  Widget _card(S s, Tournament tournament) {
    final locale = AppScope.of(context).locale;
    final day = tournament.day;
    return SoftCard(
      onTap: () => _open(TournamentScreen(token: tournament.token)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          day != null ? DateTile(day, locale) : const IconBadge(Icons.emoji_events_rounded, AppColors.orange, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  '${tournament.event} · ${s.formatLabel(tournament.playFormat)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    tournamentStatusPill(s, tournament),
                    if (!tournament.creator) StatusPill(s.organizerOf(tournament.createdBy), AppColors.blue),
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

/// Getting ready, in progress, finished.
Widget tournamentStatusPill(S s, Tournament tournament) =>
    StatusPill(s.tournamentStatus(tournament.status), switch (tournament.status) {
      'in_progress' => AppColors.orange,
      'finished' => AppColors.primaryDark,
      _ => AppColors.blue,
    });

/// A yes/no question before an action that cannot be taken back; [title] is also the button's label.
Future<bool> _confirm(BuildContext context, String title, String text, {bool danger = false}) async {
  final s = S.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.rose) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(title),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Creating a tournament (GD-01) or editing it: name, description, event (while no player is typed), format (until
/// the draw), date. Closes with the tournament saved.
class TournamentFormScreen extends StatefulWidget {
  const TournamentFormScreen({super.key, this.tournament});

  final Tournament? tournament;

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.tournament?.title);
  late final _description = TextEditingController(text: widget.tournament?.description);
  late String _discipline = widget.tournament?.discipline ?? 'singles';
  late String _format = widget.tournament?.playFormat ?? 'knockout';
  late int _groupSize = widget.tournament?.groupSize ?? 4;
  late int _advance = widget.tournament?.advancePerGroup ?? 2;
  late String? _playedOn = widget.tournament?.playedOn;
  bool _busy = false;

  bool get _disciplineEditable => widget.tournament == null || widget.tournament!.entries.isEmpty;
  bool get _formatEditable => widget.tournament == null || widget.tournament!.setup;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _playedOn != null ? DateTime.parse(_playedOn!) : now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _playedOn = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final fields = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'played_on': _playedOn,
      if (_disciplineEditable) 'discipline': _discipline,
      if (_formatEditable) 'play_format': _format,
      if (_formatEditable && _format == 'groups_knockout') ...{'group_size': _groupSize, 'advance_per_group': _advance},
    };
    try {
      final api = AppScope.read(context).api;
      final existing = widget.tournament;
      final json = existing == null
          ? await api.post('/tournaments', {'tournament': fields})
          : await api.patch('/tournaments/${existing.token}', {'tournament': fields});
      if (mounted) Navigator.pop(context, Tournament.fromJson(json));
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final creating = widget.tournament == null;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(title: creating ? s.newTournament : s.editTournament, subtitle: widget.tournament?.title),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (creating)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(s.newTournamentExplain, style: const TextStyle(color: AppColors.muted)),
                    ),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _title,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(labelText: s.tournamentName, hintText: s.tournamentNameHint),
                          validator: (value) => (value ?? '').trim().isEmpty ? s.required : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _discipline,
                          decoration: InputDecoration(
                            labelText: s.eventTitle,
                            helperText: _disciplineEditable ? null : s.disciplineLocked,
                            helperMaxLines: 2,
                          ),
                          items: [
                            for (final discipline in const ['singles', 'doubles', 'mixed_doubles'])
                              DropdownMenuItem(value: discipline, child: Text(s.eventLabel(discipline))),
                          ],
                          onChanged: _disciplineEditable ? (value) => setState(() => _discipline = value!) : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _format,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.formatTitle,
                            helperText: _formatEditable ? s.formatHint(_format) : s.formatLocked,
                            helperMaxLines: 3,
                          ),
                          items: [
                            for (final format in const ['knockout', 'groups_knockout', 'round_robin'])
                              DropdownMenuItem(value: format, child: Text(s.formatLabel(format))),
                          ],
                          onChanged: _formatEditable ? (value) => setState(() => _format = value!) : null,
                        ),
                        if (_format == 'groups_knockout') ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _groupSize,
                                  isExpanded: true,
                                  decoration: InputDecoration(labelText: s.groupSize),
                                  items: [
                                    for (final size in const [3, 4, 5, 6])
                                      DropdownMenuItem(value: size, child: Text('$size')),
                                  ],
                                  onChanged: _formatEditable ? (value) => setState(() => _groupSize = value!) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _advance,
                                  isExpanded: true,
                                  decoration: InputDecoration(labelText: s.advancePerGroup),
                                  items: [
                                    for (final count in const [1, 2])
                                      DropdownMenuItem(value: count, child: Text('$count')),
                                  ],
                                  onChanged: _formatEditable ? (value) => setState(() => _advance = value!) : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(s.playedOn, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.event_rounded),
                                label: Text(_playedOn != null ? isoDateLabel(_playedOn!) : s.pickDate),
                                onPressed: _pickDate,
                              ),
                            ),
                            if (_playedOn != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                                onPressed: () => setState(() => _playedOn = null),
                              ),
                          ],
                        ),
                        Text(s.playedOnHint, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _description,
                          maxLength: 2000,
                          minLines: 3,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: s.tournamentDescription,
                            hintText: s.tournamentDescriptionHint,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: creating ? s.createTournament : s.save,
                    icon: creating ? Icons.emoji_events_rounded : Icons.check_rounded,
                    busy: _busy,
                    onPressed: _save,
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

/// One tournament's page (public, like its link): details, the champion, its courts and times, the players, the
/// group tables with their matches and the knockout bracket. Its creator sets it up (players, seeds, draw, courts,
/// organizer link); organizers call matches to a court and enter results. Every action answers the whole page.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key, required this.token, this.initial});

  final String token;

  /// The tournament just created or joined, shown without loading it again.
  final Tournament? initial;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late Tournament? _tournament = widget.initial;
  Object? _error;
  bool _busy = false;
  final _players = TextEditingController();

  String get _path => '/tournaments/${widget.token}';

  @override
  void initState() {
    super.initState();
    if (_tournament == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _players.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get(_path);
      if (mounted) setState(() => _tournament = Tournament.fromJson(json));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Sends one action; the answer is the whole tournament. Returns the error's text (shown as a message too,
  /// unless [quiet]), or null when done.
  Future<String?> _act(Future<dynamic> Function(Api api) request, {String? done, bool quiet = false}) async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final json = await request(AppScope.read(context).api);
      if (!mounted) return null;
      setState(() => _tournament = Tournament.fromJson(json));
      if (done != null) showMessage(context, done);
      return null;
    } catch (error) {
      if (mounted && !quiet) showMessage(context, s.error(error));
      return s.error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _share(String path, String subject) =>
      SharePlus.instance.share(ShareParams(text: serverUrl(path), subject: subject));

  Future<void> _edit(Tournament tournament) async {
    final saved = await Navigator.of(context)
        .push<Tournament>(MaterialPageRoute(builder: (_) => TournamentFormScreen(tournament: tournament)));
    if (saved != null && mounted) setState(() => _tournament = saved);
  }

  Future<void> _delete() async {
    final s = S.of(context);
    if (!await _confirm(context, s.deleteTournament, s.deleteTournamentConfirm, danger: true) || !mounted) return;
    try {
      await AppScope.read(context).api.delete(_path);
      if (!mounted) return;
      showMessage(context, s.tournamentDeleted);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  Future<void> _addPlayers() async {
    final list = _players.text.trim();
    if (list.isEmpty) return;
    final error = await _act((api) => api.post('$_path/entries', {'list': list}));
    if (error == null) _players.clear();
  }

  Future<void> _editPlayer(Tournament tournament, TournamentEntry entry) async {
    final s = S.of(context);
    final name = TextEditingController(text: entry.name);
    final partner = TextEditingController(text: entry.partnerName);
    final seed = TextEditingController(text: entry.seed?.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.displayName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: s.playerName),
              ),
              if (tournament.doubles)
                TextField(
                  controller: partner,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: s.partnerName),
                ),
              TextField(
                controller: seed,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.seed),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.save)),
        ],
      ),
    );
    final fields = {
      'name': name.text.trim(),
      if (tournament.doubles) 'partner_name': partner.text.trim(),
      'seed': int.tryParse(seed.text.trim()),
    };
    name.dispose();
    partner.dispose();
    seed.dispose();
    if (ok != true || !mounted) return;
    _act((api) => api.patch('$_path/entries/${entry.id}', {'entry': fields}));
  }

  Future<void> _removePlayer(TournamentEntry entry) async {
    final s = S.of(context);
    if (!await _confirm(context, s.removePlayer, s.removePlayerConfirm(entry.displayName), danger: true) || !mounted) {
      return;
    }
    _act((api) => api.delete('$_path/entries/${entry.id}'));
  }

  Future<void> _draw() async {
    final s = S.of(context);
    if (!await _confirm(context, s.makeDraw, s.drawConfirm) || !mounted) return;
    _act((api) => api.post('$_path/draw'));
  }

  Future<void> _drawAgain() async {
    final s = S.of(context);
    if (!await _confirm(context, s.drawAgain, s.drawAgainConfirm, danger: true) || !mounted) return;
    _act((api) => api.delete('$_path/draw'));
  }

  /// The creator's own bookings, ticked when linked to the tournament (GD-05).
  Future<void> _linkBookings(Tournament tournament) async {
    final s = S.of(context);
    final picked = {for (final booking in tournament.linkableBookings) booking.id: booking.linked};
    final ids = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final locale = AppScope.of(context).locale;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.linkBookings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(s.linkBookingsHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final booking in tournament.linkableBookings)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: picked[booking.id],
                            title: Text('${booking.court} · ${timeRange(booking.startsAt, booking.endsAt)}'),
                            subtitle: Text(longDate(booking.startsAt, locale)),
                            onChanged: (value) => setSheetState(() => picked[booking.id] = value == true),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: s.saveCourts,
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(context, [
                      for (final entry in picked.entries)
                        if (entry.value) entry.key,
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ids == null || !mounted) return;
    _act((api) => api.patch('$_path/bookings', {'booking_ids': ids}));
  }

  Future<void> _newOrganizerLink() async {
    final s = S.of(context);
    if (!await _confirm(context, s.newLink, s.newLinkConfirm) || !mounted) return;
    _act((api) => api.patch('$_path/organizer_link'), done: s.newLinkDone);
  }

  Future<void> _removeOrganizer(TournamentOrganizer organizer) async {
    final s = S.of(context);
    if (!await _confirm(context, s.removeScoreKeeper, s.removeScoreKeeperConfirm(organizer.name), danger: true) ||
        !mounted) {
      return;
    }
    _act((api) => api.delete('$_path/organizers', {'user_id': organizer.userId}));
  }

  /// An organizer's sheet for one match: its court, each game's score, or a walkover (GD-05..06).
  void _openMatch(Tournament tournament, TournamentMatch match) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MatchSheet(
        match: match,
        courts: tournament.courts,
        onCall: (courtId) =>
            _act((api) => api.patch('$_path/matches/${match.id}/call', {'court_id': courtId}), quiet: true),
        onResult: (body) => _act((api) => api.patch('$_path/matches/${match.id}', body), quiet: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tournament = _tournament;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: tournament?.title ?? s.tabTournaments,
            subtitle: tournament == null ? null : '${tournament.event} · ${s.formatLabel(tournament.playFormat)}',
            actions: [
              if (tournament != null)
                IconButton(
                  tooltip: s.shareTournament,
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () => _share(tournament.sharePath, tournament.title),
                ),
              if (tournament != null && tournament.creator)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onSelected: (action) => action == 'edit' ? _edit(tournament) : _delete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(s.edit)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(s.deleteTournament, style: const TextStyle(color: AppColors.rose)),
                    ),
                  ],
                ),
            ],
          ),
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
    final knockout = tournament.matches.where((match) => match.stage == 'knockout').toList();
    final day = tournament.day;
    final void Function(TournamentMatch)? onMatch = tournament.organizer
        ? (match) => _openMatch(tournament, match)
        : null;
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
                StatusPill(tournament.event, AppColors.primary),
                StatusPill(s.formatLabel(tournament.playFormat), AppColors.primaryDark),
              ],
            ),
            const SizedBox(height: 10),
            if (day != null) InfoRow(s.playedOn, longDate(day, locale)),
            Text(s.organizedBy(tournament.createdBy), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if ((tournament.description ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(tournament.description!)),
          ],
        ),
      ),
      if (tournament.champion != null) _champion(s, tournament.champion!),
      ..._courts(s, tournament),
      if (tournament.setup) ..._playerList(s, tournament),
      if (tournament.redrawable)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.shuffle_rounded),
            label: Text(s.drawAgain),
            onPressed: _busy ? null : _drawAgain,
          ),
        ),
      if (tournament.organizer && tournament.status == 'in_progress')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(s.resultsHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      if (tournament.groups.isNotEmpty) ...[
        SectionTitle(tournament.playFormat == 'round_robin' ? s.standingsTitle : s.groupStage),
        for (final group in tournament.groups) _group(s, tournament, group, onMatch),
      ],
      if (knockout.isNotEmpty) ...[SectionTitle(s.bracket), _Bracket(matches: knockout, onTap: onMatch)],
      if (tournament.creator) ..._organizers(s, tournament),
    ];
  }

  Widget _champion(S s, String name) => Container(
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
                name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// The linked bookings (courts and times); the creator picks them among their own.
  List<Widget> _courts(S s, Tournament tournament) {
    if (tournament.bookings.isEmpty && !tournament.creator) return const [];
    final locale = AppScope.of(context).locale;
    return [
      SectionTitle(s.tournamentCourts),
      for (final booking in tournament.bookings)
        SoftCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DateTile(booking.startsAt, locale),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${booking.court} · ${timeRange(booking.startsAt, booking.endsAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      if (tournament.creator && tournament.linkableBookings.isNotEmpty)
        OutlinedButton.icon(
          icon: const Icon(Icons.event_available_rounded),
          label: Text(s.linkBookings),
          onPressed: _busy ? null : () => _linkBookings(tournament),
        )
      else if (tournament.creator && tournament.bookings.isEmpty)
        Text(s.noLinkableBookings, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
    ];
  }

  /// Before the draw: the players; the creator adds them (one per line), edits, removes, then makes the draw.
  List<Widget> _playerList(S s, Tournament tournament) {
    final creator = tournament.creator;
    return [
      SectionTitle(s.playersTitle(tournament.entries.length)),
      if (creator)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(s.playersHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      if (tournament.entries.isEmpty) Text(s.noPlayers, style: const TextStyle(color: AppColors.muted)),
      for (final entry in tournament.entries)
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          onTap: creator ? () => _editPlayer(tournament, entry) : null,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(entry.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              if (entry.seed != null) StatusPill(s.seeded(entry.seed!), AppColors.orange),
              if (creator)
                IconButton(
                  tooltip: s.removePlayer,
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  onPressed: _busy ? null : () => _removePlayer(entry),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      if (creator) ...[
        SectionTitle(s.addPlayers),
        TextField(
          controller: _players,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: s.addPlayersPlaceholder(tournament.doubles),
            helperText: s.addPlayersHint(tournament.doubles),
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(s.addToList),
          onPressed: _busy ? null : _addPlayers,
        ),
        if (tournament.entries.isNotEmpty) ...[
          const SizedBox(height: 16),
          GradientButton(label: s.makeDraw, icon: Icons.shuffle_rounded, onPressed: _busy ? null : _draw),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              s.drawHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ],
    ];
  }

  /// The creator's organizer link (GD-02): send it, make a new one, the friends who joined.
  List<Widget> _organizers(S s, Tournament tournament) => [
    SectionTitle(s.scoreKeepers),
    SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.scoreKeepersHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 10),
          if (tournament.organizerPath != null)
            FilledButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: Text(s.sendScoreKeeperLink),
              onPressed: () => _share(tournament.organizerPath!, tournament.title),
            ),
          TextButton(onPressed: _busy ? null : _newOrganizerLink, child: Text(s.newLink)),
          const Divider(),
          if (tournament.organizers.isEmpty) Text(s.noScoreKeepers, style: const TextStyle(color: AppColors.muted)),
          for (final organizer in tournament.organizers)
            Row(
              children: [
                const Icon(Icons.person_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(organizer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.rose),
                  onPressed: _busy ? null : () => _removeOrganizer(organizer),
                  child: Text(s.removeScoreKeeper),
                ),
              ],
            ),
        ],
      ),
    ),
  ];

  Widget _group(S s, Tournament tournament, TournamentGroup group, void Function(TournamentMatch)? onMatch) {
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
                  Expanded(child: Text('${index + 1}. ${row.entry.name}')),
                  Text(
                    '${row.played} · ${row.won} · ${row.gamesFor}-${row.gamesAgainst} · ${row.pointDifference > 0 ? '+' : ''}${row.pointDifference}',
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          for (final match in matches)
            InkWell(
              onTap: onMatch != null && match.editable ? () => onMatch(match) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${match.a?.name ?? '…'} – ${match.b?.name ?? '…'}',
                        style: TextStyle(fontSize: 13, fontWeight: match.finished ? FontWeight.w400 : FontWeight.w600),
                      ),
                    ),
                    Text(
                      match.walkover
                          ? s.walkoverLabel
                          : match.scores.isNotEmpty
                          ? match.scores.map((game) => '${game[0]}-${game[1]}').join(', ')
                          : (match.court != null ? s.onCourt(match.court!) : '—'),
                      style: TextStyle(
                        color: match.court != null && !match.finished ? AppColors.orange : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (onMatch != null && match.editable)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
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

/// The knockout bracket: one column per round, scrolled sideways; the winner highlighted. Organizers tap a match
/// they may edit ([onTap]).
class _Bracket extends StatelessWidget {
  const _Bracket({required this.matches, this.onTap});

  final List<TournamentMatch> matches;
  final void Function(TournamentMatch)? onTap;

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
    final editable = onTap != null && match.editable;
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

    return GestureDetector(
      onTap: editable ? () => onTap!(match) : null,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: editable ? AppColors.primary : const Color(0x1A0F172A), width: editable ? 1.5 : 1),
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
      ),
    );
  }
}

/// One match, for an organizer: the court it is played on (when bookings are linked), the score of up to three
/// games, or a walkover. [onCall] and [onResult] answer the error's text, or null when saved.
class _MatchSheet extends StatefulWidget {
  const _MatchSheet({required this.match, required this.courts, required this.onCall, required this.onResult});

  final TournamentMatch match;
  final List<TournamentCourt> courts;
  final Future<String?> Function(int? courtId) onCall;
  final Future<String?> Function(Map<String, dynamic> body) onResult;

  @override
  State<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<_MatchSheet> {
  static const _games = 3;
  late final _points = [
    for (var game = 0; game < _games; game++)
      [
        for (var side = 0; side < 2; side++)
          TextEditingController(text: game < widget.match.scores.length ? '${widget.match.scores[game][side]}' : ''),
      ],
  ];
  late int? _courtId = widget.match.courtId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final game in _points) {
      for (final controller in game) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _send(Future<String?> Function() request, {bool close = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await request();
    if (!mounted) return;
    if (error == null && close) return Navigator.pop(context);
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _saveScores() {
    final scores = <List<int>>[];
    for (final game in _points) {
      final a = int.tryParse(game[0].text.trim());
      final b = int.tryParse(game[1].text.trim());
      if (a != null && b != null) scores.add([a, b]);
    }
    if (scores.isEmpty) return setState(() => _error = S.of(context).scoresNeeded);
    _send(() => widget.onResult({'scores': scores}));
  }

  Future<void> _walkover(String side, String name) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.walkoverConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.confirm)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _send(() => widget.onResult({'walkover': side}));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final match = widget.match;
    final a = match.a?.name ?? '…';
    final b = match.b?.name ?? '…';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                match.finished ? s.correctResult : s.enterResult,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text('${match.roundName} · $a – $b', style: const TextStyle(color: AppColors.muted)),
              if (match.ready && widget.courts.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _courtId,
                  decoration: InputDecoration(labelText: s.courtLabel),
                  items: [
                    DropdownMenuItem<int?>(child: Text(s.noCourt)),
                    for (final court in widget.courts) DropdownMenuItem<int?>(value: court.id, child: Text(court.name)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _courtId = value);
                          _send(() => widget.onCall(value), close: false);
                        },
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 64),
                  Expanded(
                    child: Text(a, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(b, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              for (final (index, game) in _points.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 64, child: Text(s.gameNumber(index + 1))),
                      Expanded(child: _pointsField(game[0])),
                      const SizedBox(width: 16, child: Text('–', textAlign: TextAlign.center)),
                      Expanded(child: _pointsField(game[1])),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              GradientButton(label: s.saveResult, icon: Icons.check_rounded, busy: _busy, onPressed: _saveScores),
              const SizedBox(height: 10),
              Text(
                s.orWalkover,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _walkover('a', a),
                      child: Text(s.walkoverFor(a), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _walkover('b', b),
                      child: Text(s.walkoverFor(b), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointsField(TextEditingController controller) => TextField(
    controller: controller,
    textAlign: TextAlign.center,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(isDense: true),
  );
}

/// The organizer link opened in the app (GD-02): who invites, and accepting to enter results. The customer is
/// signed in (HomeShell asks first).
class OrganizeTournamentScreen extends StatefulWidget {
  const OrganizeTournamentScreen({super.key, required this.token, required this.organizerToken});

  final String token;
  final String organizerToken;

  @override
  State<OrganizeTournamentScreen> createState() => _OrganizeTournamentScreenState();
}

class _OrganizeTournamentScreenState extends State<OrganizeTournamentScreen> {
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
      final json = await AppScope.read(context).api.get('/tournaments/${widget.token}');
      if (mounted) setState(() => _tournament = Tournament.fromJson(json));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _open(Tournament tournament) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => TournamentScreen(token: tournament.token, initial: tournament),
    ),
  );

  Future<void> _accept() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final json = await AppScope.read(context).api
          .post('/tournaments/${widget.token}/organize', {'organizer_token': widget.organizerToken});
      if (!mounted) return;
      showMessage(context, s.joinedScoreKeeper);
      _open(Tournament.fromJson(json));
    } catch (error) {
      if (mounted) {
        showMessage(context, s.error(error));
        setState(() => _busy = false);
      }
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
                : Center(
                    child: SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.scoreboard_rounded,
                        text: tournament.organizer ? s.alreadyScoreKeeper : s.scoreKeeperInvite(tournament.createdBy),
                        action: SizedBox(
                          width: double.infinity,
                          child: tournament.organizer
                              ? GradientButton(label: s.openTournament, onPressed: () => _open(tournament))
                              : GradientButton(
                                  label: s.acceptScoreKeeper,
                                  icon: Icons.check_rounded,
                                  busy: _busy,
                                  onPressed: _accept,
                                ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
