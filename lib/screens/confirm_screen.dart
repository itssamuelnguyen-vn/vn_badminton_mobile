import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
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
      navigator.push(MaterialPageRoute(builder: (_) => PaymentScreen(token: payment.token, initial: payment)));
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
      appBar: AppBar(title: Text(s.confirmTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: expired ? Theme.of(context).colorScheme.errorContainer : Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(expired ? Icons.timer_off : Icons.timer_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(expired ? s.holdExpired : s.heldFor(countdown(_left)))),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        for (final booking in _bookings)
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_tennis),
              title: Text('${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}'),
              subtitle: Text(longDate(booking.startsAt, locale)),
              trailing: Text(vnd(booking.amountVnd)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(child: Text(s.total, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text(vnd(_amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
        ),
        TextField(controller: _note, decoration: InputDecoration(labelText: s.note), maxLength: 500, maxLines: 2),
        Text(s.payInfo, style: TextStyle(color: Theme.of(context).hintColor)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        if (expired)
          FilledButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.pickAgain))
        else
          FilledButton(
            onPressed: _busy ? null : _book,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.bookAndPay),
          ),
      ]),
    );
  }
}
