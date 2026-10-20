import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_lock.dart';
import 'app_state.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  await initializeDateFormatting('en');
  final state = AppState();
  await state.load();
  runApp(AppScope(state: state, child: const VnBadmintonApp()));
}

class VnBadmintonApp extends StatelessWidget {
  const VnBadmintonApp({super.key});

  // Emerald 600, as on the web.
  static const brand = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MaterialApp(
      title: 'VN Badminton',
      debugShowCheckedModeBanner: false,
      locale: Locale(state.locale),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: AppLock(child: HomeShell(key: HomeShell.globalKey)),
    );
  }
}
