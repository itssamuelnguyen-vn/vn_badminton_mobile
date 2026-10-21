import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';
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

  /// Extras picked (TI-01): product id -> quantity.
  final Map<int, int> _quantities = {};

  int _extrasVnd(List<Product> products) =>
      products.fold(0, (sum, product) => sum + product.priceVnd * (_quantities[product.id] ?? 0));

  // Offers (UD-03): the price after the member tier or a voucher, or paid with prepaid hours.
  final _voucher = TextEditingController();
  String? _appliedVoucher;
  Quote? _quote;
  List<PackagePurchase> _purchases = const [];
  PackagePurchase? _package;
  int _quoteRequest = 0;

  List<Map<String, dynamic>> get _items => [
    for (final entry in _quantities.entries)
      if (entry.value > 0) {'product_id': entry.key, 'quantity': entry.value},
  ];

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
    _requote();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final json = await _api.get('/packages');
      if (!mounted) return;
      setState(() {
        _purchases = [for (final p in json['purchases'] as List) PackagePurchase.fromJson(p)]
            .where((p) => p.usable)
            .toList();
      });
    } catch (_) {
      // Without them, the customer pays by transfer as usual.
    }
  }

  /// Asks the server what the order costs now (only the latest answer is kept).
  Future<void> _requote() async {
    final request = ++_quoteRequest;
    try {
      final json = await _api.post('/quote', {
        'slots': widget.slots,
        if (_package == null) 'items': _items,
        if (_appliedVoucher != null) 'voucher_code': _appliedVoucher,
        if (_package != null) 'package_purchase_id': _package!.id,
      });
      if (mounted && request == _quoteRequest) setState(() => _quote = Quote.fromJson(json));
    } catch (_) {
      // The booking itself checks everything again.
    }
  }

  void _changeQuantity(int productId, int quantity) {
    setState(() => _quantities[productId] = quantity);
    _requote();
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
    _voucher.dispose();
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
      final json = await _api.post('/bookings', {
        'slots': widget.slots,
        'note': _note.text.trim(),
        if (_package == null) 'items': _items,
        if (_package == null && _appliedVoucher != null) 'voucher_code': _appliedVoucher,
        if (_package != null) 'package_purchase_id': _package!.id,
      });
      _booked = true;
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (_package != null) {
        // Paid with prepaid hours: confirmed already, nothing to transfer.
        showMessage(context, S.of(context).bookedWithPackage);
        navigator.pop(true);
        HomeShell.showTab(context, 1);
        return;
      }
      final payment = Payment.fromJson(json);
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
    final products = AppScope.of(context).venue?.products ?? const <Product>[];

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
                if (_purchases.isNotEmpty) _packageChoice(s),
                if (products.isNotEmpty && _package == null) _extras(s, products),
                if (_package != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(s.extrasAtCounter, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                if (_package == null) _voucherField(s),
                if ((_quote?.discountVnd ?? 0) > 0 && _quote?.offerKind != 'package')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s.discount}: ${_quote!.offerLabel ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '−${vnd(_quote!.discountVnd)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                for (final message in _quote?.messages ?? const <String>[])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(message, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
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
                        vnd(_quote?.totalVnd ?? _amount + _extrasVnd(products)),
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
                  GradientButton(
                    label: _package != null ? s.bookWithPackage : s.bookAndPay,
                    icon: _package != null ? Icons.inventory_2_rounded : Icons.qr_code_2_rounded,
                    busy: _busy,
                    onPressed: _book,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _extras(S s, List<Product> products) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconBadge(Icons.sports_tennis_rounded, AppColors.orange, size: 36),
            const SizedBox(width: 10),
            Text(s.extras, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 4),
        Text(s.extrasHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 4),
        for (final product in products)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(vnd(product.priceVnd), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: AppColors.muted,
                onPressed: (_quantities[product.id] ?? 0) == 0
                    ? null
                    : () => _changeQuantity(product.id, _quantities[product.id]! - 1),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  '${_quantities[product.id] ?? 0}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded),
                color: AppColors.primary,
                onPressed: (_quantities[product.id] ?? 0) >= 20
                    ? null
                    : () => _changeQuantity(product.id, (_quantities[product.id] ?? 0) + 1),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _packageChoice(S s) => SoftCard(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        for (final purchase in _purchases)
          SwitchListTile(
            secondary: const IconBadge(Icons.inventory_2_rounded, AppColors.violet, size: 38),
            title: Text(s.payWithPackage),
            subtitle: Text('${purchase.name} · ${s.packageLeft(s.hours(purchase.minutesLeft))}'),
            value: _package?.id == purchase.id,
            onChanged: (on) {
              setState(() => _package = on ? purchase : null);
              _requote();
            },
          ),
      ],
    ),
  );

  Widget _voucherField(S s) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _voucher,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: s.voucher,
              prefixIcon: const Icon(Icons.confirmation_number_rounded),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
          onPressed: () {
            setState(() => _appliedVoucher = _voucher.text.trim().isEmpty ? null : _voucher.text.trim());
            _requote();
          },
          child: Text(s.apply),
        ),
      ],
    ),
  );
}
