import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment_screen.dart';

/// The confirmation step: the picked slots are held for the customer for a few minutes (POST /hold). Going
/// back frees them; "Book" creates the bookings waiting for the transfer and opens the payment screen.
/// Pops true when booked.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.hold, required this.slots});

  final Map<String, dynamic> hold;
  final List<Map<String, dynamic>> slots;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final _note = TextEditingController();
  late final DateTime _heldUntil = DateTime.parse(widget.hold['held_until'] as String);
  late final List<Booking> _bookings = [for (final b in widget.hold['bookings'] as List) Booking.fromJson(b)];
  late final int _amount = (widget.hold['amount_vnd'] as num).toInt();
  late final Timer _timer;
  late final _api = AppScope.read(context).api;
  bool _busy = false;
  bool _booked = false;
  String? _error;

  Duration get _left => _heldUntil.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api; // Read now: the context can no longer be used in dispose.
  }

  @override
  void dispose() {
    _timer.cancel();
    _note.dispose();
    // Leaving without booking: free the slots at once for other customers.
    if (!_booked) _api.delete('/hold').catchError((_) => null);
    super.dispose();
  }

  Future<void> _book() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await _api.post('/bookings', {'slots': widget.slots, 'note': _note.text.trim()});
      _booked = true;
      if (!mounted) return;
      final payment = Payment.fromJson(json);
      final navigator = Navigator.of(context);
      navigator.pop(true);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(token: payment.token, initial: payment),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = S.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = AppScope.of(context).locale;
    final expired = _left.isNegative;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: s.confirmTitle,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: expired ? AppColors.rose : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(expired ? Icons.timer_off_rounded : Icons.timer_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expired ? s.holdExpired : s.heldFor(countdown(_left)),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final booking in _bookings)
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
                                longDate(booking.startsAt, locale),
                                style: const TextStyle(color: AppColors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Text(vnd(booking.amountVnd), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.total,
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        vnd(_amount),
                        style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800, fontSize: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _note,
                  decoration: InputDecoration(labelText: s.note, prefixIcon: const Icon(Icons.edit_note_rounded)),
                  maxLength: 500,
                  maxLines: 2,
                ),
                Text(s.payInfo, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                if (expired)
                  GradientButton(
                    label: s.pickAgain,
                    icon: Icons.refresh_rounded,
                    onPressed: () => Navigator.of(context).pop(false),
                  )
                else
                  GradientButton(label: s.bookAndPay, icon: Icons.qr_code_2_rounded, busy: _busy, onPressed: _book),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
