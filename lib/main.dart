import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_lock.dart';
import 'app_state.dart';
import 'deep_links.dart';
import 'screens/home_shell.dart';
import 'strings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  await initializeDateFormatting('en');
  final state = AppState();
  // Early, so the link that opened the app is not missed; the home screen opens it once built.
  listenToLinks();
  await state.load();
  runApp(AppScope(state: state, child: const VnBadmintonApp()));
  // After the first frame is on its way; a notification that opened the app is kept until the home screen shows it.
  state.startPush(channelName: S(state.locale).notificationChannel, onOpen: openPath);
}

class VnBadmintonApp extends StatelessWidget {
  const VnBadmintonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MaterialApp(
      title: 'VN Badminton',
      debugShowCheckedModeBanner: false,
      locale: Locale(state.locale),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(),
      home: AppLock(child: HomeShell(key: HomeShell.globalKey)),
    );
  }
}
