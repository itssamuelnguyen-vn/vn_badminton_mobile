import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'confirm_screen.dart';

/// The booking grid of one day: courts across, times down. The customer taps free cells, one unbroken range
/// per court (several courts allowed), then continues to the confirmation.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _cellWidth = 64.0;
  static const _cellHeight = 44.0;
  static const _timeWidth = 52.0;

  final _headerScroll = ScrollController();
  final _bodyScroll = ScrollController();

  ScheduleDay? _day;
  String? _date;
  Object? _error;
  bool _loading = false;
  bool _continuing = false;
  int? _userId;

  /// Picked cells: court id -> indexes in the day's times (always one unbroken range).
  final Map<int, Set<int>> _picked = {};

  @override
  void initState() {
    super.initState();
    _bodyScroll.addListener(() {
      if (_headerScroll.hasClients) _headerScroll.jumpTo(_bodyScroll.offset);
    });
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Signing in or out changes which cells are "yours".
    final userId = AppScope.of(context).user?.id;
    if (userId != _userId) {
      _userId = userId;
      if (_day != null) _load();
    }
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  Future<void> _load({String? date, bool keepPicked = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await AppScope.read(context).api.get('/schedule', query: {if ((date ?? _date) != null) 'date': (date ?? _date)!});
      final day = ScheduleDay.fromJson(json);
      if (!mounted) return;
      setState(() {
        if (!keepPicked || day.date != _day?.date) _picked.clear();
        _day = day;
        _date = day.date;
        _dropTakenPicks();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// After a reload, cells someone else took meanwhile are no longer picked.
  void _dropTakenPicks() {
    final day = _day!;
    _picked.removeWhere((courtId, indexes) {
      final slots = day.slots[courtId] ?? const [];
      return indexes.any((i) => i >= slots.length || !slots[i].available);
    });
  }

  void _tap(int courtId, int index) {
    setState(() {
      final picked = _picked[courtId] ?? <int>{};
      if (picked.contains(index)) {
        // Unpicking keeps the range unbroken: everything after the tapped cell goes too.
        picked.removeWhere((i) => i >= index);
      } else if (picked.isEmpty ||
          index == picked.reduce((a, b) => a < b ? a : b) - 1 ||
          index == picked.reduce((a, b) => a > b ? a : b) + 1) {
        picked.add(index);
      } else {
        picked
          ..clear()
          ..add(index);
      }
      if (picked.isEmpty) {
        _picked.remove(courtId);
      } else {
        _picked[courtId] = picked;
      }
    });
  }

  /// The picked ranges as the API wants them.
  List<Map<String, dynamic>> _slotsParam() {
    final day = _day!;
    return [
      for (final entry in _picked.entries)
        () {
          final indexes = entry.value.toList()..sort();
          final slots = day.slots[entry.key]!;
          final start = slots[indexes.first];
          final end = slots[indexes.last].startsAt.add(const Duration(minutes: 30));
          return {'court_id': entry.key, 'starts_at': start.startsAtText, 'ends_at': venueIso(end)};
        }(),
    ];
  }

  Future<void> _continue() async {
    final state = AppScope.read(context);
    final s = S.of(context);
    if (!await ensureSignedIn(context) || !mounted) return;

    if (!state.user!.emailVerified) {
      try {
        await state.refreshUser();
      } catch (_) {}
      if (!mounted) return;
      if (!state.user!.emailVerified) return _askToVerify();
    }

    setState(() => _continuing = true);
    try {
      final slots = _slotsParam();
      final hold = await state.api.post('/hold', {'slots': slots});
      if (!mounted) return;
      final booked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ConfirmScreen(hold: hold as Map<String, dynamic>, slots: slots)),
      );
      if (booked == true) _picked.clear();
      if (mounted) _load(keepPicked: true);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
      if (error is ApiError && error.code == 'not_bookable') _load(keepPicked: true);
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  Future<void> _askToVerify() async {
    final s = S.of(context);
    final resend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.emailUnverified),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.close)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.resendVerification)),
        ],
      ),
    );
    if (resend != true || !mounted) return;
    try {
      await AppScope.read(context).api.post('/account/resend_verification');
      if (mounted) showMessage(context, s.resent);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final day = _day;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.venue?.name ?? 'VN Badminton'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : () => _load(keepPicked: true)),
        ],
        bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: day == null
          ? (_error != null
              ? ErrorView(message: s.error(_error!), onRetry: _load)
              : const Center(child: CircularProgressIndicator()))
          : Column(children: [
              _dates(day, state.locale),
              _legend(s),
              const Divider(height: 1),
              Expanded(child: day.times.isEmpty ? Center(child: Text(s.noSlots)) : _grid(day)),
              if (_picked.isNotEmpty) _summary(s, state),
            ]),
    );
  }

  Widget _dates(ScheduleDay day, String locale) => SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: [
            for (final date in day.dates)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(dayLabel(date, locale)),
                  selected: date == day.date,
                  showCheckmark: false,
                  onSelected: (_) => _load(date: date),
                ),
              ),
          ],
        ),
      );

  Widget _legend(S s) {
    Widget item(Color color, String label, {Color? border}) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: color, border: Border.all(color: border ?? color), borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        );
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(runSpacing: 4, children: [
        item(Colors.white, s.legendFree, border: Colors.grey.shade400),
        item(scheme.primary, s.legendPicked),
        item(Colors.blue.shade200, s.legendMine),
        item(Colors.amber.shade200, s.legendHeld),
        item(Colors.grey.shade300, s.legendTaken),
      ]),
    );
  }

  Widget _grid(ScheduleDay day) {
    final header = Row(children: [
      const SizedBox(width: _timeWidth),
      Expanded(
        child: SingleChildScrollView(
          controller: _headerScroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(children: [
            for (final court in day.courts)
              SizedBox(
                width: _cellWidth,
                height: 32,
                child: Center(child: Text(court.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              ),
          ]),
        ),
      ),
    ]);

    final body = RefreshIndicator(
      onRefresh: () => _load(keepPicked: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            for (final time in day.times)
              SizedBox(
                width: _timeWidth,
                height: _cellHeight,
                child: Center(child: Text(hhmm(time), style: const TextStyle(fontSize: 12))),
              ),
          ]),
          Expanded(
            child: SingleChildScrollView(
              controller: _bodyScroll,
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final court in day.courts)
                  Column(children: [
                    for (final (i, slot) in (day.slots[court.id] ?? const <Slot>[]).indexed) _cell(court.id, i, slot),
                  ]),
              ]),
            ),
          ),
        ]),
      ),
    );

    return Column(children: [header, Expanded(child: body)]);
  }

  Widget _cell(int courtId, int index, Slot slot) {
    final scheme = Theme.of(context).colorScheme;
    final picked = _picked[courtId]?.contains(index) ?? false;
    final (Color color, Color text) = picked
        ? (scheme.primary, Colors.white)
        : switch (slot.state) {
            'available' => (Colors.white, Colors.black87),
            'mine' => (Colors.blue.shade200, Colors.black87),
            'held' => (Colors.amber.shade200, Colors.black54),
            _ => (Colors.grey.shade300, Colors.black38),
          };

    return GestureDetector(
      onTap: slot.available ? () => _tap(courtId, index) : null,
      child: Container(
        width: _cellWidth,
        height: _cellHeight,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(color: color, border: Border.all(color: Colors.grey.shade300, width: 0.5)),
        alignment: Alignment.center,
        child: slot.available ? Text(shortVnd(slot.priceVnd), style: TextStyle(fontSize: 11, color: text)) : null,
      ),
    );
  }

  Widget _summary(S s, AppState state) {
    final day = _day!;
    var total = 0, minutes = 0, shortest = 1 << 30;
    for (final entry in _picked.entries) {
      final slots = day.slots[entry.key]!;
      for (final i in entry.value) {
        total += slots[i].priceVnd;
      }
      minutes += entry.value.length * 30;
      if (entry.value.length * 30 < shortest) shortest = entry.value.length * 30;
    }
    final minMinutes = state.venue?.minBookingMinutes ?? 0;
    final tooShort = shortest < minMinutes;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text('${s.pickedSummary(_picked.length, s.hours(minutes))} · ${vnd(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(onPressed: () => setState(_picked.clear), child: Text(s.clear)),
            ]),
            if (tooShort)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s.minDuration(s.hours(minMinutes)), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(
              onPressed: tooShort || _continuing ? null : _continue,
              child: _continuing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(s.continueLabel),
            ),
          ]),
        ),
      ),
    );
  }
}
