import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
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
  static const _gap = 4.0;
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
      final json = await AppScope.read(context).api
          .get('/schedule', query: {if ((date ?? _date) != null) 'date': (date ?? _date)!});
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
        MaterialPageRoute(
          builder: (_) => ConfirmScreen(hold: hold as Map<String, dynamic>, slots: slots),
        ),
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
    final user = state.user;
    final firstName = user?.fullName.trim().split(RegExp(r'\s+')).last ?? '';

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: firstName.isEmpty ? (state.venue?.name ?? 'VN Badminton') : s.hello(firstName),
            subtitle: s.readyToPlay,
            bottomPadding: 18,
            actions: [
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: () => _load(keepPicked: true),
                    ),
            ],
            child: day == null ? null : _dates(day, state.locale),
          ),
          Expanded(
            child: day == null
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : Column(
                    children: [
                      _legend(s),
                      Expanded(child: day.times.isEmpty ? Center(child: Text(s.noSlots)) : _grid(day)),
                      if (_picked.isNotEmpty) _summary(s, state),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dates(ScheduleDay day, String locale) => SizedBox(
    height: 70,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 12),
      itemCount: day.dates.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final date = day.dates[i];
        final selected = date == day.date;
        final color = selected ? AppColors.primaryDark : Colors.white;
        return GestureDetector(
          onTap: () => _load(date: date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayShort(date, locale),
                  style: TextStyle(
                    color: color.withValues(alpha: selected ? 1 : 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayOfMonth(date),
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _legend(S s) {
    Widget item(Color color, String label, {Gradient? gradient, Color? border}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            border: border == null ? null : Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(Colors.white, s.legendFree, border: AppColors.line),
          item(AppColors.primary, s.legendPicked, gradient: AppColors.brandGradient),
          item(_mine, s.legendMine),
          item(_held, s.legendHeld),
          item(_taken, s.legendTaken),
        ],
      ),
    );
  }

  static const _mine = Color(0xFFE0E7FF);
  static const _held = Color(0xFFFEF3C7);
  static const _taken = Color(0xFFE6ECE9);

  Widget _grid(ScheduleDay day) {
    final header = Row(
      children: [
        const SizedBox(width: _timeWidth),
        Expanded(
          child: SingleChildScrollView(
            controller: _headerScroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                for (final court in day.courts)
                  Container(
                    width: _cellWidth,
                    height: 30,
                    margin: const EdgeInsets.all(_gap / 2),
                    decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(
                      court.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryDark),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    final body = RefreshIndicator(
      onRefresh: () => _load(keepPicked: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                for (final time in day.times)
                  SizedBox(
                    width: _timeWidth,
                    height: _cellHeight + _gap,
                    child: Center(
                      child: Text(
                        hhmm(time),
                        style: venueTime(time).minute == 0
                            ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)
                            : const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _bodyScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    for (final court in day.courts)
                      Column(
                        children: [
                          for (final (i, slot) in (day.slots[court.id] ?? const <Slot>[]).indexed)
                            _cell(court.id, i, slot),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }

  Widget _cell(int courtId, int index, Slot slot) {
    final picked = _picked[courtId]?.contains(index) ?? false;
    final Widget? content = picked
        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
        : switch (slot.state) {
            'available' => Text(
              shortVnd(slot.priceVnd),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
            ),
            'mine' => const Icon(Icons.person_rounded, color: AppColors.indigo, size: 18),
            'held' => const Icon(Icons.hourglass_bottom_rounded, color: AppColors.amber, size: 16),
            _ => null,
          };
    final color = switch (slot.state) {
      _ when picked => null,
      'available' => Colors.white,
      'mine' => _mine,
      'held' => _held,
      _ => _taken,
    };

    return GestureDetector(
      onTap: slot.available ? () => _tap(courtId, index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _cellWidth,
        height: _cellHeight,
        margin: const EdgeInsets.all(_gap / 2),
        decoration: BoxDecoration(
          color: color,
          gradient: picked ? AppColors.brandGradient : null,
          border: slot.state == 'available' && !picked ? Border.all(color: AppColors.line) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: picked
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: content,
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

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.pickedSummary(_picked.length, s.hours(minutes)),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      Text(
                        vnd(total),
                        style: const TextStyle(color: AppColors.lime, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: () => setState(_picked.clear),
                  child: Text(s.clear),
                ),
              ],
            ),
            if (tooShort)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s.minDuration(s.hours(minMinutes)), style: const TextStyle(color: Color(0xFFFCA5A5))),
              ),
            const SizedBox(height: 12),
            GradientButton(
              label: s.continueLabel,
              icon: Icons.arrow_forward_rounded,
              gradient: AppColors.limeGradient,
              foreground: AppColors.ink,
              busy: _continuing,
              onPressed: tooShort ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }
}
