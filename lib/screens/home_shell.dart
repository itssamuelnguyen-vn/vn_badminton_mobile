import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../deep_links.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'account_screen.dart';
import 'auth_screens.dart';
import 'booking_screen.dart';
import 'bookings_screen.dart';
import 'payment_screen.dart';
import 'play_screen.dart';
import 'schedule_screen.dart';
import 'tournaments_screen.dart';
import 'settings_screen.dart';

/// The four tabs: booking grid, my bookings, open play, account. Also opens the links of the server's emails
/// (deep_links.dart): the payment page or the booking, after signing in if needed.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static final globalKey = GlobalKey<HomeShellState>();

  /// Closes the screens pushed on top and opens a tab (e.g. "See my bookings" after paying).
  static void showTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    globalKey.currentState?.select(index);
  }

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  // A new key reloads "My bookings" each time it is opened, so it never shows stale data.
  int _bookingsVisits = 0;

  void select(int index) => setState(() {
    if (index == 1) _bookingsVisits++;
    _index = index;
  });

  @override
  void initState() {
    super.initState();
    pendingLink.addListener(_openLink);
    // A link that opened the app before this screen was built (cold start, app lock).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openLink();
      // Customers signed in before notifications came (0.7.0) are asked once too.
      if (mounted) askForNotifications(context);
    });
  }

  @override
  void dispose() {
    pendingLink.removeListener(_openLink);
    super.dispose();
  }

  Future<void> _openLink() async {
    final link = pendingLink.value;
    if (link == null || !mounted || apiUrl.isEmpty) return;
    pendingLink.value = null;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    if (link.target == LinkTarget.home) return select(0);
    // A tournament's page is public.
    if (link.target == LinkTarget.tournament) {
      navigator.push(MaterialPageRoute(builder: (_) => TournamentScreen(id: int.parse(link.value!))));
      return;
    }
    if (!await ensureSignedIn(context) || !mounted) return;

    switch (link.target) {
      case LinkTarget.bookings:
        select(1);
      case LinkTarget.payment:
        navigator.push(MaterialPageRoute(builder: (_) => PaymentScreen(token: link.value!)));
      case LinkTarget.booking:
        try {
          final booking = Booking.fromJson(await AppScope.read(context).api.get('/bookings/${link.value}'));
          navigator.push(MaterialPageRoute(builder: (_) => BookingScreen(booking: booking)));
        } catch (error) {
          if (mounted) showMessage(context, S.of(context).error(error));
        }
      case LinkTarget.home:
      case LinkTarget.tournament:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (apiUrl.isEmpty) return Scaffold(body: Center(child: Text(s.noServer)));

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const ScheduleScreen(),
          BookingsScreen(key: ValueKey(_bookingsVisits)),
          const PlayScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0x14065F46), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: select,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: s.tabBook,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: s.tabBookings,
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups_rounded),
              label: s.tabPlay,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person_rounded),
              label: s.tabAccount,
            ),
          ],
        ),
      ),
    );
  }
}
