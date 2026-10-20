import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(booking.code)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              InfoRow(s.bookingCode, booking.code),
              InfoRow(s.court, booking.court.name),
              InfoRow(s.date, longDate(booking.startsAt, state.locale)),
              InfoRow(s.time, timeRange(booking.startsAt, booking.endsAt)),
              InfoRow(s.amount, vnd(booking.amountVnd)),
              InfoRow(s.status, s.bookingStatus(booking.status)),
              InfoRow(s.payment, [
                s.paymentStatus(booking.paymentStatus),
                if ((booking.refundVnd ?? 0) > 0) s.refunded(vnd(booking.refundVnd!)),
              ].join(' · ')),
              if (booking.series) InfoRow('', s.regular),
              if ((booking.note ?? '').isNotEmpty) InfoRow(s.note, booking.note!),
              if ((booking.cancellationReason ?? '').isNotEmpty) InfoRow('', booking.cancellationReason!),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (booking.paymentToken != null)
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: Text(s.payNow),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PaymentScreen(token: booking.paymentToken!)),
            ),
          ),
        if (booking.canCancel) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: Text(s.cancelBooking),
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: _busy ? null : _cancel,
          ),
          if (cutoff > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.cancelCutoff(cutoff), style: TextStyle(color: Theme.of(context).hintColor)),
            ),
        ],
      ]),
    );
  }
}
