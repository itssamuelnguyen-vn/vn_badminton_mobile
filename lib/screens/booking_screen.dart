import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment_screen.dart';
import 'schedule_screen.dart';

/// One booking, with "Cancel" and "Change time" while the venue's rules allow them (the server decides:
/// can_cancel, can_reschedule), adding it to the phone's calendar, sharing it with the group (with each
/// player's share), and rating it once played (TI-03).
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Booking _booking = widget.booking;
  bool _busy = false;

  Future<void> _reload() async {
    try {
      final json = await AppScope.read(context).api.get('/bookings/${_booking.code}');
      if (mounted) setState(() => _booking = Booking.fromJson(json));
    } catch (_) {}
  }

  Future<void> _reschedule() async {
    final moved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ScheduleScreen(rescheduling: _booking)));
    if (moved == true) _reload();
  }

  /// Google Calendar's "new event" page, filled in (opens the Calendar app when installed).
  void _addToCalendar() {
    final venue = AppScope.read(context).venue;
    String utc(DateTime time) => '${time.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Cầu lông · ${_booking.court.name}',
      'dates': '${utc(_booking.startsAt)}/${utc(_booking.endsAt)}',
      'details': '${venue?.name ?? 'VN Badminton'} · ${_booking.code}',
      'location': venue?.address ?? '',
    });
    openLink(uri.toString());
  }

  Future<void> _share() async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final booking = _booking;
    final players = await showDialog<int>(
      context: context,
      builder: (context) {
        var count = 4;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(s.splitTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.players, style: const TextStyle(color: AppColors.muted)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: count > 1 ? () => setDialogState(() => count--) : null,
                    ),
                    Text('$count', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                      onPressed: count < 20 ? () => setDialogState(() => count++) : null,
                    ),
                  ],
                ),
                Text(
                  s.perPerson(vnd(((booking.totalVnd / count) / 1000).ceil() * 1000)),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, 1), child: Text(s.share)),
              FilledButton(onPressed: () => Navigator.pop(context, count), child: Text(s.splitTitle)),
            ],
          ),
        );
      },
    );
    if (players == null || !mounted) return;
    final venue = state.venue;
    final text = s.shareText(
      court: booking.court.name,
      date: longDate(booking.startsAt, state.locale),
      time: timeRange(booking.startsAt, booking.endsAt),
      venue: venue?.name ?? 'VN Badminton',
      address: venue?.address ?? '',
      total: vnd(booking.totalVnd),
      // Rounded up to the thousand, as people pay each other.
      split: players > 1 ? vnd(((booking.totalVnd / players) / 1000).ceil() * 1000) : null,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Shows the booking to one of the customer's groups, with how many players split it (NH-02).
  Future<void> _shareToGroup() async {
    final s = S.of(context);
    final api = AppScope.read(context).api;
    final List<Group> groups;
    try {
      final json = await api.get('/groups');
      groups = [for (final g in json['groups'] as List) Group.fromJson(g)];
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
      return;
    }
    if (!mounted) return;
    if (groups.isEmpty) return showMessage(context, s.noGroups);

    final picked = await showModalBottomSheet<(Group, int)>(
      context: context,
      builder: (context) {
        var group = groups.first;
        var players = group.members.length;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.shareToGroup, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final g in groups)
                        ChoiceChip(
                          label: Text(g.name),
                          selected: g.id == group.id,
                          onSelected: (_) => setSheetState(() {
                            group = g;
                            players = g.members.length;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.players, style: const TextStyle(color: AppColors.muted)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: players > 1 ? () => setSheetState(() => players--) : null,
                      ),
                      Text('$players', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                        onPressed: players < 50 ? () => setSheetState(() => players++) : null,
                      ),
                    ],
                  ),
                  Text(
                    s.perPerson(vnd(((_booking.totalVnd / players) / 1000).ceil() * 1000)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: s.share,
                    icon: Icons.groups_2_rounded,
                    onPressed: () => Navigator.pop(context, (group, players)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    try {
      await api.post('/groups/${picked.$1.id}/shares', {'booking_code': _booking.code, 'players': picked.$2});
      if (mounted) showMessage(context, s.sharedToGroup);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  Future<void> _rate() async {
    final s = S.of(context);
    final comment = TextEditingController();
    var rating = 5;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.rateSession, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      iconSize: 40,
                      icon: Icon(
                        star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.amber,
                      ),
                      onPressed: () => setSheetState(() => rating = star),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: comment,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(labelText: s.reviewComment),
              ),
              const SizedBox(height: 8),
              GradientButton(label: s.send, icon: Icons.send_rounded, onPressed: () => Navigator.pop(context, true)),
            ],
          ),
        ),
      ),
    );
    if (sent != true || !mounted) {
      comment.dispose();
      return;
    }
    try {
      final json = await AppScope.read(context).api
          .post('/bookings/${_booking.code}/review', {'rating': rating, 'comment': comment.text.trim()});
      if (!mounted) return;
      setState(() => _booking = Booking.fromJson(json));
      showMessage(context, s.thanksReview);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    } finally {
      comment.dispose();
    }
  }

  Future<void> _cancel() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.cancelBooking),
        content: Text([s.cancelConfirm, if (_booking.cancelWithoutRefund) s.cancelNoRefund].join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.keep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.cancelBooking),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final json = await AppScope.read(context).api.patch('/bookings/${_booking.code}/cancel');
      if (!mounted) return;
      setState(() => _booking = Booking.fromJson(json));
      showMessage(context, s.cancelled);
    } on ApiError catch (error) {
      if (mounted) showMessage(context, s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final booking = _booking;
    final cutoff = state.venue?.cancellationCutoffHours ?? 0;

    Widget pill(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: '${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}',
            subtitle: longDate(booking.startsAt, state.locale),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                pill(s.bookingStatus(booking.status)),
                pill(s.paymentStatus(booking.paymentStatus)),
                if (booking.series) pill(s.regular),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoftCard(
                  child: Column(
                    children: [
                      InfoRow(s.bookingCode, booking.code),
                      InfoRow(s.court, booking.court.name),
                      InfoRow(s.date, longDate(booking.startsAt, state.locale)),
                      InfoRow(s.time, timeRange(booking.startsAt, booking.endsAt)),
                      if (booking.items.isEmpty)
                        InfoRow(s.amount, vnd(booking.amountVnd))
                      else ...[
                        InfoRow(s.courtPrice, vnd(booking.amountVnd)),
                        for (final item in booking.items)
                          InfoRow('${item.name} × ${item.quantity}', vnd(item.unitPriceVnd * item.quantity)),
                        InfoRow(s.total, vnd(booking.totalVnd)),
                      ],
                      InfoRow(s.status, s.bookingStatus(booking.status)),
                      InfoRow(
                        s.payment,
                        [
                          s.paymentStatus(booking.paymentStatus),
                          if ((booking.refundVnd ?? 0) > 0) s.refunded(vnd(booking.refundVnd!)),
                        ].join(' · '),
                      ),
                      if ((booking.note ?? '').isNotEmpty) InfoRow(s.note, booking.note!),
                      if ((booking.cancellationReason ?? '').isNotEmpty) InfoRow('', booking.cancellationReason!),
                    ],
                  ),
                ),
                if (booking.review != null)
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.yourReview, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Row(
                          children: [
                            for (var star = 1; star <= 5; star++)
                              Icon(
                                star <= booking.review!.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.amber,
                              ),
                          ],
                        ),
                        if ((booking.review!.comment ?? '').isNotEmpty) Text(booking.review!.comment!),
                      ],
                    ),
                  ),
                if (booking.canReview)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GradientButton(
                      label: s.rateSession,
                      icon: Icons.star_rounded,
                      gradient: AppColors.payGradient,
                      onPressed: _rate,
                    ),
                  ),
                if (booking.status == 'confirmed' && booking.endsAt.isAfter(DateTime.now()))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event_rounded),
                            label: Text(s.addToCalendar),
                            onPressed: _addToCalendar,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.share_rounded),
                            label: Text(s.share),
                            onPressed: _share,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (booking.status == 'confirmed' && booking.endsAt.isAfter(DateTime.now()))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.groups_2_rounded),
                      label: Text(s.shareToGroup),
                      onPressed: _shareToGroup,
                    ),
                  ),
                if (booking.canReschedule)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GradientButton(
                      label: s.reschedule,
                      icon: Icons.edit_calendar_rounded,
                      onPressed: _reschedule,
                    ),
                  ),
                const SizedBox(height: 16),
                if (booking.paymentToken != null)
                  GradientButton(
                    label: s.payNow,
                    icon: Icons.qr_code_2_rounded,
                    gradient: AppColors.payGradient,
                    onPressed: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => PaymentScreen(token: booking.paymentToken!))),
                  ),
                if (booking.canCancel) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(s.cancelBooking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: BorderSide(color: AppColors.rose.withValues(alpha: 0.4), width: 1.5),
                    ),
                    onPressed: _busy ? null : _cancel,
                  ),
                  if (cutoff > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        s.cancelCutoff(cutoff),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
