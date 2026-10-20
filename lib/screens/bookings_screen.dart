import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'booking_screen.dart';
import 'payment_screen.dart';

/// "My bookings": orders waiting for a transfer, upcoming and past bookings.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Payment> _awaiting = [];
  List<Booking> _upcoming = [];
  List<Booking> _past = [];
  bool _loaded = false;
  Object? _error;
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = AppScope.of(context).user?.id;
    if (userId != _userId || !_loaded) {
      _userId = userId;
      if (userId != null) _load();
    }
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/bookings');
      if (!mounted) return;
      setState(() {
        _awaiting = [for (final p in json['awaiting_payments'] as List) Payment.fromJson(p)];
        _upcoming = [for (final b in json['upcoming'] as List) Booking.fromJson(b)];
        _past = [for (final b in json['past'] as List) Booking.fromJson(b)];
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);

    Widget body;
    if (!state.signedIn) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.signInToSeeBookings, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ensureSignedIn(context), child: Text(s.signIn)),
          ]),
        ),
      );
    } else if (!_loaded) {
      body = _error != null ? ErrorView(message: s.error(_error!), onRetry: _load) : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (_awaiting.isEmpty && _upcoming.isEmpty && _past.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(s.noBookings, textAlign: TextAlign.center)),
          if (_awaiting.isNotEmpty) _heading(s.awaitingPayment),
          for (final payment in _awaiting)
            Card(
              color: Colors.amber.shade50,
              child: ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text('${payment.code} · ${vnd(payment.remainingVnd)}'),
                subtitle: Text([
                  for (final b in payment.bookings) '${b.court.name} ${timeRange(b.startsAt, b.endsAt)}',
                  if (payment.expiresAt != null) s.payWithin(countdown(payment.expiresAt!.difference(DateTime.now()))),
                ].join('\n')),
                trailing: FilledButton(
                  onPressed: () => _open(PaymentScreen(token: payment.token, initial: payment)),
                  child: Text(s.payNow),
                ),
              ),
            ),
          if (_upcoming.isNotEmpty) _heading(s.upcoming),
          for (final booking in _upcoming) _bookingTile(s, state.locale, booking),
          if (_past.isNotEmpty) _heading(s.past),
          for (final booking in _past) _bookingTile(s, state.locale, booking, past: true),
        ]),
      );
    }

    return Scaffold(appBar: AppBar(title: Text(s.tabBookings)), body: body);
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _bookingTile(S s, String locale, Booking booking, {bool past = false}) => Card(
        color: past ? Colors.grey.shade100 : null,
        child: ListTile(
          leading: Icon(Icons.sports_tennis, color: past ? Colors.grey : null),
          title: Text('${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}'),
          subtitle: Text('${longDate(booking.startsAt, locale)}\n'
              '${s.bookingStatus(booking.status)} · ${s.paymentStatus(booking.paymentStatus)}'),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(BookingScreen(booking: booking)),
        ),
      );
}
