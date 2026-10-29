import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_prefs.dart';
import 'data/finance_store.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  final store = FinanceStore();
  final prefs = AppPrefs();
  await Future.wait([store.load(), prefs.load()]);
  runApp(FinanceApp(store: store, prefs: prefs));
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key, required this.store, required this.prefs});

  final FinanceStore store;
  final AppPrefs prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: Consumer<AppPrefs>(
        builder: (context, p, _) => MaterialApp(
          title: 'Finans',
          debugShowCheckedModeBanner: false,
          themeMode: p.themeMode,
          theme: buildTheme(Brightness.light, Color(p.seedColor)),
          darkTheme: buildTheme(Brightness.dark, Color(p.seedColor)),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
