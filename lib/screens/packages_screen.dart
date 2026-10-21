import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment_screen.dart';

/// Prepaid hours (UD-04): the customer's own, with the time left, and the packages on sale, bought by transfer.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  List<PackageOffer> _packages = const [];
  List<PackagePurchase> _purchases = const [];
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await AppScope.read(context).api.get('/packages');
      if (!mounted) return;
      setState(() {
        _packages = [for (final p in json['packages'] as List) PackageOffer.fromJson(p)];
        _purchases = [for (final p in json['purchases'] as List) PackagePurchase.fromJson(p)];
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _openPayment(String token, [Payment? initial]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(token: token, initial: initial),
      ),
    );
    _load();
  }

  Future<void> _buy(PackageOffer package) async {
    final s = S.of(context);
    try {
      final json = await AppScope.read(context).api.post('/packages/${package.id}/buy');
      if (!mounted) return;
      final payment = Payment.fromJson(json);
      _openPayment(payment.token, payment);
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(title: s.packages, subtitle: s.packagesIntro),
          Expanded(
            child: !_loaded
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (_purchases.isNotEmpty) SectionTitle(s.myPackages),
                        for (final purchase in _purchases) _purchaseCard(s, purchase),
                        SectionTitle(s.forSale),
                        if (_packages.isEmpty) EmptyState(icon: Icons.inventory_2_rounded, text: s.nothingYet),
                        for (final package in _packages) _packageCard(s, package),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(s.packageRules, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseCard(S s, PackagePurchase purchase) {
    final progress = purchase.minutesTotal == 0 ? 0.0 : purchase.minutesLeft / purchase.minutesTotal;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  purchase.name,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (purchase.status == 'awaiting')
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.orange,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: purchase.paymentToken == null ? null : () => _openPayment(purchase.paymentToken!),
                  child: Text(s.awaitingTransfer),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.packageLeft(s.hours(purchase.minutesLeft)),
            style: const TextStyle(color: AppColors.lime, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (purchase.expiresAt != null) s.expiresOn(longDate(purchase.expiresAt!, AppScope.of(context).locale)),
              if (purchase.startMinute != null)
                s.onlyBetween(minuteLabel(purchase.startMinute!), minuteLabel(purchase.endMinute!)),
            ].join(' · '),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _packageCard(S s, PackageOffer package) => SoftCard(
    child: Row(
      children: [
        const IconBadge(Icons.inventory_2_rounded, AppColors.violet),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(package.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                [
                  s.hours(package.minutes),
                  s.validFor(package.validDays),
                  if (package.startMinute != null)
                    s.onlyBetween(minuteLabel(package.startMinute!), minuteLabel(package.endMinute!)),
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                vnd(package.priceVnd),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
              ),
            ],
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          onPressed: () => _buy(package),
          child: Text(s.buy),
        ),
      ],
    ),
  );
}
