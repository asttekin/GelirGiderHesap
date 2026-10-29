import 'package:finans/logic/finance_math.dart';
import 'package:finans/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmount', () {
    test('Türkçe ve İngilizce biçimler', () {
      expect(parseAmount('1.234,56'), 123456);
      expect(parseAmount('1234,5'), 123450);
      expect(parseAmount('1234.56'), 123456);
      expect(parseAmount('1.234'), 123400);
      expect(parseAmount('1.234.567'), 123456700);
      expect(parseAmount('12.5'), 1250);
      expect(parseAmount('₺ 250'), 25000);
      expect(parseAmount('-45,10'), -4510);
      expect(parseAmount('1,234.56'), 123456);
    });

    test('geçersiz girişler', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('1,2,3'), isNull);
      expect(parseAmount('1,234'), isNull); // virgülden sonra 3 hane
    });
  });

  test('addMonths ay sonunu korur', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    expect(addMonths(DateTime(2026, 3, 10), -4), DateTime(2025, 11, 10));
  });

  test('aylık tekrar baz tarihten hesaplanır (kayma birikmez)', () {
    final base = DateTime(2026, 1, 31);
    expect(occurrenceAt(base, Recurrence.monthly, 1), DateTime(2026, 2, 28));
    expect(occurrenceAt(base, Recurrence.monthly, 2), DateTime(2026, 3, 31));
  });

  group('bakiyeler', () {
    const a = Account(id: 'a', name: 'Banka', openingBalance: 10000);
    const b = Account(id: 'b', name: 'Kasa');
    final txns = [
      Txn(id: '1', type: TxnType.income, amount: 5000, date: DateTime(2026, 5, 1), accountId: 'a'),
      Txn(id: '2', type: TxnType.expense, amount: 2000, date: DateTime(2026, 5, 2), accountId: 'a'),
      Txn(id: '3', type: TxnType.transfer, amount: 3000, date: DateTime(2026, 5, 3), accountId: 'a', toAccountId: 'b'),
    ];

    test('hesap bakiyesi ve transfer', () {
      expect(accountBalance(a, txns), 10000);
      expect(accountBalance(b, txns), 3000);
      expect(totalBalance([a, b], txns), 13000);
      expect(accountBalance(a, txns, until: DateTime(2026, 5, 1)), 15000);
    });

    test('arşivlenmiş hesap toplama girmez', () {
      expect(totalBalance([a, b.copyWith(archived: true)], txns), 10000);
    });

    test('bakiye geçmişi transferleri nötr sayar', () {
      final h = historicalBalance([a, b], txns, DateTime(2026, 4, 30), DateTime(2026, 5, 3));
      expect(h.map((p) => p.balance), [10000, 15000, 13000, 13000]);
    });
  });

  test('cari bakiyesi ve ekstre', () {
    const c = Contact(id: 'c', name: 'Müşteri', openingBalance: 1000);
    final entries = [
      ContactEntry(id: 'e1', contactId: 'c', type: EntryType.sale, amount: 5000, date: DateTime(2026, 1, 1)),
      ContactEntry(id: 'e2', contactId: 'c', type: EntryType.purchase, amount: 500, date: DateTime(2026, 1, 3)),
    ];
    final txns = [
      Txn(id: 't', type: TxnType.income, amount: 2000, date: DateTime(2026, 1, 2), accountId: 'a', contactId: 'c'),
      Txn(id: 'u', type: TxnType.income, amount: 999, date: DateTime(2026, 1, 2), accountId: 'a'),
    ];
    expect(contactBalance(c, entries, txns), 1000 + 5000 - 2000 - 500);
    final st = contactStatement(c, entries, txns);
    expect(st.map((l) => l.balance), [6000, 4000, 3500]);
  });

  group('planlı kalemler', () {
    final today = DateTime(2026, 10, 15);

    test('gecikmiş vade bugüne taşınır, tekrarlar sayılır', () {
      final p = PlannedItem(
        id: 'p',
        kind: PlannedKind.payment,
        title: 'Kira',
        amount: 1000,
        dueDate: DateTime(2026, 10, 1),
        recurrence: Recurrence.monthly,
      );
      final occ = occurrencesBetween(p, today, DateTime(2026, 12, 31));
      expect(occ, [today, DateTime(2026, 11, 1), DateTime(2026, 12, 1)]);
    });

    test('son vade sonrası üretilmez', () {
      final p = PlannedItem(
        id: 'p',
        kind: PlannedKind.payment,
        title: 'Taksit',
        amount: 1000,
        dueDate: DateTime(2026, 10, 20),
        recurrence: Recurrence.monthly,
        endDate: DateTime(2026, 11, 20),
      );
      expect(occurrencesBetween(p, today, DateTime(2027, 6, 1)).length, 2);
    });

    test('nakit akışı projeksiyonu', () {
      final items = [
        PlannedItem(id: '1', kind: PlannedKind.collection, title: 'T', amount: 5000, dueDate: DateTime(2026, 10, 17)),
        PlannedItem(id: '2', kind: PlannedKind.payment, title: 'Ö', amount: 8000, dueDate: DateTime(2026, 10, 16)),
        PlannedItem(id: '3', kind: PlannedKind.payment, title: 'X', amount: 1, dueDate: DateTime(2026, 10, 16), completed: true),
      ];
      final proj = projectCashFlow(startBalance: 10000, planned: items, today: today, days: 3);
      expect(proj.map((p) => p.balance), [10000, 2000, 7000, 7000]);
    });
  });

  test('rapor ve aylık dağılım transferleri saymaz', () {
    final txns = [
      Txn(id: '1', type: TxnType.income, amount: 100, date: DateTime(2026, 9, 5), accountId: 'a', categoryId: 'x', contactId: 'c'),
      Txn(id: '2', type: TxnType.expense, amount: 40, date: DateTime(2026, 10, 5), accountId: 'a', categoryId: 'y'),
      Txn(id: '3', type: TxnType.transfer, amount: 999, date: DateTime(2026, 10, 6), accountId: 'a', toAccountId: 'b'),
      Txn(id: '4', type: TxnType.expense, amount: 10, date: DateTime(2026, 10, 31, 23, 59), accountId: 'a'),
    ];
    final r = buildReport(txns, DateTime(2026, 9, 1), DateTime(2026, 10, 31));
    expect(r.income, 100);
    expect(r.expense, 50);
    expect(r.expenseByCategory, {'y': 40, '': 10});
    expect(r.byContact['c'], (100, 0));
    expect(r.savingsRate, 50);

    final m = monthlyBuckets(txns, DateTime(2026, 10), 3);
    expect(m.map((b) => (b.income, b.expense)), [(0, 0), (100, 0), (0, 50)]);
  });
}
