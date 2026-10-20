import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment_screen.dart';

/// One booking, with "Cancel" while the venue's rules allow it (the server decides: can_cancel).
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Booking _booking = widget.booking;
  bool _busy = false;

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
                      InfoRow(s.amount, vnd(booking.amountVnd)),
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
