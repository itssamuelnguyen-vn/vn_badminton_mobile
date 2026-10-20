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
/// per court (several courts allowed), then continues to the confirmation. Tapping a taken cell offers to be
/// told when a court frees up (TI-04).
///
/// With [rescheduling], the grid picks the new time of that booking instead (one range on one court, its own
/// slots selectable again, DOI-05) and pops true once it was moved.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.rescheduling});

  final Booking? rescheduling;

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
  List<Announcement> _announcements = const [];

  Booking? get _rescheduling => widget.rescheduling;

  /// Picked cells: court id -> indexes in the day's times (always one unbroken range).
  final Map<int, Set<int>> _picked = {};

  @override
  void initState() {
    super.initState();
    _bodyScroll.addListener(() {
      if (_headerScroll.hasClients) _headerScroll.jumpTo(_bodyScroll.offset);
    });
    _load(date: _rescheduling == null ? null : venueDate(_rescheduling!.startsAt));
    if (_rescheduling == null) _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final json = await AppScope.read(context).api.get('/announcements');
      if (mounted) {
        setState(() => _announcements = [for (final a in json['announcements'] as List) Announcement.fromJson(a)]);
      }
    } catch (_) {
      // News are a nice-to-have: the schedule works without them.
    }
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
          .get(
            '/schedule',
            query: {
              if ((date ?? _date) != null) 'date': (date ?? _date)!,
              if (_rescheduling != null) 'reschedule': _rescheduling!.code,
            },
          );
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
      // A booking moves to one court only.
      if (_rescheduling != null) _picked.removeWhere((id, _) => id != courtId);
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

    if (_rescheduling != null) return _reviewReschedule();

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

  /// Shows the old and new times and the new price (checked by the server, nothing saved), then moves the booking.
  Future<void> _reviewReschedule() async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final booking = _rescheduling!;
    final slot = _slotsParam().single;
    setState(() => _continuing = true);
    try {
      final review = await state.api.get(
        '/bookings/${booking.code}/reschedule',
        query: {for (final e in slot.entries) e.key: '${e.value}'},
      );
      if (!mounted) return;
      final moved = Booking.fromJson(review['booking'] as Map<String, dynamic>);
      final valid = review['valid'] == true;
      final messages = [for (final m in review['messages'] as List) m.toString()];
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.reschedule),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(s.oldTime, '${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}\n${longDate(booking.startsAt, state.locale)}'),
              InfoRow(s.newTime, '${moved.court.name} · ${timeRange(moved.startsAt, moved.endsAt)}\n${longDate(moved.startsAt, state.locale)}'),
              InfoRow(s.newPrice, vnd(moved.amountVnd)),
              if (booking.paymentStatus == 'paid')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.keepPaidAmount, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
              if (!valid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(messages.join('\n'), style: const TextStyle(color: AppColors.rose)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
            if (valid) FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.confirm)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await state.api.patch('/bookings/${booking.code}/reschedule', slot);
      if (!mounted) return;
      showMessage(context, s.rescheduled);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  /// A taken cell: offers to wait for that time on any court (TI-04), for one to two hours from it.
  Future<void> _askWaitlist(int courtId, int index) async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final day = _day!;
    final start = day.slots[courtId]![index].startsAt;
    final last = day.times.last.add(const Duration(minutes: 30));
    final options = [
      for (final minutes in [60, 90, 120])
        if (!start.add(Duration(minutes: minutes)).isAfter(last)) minutes,
    ];
    if (options.isEmpty) options.add(last.difference(start).inMinutes);

    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.notifications_active_rounded, AppColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.notifyWhenFree, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.notifyRange('${hhmm(start)} · ${longDate(start, state.locale)}')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in options)
                    ActionChip(
                      label: Text('${hhmm(start)}–${hhmm(start.add(Duration(minutes: m)))} (${s.hours(m)})'),
                      onPressed: () => Navigator.pop(context, m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.notifyHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
    if (minutes == null || !mounted) return;
    if (!await ensureSignedIn(context) || !mounted) return;
    try {
      await state.api.post('/waitlist', {
        'starts_at': venueIso(start),
        'ends_at': venueIso(start.add(Duration(minutes: minutes))),
      });
      if (mounted) showMessage(context, s.notifySaved);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
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
            title: _rescheduling != null
                ? s.rescheduleTitle
                : firstName.isEmpty
                ? (state.venue?.name ?? 'VN Badminton')
                : s.hello(firstName),
            subtitle: _rescheduling != null
                ? '${_rescheduling!.court.name} · ${timeRange(_rescheduling!.startsAt, _rescheduling!.endsAt)}'
                : s.readyToPlay,
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
                      for (final announcement in _announcements) _announcement(announcement),
                      if (_rescheduling != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(s.rescheduleHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ),
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

  Widget _announcement(Announcement announcement) {
    final (color, icon) = switch (announcement.tone) {
      'offer' => (AppColors.primary, Icons.local_offer_rounded),
      'warning' => (AppColors.orange, Icons.campaign_rounded),
      _ => (AppColors.blue, Icons.info_rounded),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(announcement.title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                if ((announcement.body ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(announcement.body!, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      onTap: slot.available
          ? () => _tap(courtId, index)
          : (_rescheduling == null && (slot.state == 'booked' || slot.state == 'held'))
          ? () => _askWaitlist(courtId, index)
          : null,
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
              label: _rescheduling != null ? s.reschedule : s.continueLabel,
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
