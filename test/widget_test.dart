import 'package:finans/data/app_prefs.dart';
import 'package:finans/data/demo_data.dart';
import 'package:finans/data/finance_store.dart';
import 'package:finans/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(FinanceStore, AppPrefs)> _setup({bool demo = true}) async {
  SharedPreferences.setMockInitialValues({});
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  final store = FinanceStore();
  final prefs = AppPrefs();
  await store.load();
  await prefs.load();
  if (demo) loadDemoData(store);
  return (store, prefs);
}

Future<void> _visitAllTabs(WidgetTester tester) async {
  for (final tab in ['İşlemler', 'Planlı', 'Hesaplar', 'Raporlar', 'Özet']) {
    await tester.tap(find.text(tab).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: tab);
  }
}

void main() {
  for (final size in [const Size(390, 844), const Size(1366, 1024)]) {
    testWidgets('tüm sekmeler örnek veriyle açılır (${size.width.toInt()} px)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (store, prefs) = await _setup();
      await tester.pumpWidget(FinanceApp(store: store, prefs: prefs));
      await tester.pumpAndSettle();
      expect(find.text('Toplam nakit varlık'), findsOneWidget);
      await _visitAllTabs(tester);

      // Cari sekmesi ve detay
      await tester.tap(find.text('Hesaplar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cari Hesaplar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akdeniz Lojistik A.Ş.'));
      await tester.pumpAndSettle();
      expect(find.text('Cari ekstresi'), findsOneWidget);
    });
  }

  testWidgets('koyu tema ve gizli tutarlar', (tester) async {
    final (store, prefs) = await _setup();
    prefs.themeMode = ThemeMode.dark;
    prefs.hideAmounts = true;
    await tester.pumpWidget(FinanceApp(store: store, prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('₺ ••••'), findsWidgets);
    await _visitAllTabs(tester);
  });

  testWidgets('boş durumda karşılama ve hızlı gider ekleme', (tester) async {
    final (store, prefs) = await _setup(demo: false);
    await tester.pumpWidget(FinanceApp(store: store, prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('Örnek veriyle dene'), findsOneWidget);
    await _visitAllTabs(tester);

    // İlk hesabı ekle
    await tester.tap(find.text('İlk hesabı ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hesap adı'), 'Ana Hesap');
    await tester.enterText(find.widgetWithText(TextFormField, 'Açılış bakiyesi'), '1.000,50');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.totalCash, 100050);
    await tester.pump(const Duration(seconds: 6)); // bildirim kapansın
    await tester.pumpAndSettle();

    // Gider ekle
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gider'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Tutar'), '250,25');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.totalCash, 100050 - 25025);
    expect(tester.takeException(), isNull);
  });
}
