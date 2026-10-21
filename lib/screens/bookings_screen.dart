import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
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
        child: EmptyState(
          icon: Icons.sports_tennis_rounded,
          text: s.signInToSeeBookings,
          action: SizedBox(
            width: 220,
            child: GradientButton(label: s.signIn, onPressed: () => ensureSignedIn(context)),
          ),
        ),
      );
    } else if (!_loaded) {
      body = _error != null
          ? ErrorView(message: s.error(_error!), onRetry: _load)
          : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_awaiting.isEmpty && _upcoming.isEmpty && _past.isEmpty)
              EmptyState(icon: Icons.event_available_rounded, text: s.noBookings),
            if (_awaiting.isNotEmpty) SectionTitle(s.awaitingPayment),
            for (final payment in _awaiting) _paymentCard(s, payment),
            if (_upcoming.isNotEmpty) SectionTitle(s.upcoming),
            for (final booking in _upcoming) _bookingTile(s, state.locale, booking),
            if (_past.isNotEmpty) SectionTitle(s.past),
            for (final booking in _past) _bookingTile(s, state.locale, booking, past: true),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(title: s.tabBookings, subtitle: s.bookingsSubtitle),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _paymentCard(S s, Payment payment) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: AppColors.payGradient,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                payment.code,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            Text(
              vnd(payment.remainingVnd),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final b in payment.bookings)
          Text('${b.court.name} · ${timeRange(b.startsAt, b.endsAt)}', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (payment.expiresAt != null)
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        s.payWithin(countdown(payment.expiresAt!.difference(DateTime.now()))),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.orange,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: () => _open(PaymentScreen(token: payment.token, initial: payment)),
              child: Text(s.payNow),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _bookingTile(S s, String locale, Booking booking, {bool past = false}) => SoftCard(
    padding: const EdgeInsets.all(12),
    onTap: () => _open(BookingScreen(booking: booking)),
    child: Row(
      children: [
        DateTile(booking.startsAt, locale, active: !past),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${booking.court.name} · ${timeRange(booking.startsAt, booking.endsAt)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: past ? AppColors.muted : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(longDate(booking.startsAt, locale), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  StatusPill(s.bookingStatus(booking.status), AppColors.bookingStatus(booking.status)),
                  StatusPill(s.paymentStatus(booking.paymentStatus), AppColors.paymentStatus(booking.paymentStatus)),
                  if (booking.paidWithPackage)
                    StatusPill(s.packages, AppColors.violet, icon: Icons.inventory_2_rounded),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}
