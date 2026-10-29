import 'package:finans/data/demo_data.dart';
import 'package:finans/data/finance_store.dart';
import 'package:finans/data/rate_service.dart';
import 'package:finans/logic/currency.dart';
import 'package:finans/logic/finance_math.dart';
import 'package:finans/models/models.dart';
import 'package:finans/services/pdf_reports.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const rates = Rates(usd: 40, eur: 50, source: 'test');
  final now = DateTime(2026, 10, 29, 10);

  group('Rates', () {
    test('çevirme', () {
      expect(rates.toTry(10000, 'USD'), 400000);
      expect(rates.toTry(10000, 'TRY'), 10000);
      expect(rates.fromTry(500000, 'EUR'), 10000);
      expect(rates.convert(10000, 'EUR', 'USD'), 12500);
      expect(rates.convert(777, 'USD', 'USD'), 777);
    });

    test('parseRate', () {
      expect(parseRate('41,9876'), 41.9876);
      expect(parseRate('41.98'), 41.98);
      expect(parseRate('0'), isNull);
      expect(parseRate('abc'), isNull);
    });

    test('JSON', () {
      final r = Rates(usd: 41.5, eur: 48.2, updatedAt: now, source: 'TCMB');
      final back = Rates.fromJson(r.toJson());
      expect((back.usd, back.eur, back.updatedAt, back.source), (41.5, 48.2, now, 'TCMB'));
    });
  });

  group('kur kaynakları', () {
    test('TCMB XML', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<Tarih_Date Tarih="29.10.2026">
  <Currency CrossOrder="0" Kod="USD" CurrencyCode="USD">
    <Unit>1</Unit><Isim>ABD DOLARI</Isim>
    <ForexBuying>41.8765</ForexBuying><ForexSelling>41.9520</ForexSelling>
  </Currency>
  <Currency CrossOrder="9" Kod="EUR" CurrencyCode="EUR">
    <Unit>1</Unit><Isim>EURO</Isim>
    <ForexBuying>48.6001</ForexBuying><ForexSelling>48.6877</ForexSelling>
  </Currency>
</Tarih_Date>''';
      final r = RateService.parseTcmb(xml, now);
      expect(r.usd, 41.952);
      expect(r.eur, 48.6877);
      expect(r.source, contains('TCMB'));
    });

    test('Frankfurter JSON (ters kur)', () {
      final r = RateService.parseFrankfurter(
        '{"amount":1.0,"base":"TRY","date":"2026-10-29","rates":{"EUR":0.02,"USD":0.025}}',
        now,
      );
      expect(r.usd, closeTo(40, 1e-9));
      expect(r.eur, closeTo(50, 1e-9));
    });

    test('ExchangeRate-API JSON', () {
      final r = RateService.parseErApi('{"result":"success","rates":{"USD":1,"TRY":40.0,"EUR":0.8}}', now);
      expect(r.usd, 40);
      expect(r.eur, closeTo(50, 1e-9));
      expect(() => RateService.parseErApi('{"result":"error"}', now), throwsFormatException);
    });

    test('ilk kaynak başarısızsa sonrakine geçer, hepsi başarısızsa kur korunur', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FinanceStore();
      await store.load();
      final client = MockClient((req) async {
        if (req.url.host.contains('frankfurter')) {
          return http.Response('{"base":"TRY","rates":{"EUR":0.02,"USD":0.025}}', 200);
        }
        return http.Response('hata', 503);
      });
      final s = RateService(store, client: client);
      expect(await s.refresh(), isNull);
      expect(store.rates.usd, closeTo(40, 1e-9));
      expect(store.rates.updatedAt, isNotNull);

      final failing = RateService(store, client: MockClient((_) async => http.Response('', 500)));
      expect(await failing.refresh(), isNotNull);
      expect(store.rates.usd, closeTo(40, 1e-9));
    });
  });

  group('döviz hesapları', () {
    const tryAcc = Account(id: 't', name: 'TL', openingBalance: 100000);
    const usdAcc = Account(id: 'u', name: 'USD', currency: 'USD', openingBalance: 10000); // 100 $
    final txns = [
      Txn(id: '1', type: TxnType.income, amount: 5000, date: now, accountId: 'u', currency: 'USD', rate: 38),
      Txn(id: '2', type: TxnType.transfer, amount: 2000, date: now, accountId: 'u', toAccountId: 't',
          currency: 'USD', rate: 38, toAmount: 76000),
    ];

    test('bakiye kendi biriminde, toplam güncel kurla', () {
      expect(accountBalance(usdAcc, txns), 13000); // 100 + 50 − 20 $
      expect(accountBalance(tryAcc, txns), 176000);
      expect(totalBalance([tryAcc, usdAcc], txns, rates: rates), 176000 + 13000 * 40);
    });

    test('rapor işlem anındaki kurla', () {
      final r = buildReport(txns, now, now);
      expect(r.income, 5000 * 38);
    });

    test('cari bakiyesi döviz tahsilatını ₺ çevirir', () {
      const c = Contact(id: 'c', name: 'C', openingBalance: 500000);
      final t = Txn(id: 'x', type: TxnType.income, amount: 10000, date: now, accountId: 'u',
          currency: 'EUR', rate: 45, contactId: 'c');
      expect(contactBalance(c, const [], [t]), 500000 - 450000);
      expect(contactStatement(c, const [], [t]).single.description, contains('EUR'));
    });

    test('projeksiyon döviz kalemlerini çevirir', () {
      final p = PlannedItem(id: 'p', kind: PlannedKind.collection, title: 'E', amount: 10000,
          dueDate: now, currency: 'EUR');
      final proj = projectCashFlow(startBalance: 0, planned: [p], today: now, days: 1, rates: rates);
      expect(proj.first.balance, 500000);
    });

    test('döviz planlı kalem TL hesaptan ödenince çevrilir', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FinanceStore();
      await store.load();
      store.setRates(rates);
      store.upsertAccount(tryAcc);
      final p = PlannedItem(id: 'p', kind: PlannedKind.payment, title: 'Lisans', amount: 5900,
          dueDate: now, currency: 'USD');
      store.upsertPlanned(p);
      final t = store.completePlanned(p, accountId: 't');
      expect(t.currency, 'TRY');
      expect(t.amount, 5900 * 40);
      expect(store.plannedItem('p')!.completed, isTrue);
    });
  });

  test('PDF rapor ve ekstre üretilir', () async {
    SharedPreferences.setMockInitialValues({});
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
    final store = FinanceStore();
    await store.load();
    loadDemoData(store);
    final pdf = await PdfReports.financialReport(
      store: store,
      from: DateTime(DateTime.now().year, 1, 1),
      to: DateTime.now(),
    );
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(10000));
    final st = await PdfReports.statement(store: store, contact: store.contacts.first);
    expect(String.fromCharCodes(st.take(5)), '%PDF-');
  });
}
