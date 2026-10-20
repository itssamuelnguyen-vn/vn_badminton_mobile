import 'package:flutter/material.dart';

import '../api.dart';
import '../strings.dart';
import 'account_screen.dart';
import 'bookings_screen.dart';
import 'schedule_screen.dart';

/// The three tabs: booking grid, my bookings, account.
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
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (apiUrl.isEmpty) return Scaffold(body: Center(child: Text(s.noServer)));

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const ScheduleScreen(),
          BookingsScreen(key: ValueKey(_bookingsVisits)),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: s.tabBook),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: s.tabBookings),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: s.tabAccount),
        ],
      ),
    );
  }
}
