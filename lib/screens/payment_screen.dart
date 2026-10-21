import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
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
    final left = payment?.status == 'awaiting' ? payment!.expiresAt?.difference(DateTime.now()) : null;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: s.paymentTitle,
            child: left == null
                ? null
                : Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.payWithin(countdown(left)),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: payment == null
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _refresh)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...switch (payment.status) {
                          'paid' => _paid(s, payment),
                          'awaiting' => _awaiting(s, payment),
                          _ => [
                            _notice(
                              Icons.timer_off_rounded,
                              AppColors.rose,
                              payment.status == 'expired' ? s.paymentExpired : s.paymentCancelled,
                            ),
                          ],
                        },
                        const SizedBox(height: 8),
                        ..._bookings(payment),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _paid(S s, Payment payment) => [
    const SizedBox(height: 12),
    Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
      ),
    ),
    const SizedBox(height: 20),
    Text(
      s.paid,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 8),
    Text(
      s.paidText,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted),
    ),
    const SizedBox(height: 20),
    GradientButton(
      label: s.seeMyBookings,
      icon: Icons.event_note_rounded,
      onPressed: () => HomeShell.showTab(context, 1),
    ),
    const SizedBox(height: 12),
  ];

  List<Widget> _awaiting(S s, Payment payment) => [
    if (payment.discountVnd > 0)
      _notice(Icons.local_offer_rounded, AppColors.primary, s.savedAmount(vnd(payment.discountVnd))),
    if (payment.receivedVnd > 0 && payment.remainingVnd > 0)
      _notice(
        Icons.info_rounded,
        AppColors.blue,
        s.partlyReceived(vnd(payment.receivedVnd), vnd(payment.remainingVnd)),
      ),
    if (payment.qrImageUrl != null)
      SoftCard(
        child: Column(
          children: [
            Text(
              s.scanQr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                payment.qrImageUrl!,
                width: 260,
                height: 260,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(width: 260, height: 260, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (context, _, _) =>
                    SizedBox(width: 260, height: 120, child: Center(child: Text(s.qrUnavailable))),
              ),
            ),
          ],
        ),
      ),
    SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.orTransferManually, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          CopyRow(label: s.bank, value: payment.bank.code),
          CopyRow(label: s.accountNumber, value: payment.bank.accountNumber),
          CopyRow(label: s.accountName, value: payment.bank.accountName),
          CopyRow(
            label: s.amount,
            value: vnd(payment.remainingVnd),
            copyText: '${payment.remainingVnd}',
            emphasis: true,
          ),
          CopyRow(label: s.transferContent, value: payment.code, emphasis: true),
          const SizedBox(height: 4),
          Text(
            s.exactContent,
            style: const TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text(
          s.waitingForMoney,
          style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    ),
    const SizedBox(height: 8),
  ];

  List<Widget> _bookings(Payment payment) {
    final locale = AppScope.of(context).locale;
    return [
      for (final booking in payment.bookings)
        SoftCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DateTile(booking.startsAt, locale),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      '${longDate(booking.startsAt, locale)} · ${booking.code}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(vnd(booking.amountVnd), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
    ];
  }

  Widget _notice(IconData icon, Color color, String text) => SoftCard(
    child: Row(
      children: [
        IconBadge(icon, color),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
