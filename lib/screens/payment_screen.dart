import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'home_shell.dart';

/// The transfer page: QR code and bank details, a countdown, and a check every few seconds that turns the
/// page into "Payment received" as soon as the server sees the money (SePay webhook).
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.token, this.initial});

  final String token;
  final Payment? initial;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Payment? _payment = widget.initial;
  Object? _error;
  Timer? _tick;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    if (_payment == null) _refresh();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final payment = Payment.fromJson(await AppScope.read(context).api.get('/payments/${widget.token}'));
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _error = null;
      });
      if (payment.status != 'awaiting') {
        _poll?.cancel();
        _tick?.cancel();
      }
    } catch (error) {
      // A missed check is retried by the next one; only shown when there is nothing else to show.
      if (mounted && _payment == null) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final payment = _payment;
    return Scaffold(
      appBar: AppBar(title: Text(s.paymentTitle)),
      body: payment == null
          ? (_error != null
              ? ErrorView(message: s.error(_error!), onRetry: _refresh)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                ...switch (payment.status) {
                  'paid' => _paid(s, payment),
                  'awaiting' => _awaiting(s, payment),
                  _ => [_notice(Icons.timer_off, payment.status == 'expired' ? s.paymentExpired : s.paymentCancelled)],
                },
                const SizedBox(height: 16),
                ..._bookings(payment),
              ]),
            ),
    );
  }

  List<Widget> _paid(S s, Payment payment) => [
        const SizedBox(height: 16),
        Icon(Icons.check_circle, size: 72, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(s.paid, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(s.paidText, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => HomeShell.showTab(context, 1), child: Text(s.seeMyBookings)),
      ];

  List<Widget> _awaiting(S s, Payment payment) {
    final left = payment.expiresAt?.difference(DateTime.now());
    return [
      if (left != null)
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(s.payWithin(countdown(left)), style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      if (payment.receivedVnd > 0 && payment.remainingVnd > 0)
        _notice(Icons.info_outline, s.partlyReceived(vnd(payment.receivedVnd), vnd(payment.remainingVnd))),
      const SizedBox(height: 8),
      Text(s.scanQr, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      if (payment.qrImageUrl != null)
        Center(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Image.network(
              payment.qrImageUrl!,
              width: 260,
              height: 260,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const SizedBox(width: 260, height: 260, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (context, _, _) => SizedBox(width: 260, height: 120, child: Center(child: Text(s.qrUnavailable))),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Text(s.orTransferManually, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      CopyRow(label: s.bank, value: payment.bank.code),
      CopyRow(label: s.accountNumber, value: payment.bank.accountNumber),
      CopyRow(label: s.accountName, value: payment.bank.accountName),
      CopyRow(label: s.amount, value: vnd(payment.remainingVnd), copyText: '${payment.remainingVnd}', emphasis: true),
      CopyRow(label: s.transferContent, value: payment.code, emphasis: true),
      const SizedBox(height: 4),
      Text(s.exactContent, style: TextStyle(color: Theme.of(context).hintColor)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(s.waitingForMoney),
      ]),
    ];
  }

  List<Widget> _bookings(Payment payment) {
    final locale = AppScope.of(context).locale;
    return [
      for (final booking in payment.bookings)
        Card(
          child: ListTile(
            leading: const Icon(Icons.sports_tennis),
            title: Text('${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}'),
            subtitle: Text('${longDate(booking.startsAt, locale)} · ${booking.code}'),
            trailing: Text(vnd(booking.amountVnd)),
          ),
        ),
    ];
  }

  Widget _notice(IconData icon, String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(text))]),
        ),
      );
}
