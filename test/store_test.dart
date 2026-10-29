import 'package:finans/data/demo_data.dart';
import 'package:finans/data/finance_store.dart';
import 'package:finans/logic/finance_math.dart';
import 'package:finans/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FinanceStore> fresh() async {
    final s = FinanceStore();
    await s.load();
    return s;
  }

  test('ilk açılışta varsayılan kategoriler yüklenir', () async {
    final s = await fresh();
    expect(s.isEmpty, isTrue);
    expect(s.categoriesOf(CategoryKind.income), isNotEmpty);
    expect(s.categoriesOf(CategoryKind.expense), isNotEmpty);
  });

  test('veri kaydedilir ve yeniden yüklenir', () async {
    final s = await fresh();
    loadDemoData(s);
    await Future<void>.delayed(Duration.zero);
    final cash = s.totalCash;
    final s2 = await fresh();
    expect(s2.accounts.length, s.accounts.length);
    expect(s2.txns.length, s.txns.length);
    expect(s2.totalCash, cash);
    expect(s2.planned.length, s.planned.length);
  });

  test('yedek dışa/içe aktarma', () async {
    final s = await fresh();
    loadDemoData(s);
    final json = s.exportJson();
    await s.resetAll();
    expect(s.isEmpty, isTrue);
    await s.importJson(json);
    expect(s.accounts, isNotEmpty);
    expect(() => s.importJson('[1,2]'), throwsFormatException);
  });

  test('tekrarlayan planlı kalem gerçekleşince vade ilerler', () async {
    final s = await fresh();
    const a = Account(id: 'a', name: 'Banka');
    s.upsertAccount(a);
    final p = PlannedItem(
      id: 'p',
      kind: PlannedKind.payment,
      title: 'Kira',
      amount: 1000,
      dueDate: DateTime(2026, 1, 1),
      recurrence: Recurrence.monthly,
      endDate: DateTime(2026, 2, 1),
    );
    s.upsertPlanned(p);
    s.completePlanned(p, accountId: 'a');
    expect(s.plannedItem('p')!.dueDate, DateTime(2026, 2, 1));
    expect(s.plannedItem('p')!.completed, isFalse);
    expect(s.balanceOf(a), -1000);

    s.completePlanned(s.plannedItem('p')!, accountId: 'a', amount: 1200);
    expect(s.plannedItem('p')!.completed, isTrue);
    expect(s.balanceOf(a), -2200);
    expect(s.txns.every((t) => t.plannedId == 'p'), isTrue);
  });

  test('işlemi olan hesap silinmez, arşivlenir', () async {
    final s = await fresh();
    s.upsertAccount(const Account(id: 'a', name: 'A'));
    s.upsertAccount(const Account(id: 'b', name: 'B'));
    s.upsertTxn(Txn(id: 't', type: TxnType.income, amount: 1, date: DateTime.now(), accountId: 'a'));
    expect(s.deleteAccount('a'), isFalse);
    expect(s.account('a')!.archived, isTrue);
    expect(s.deleteAccount('b'), isTrue);
    expect(s.account('b'), isNull);
  });

  test('cari silinince işlemler kalır, bağlantı kalkar', () async {
    final s = await fresh();
    s.upsertAccount(const Account(id: 'a', name: 'A'));
    s.upsertContact(const Contact(id: 'c', name: 'C'));
    s.upsertTxn(Txn(id: 't', type: TxnType.income, amount: 1, date: DateTime.now(), accountId: 'a', contactId: 'c'));
    s.upsertEntry(ContactEntry(id: 'e', contactId: 'c', type: EntryType.sale, amount: 5, date: DateTime.now()));
    s.deleteContact('c');
    expect(s.txns.single.contactId, isNull);
    expect(s.entries, isEmpty);
  });

  test('demo verisi tutarlı', () async {
    final s = await fresh();
    final now = DateTime(2026, 10, 29);
    loadDemoData(s, now: now);
    expect(s.txns.every((t) => !t.date.isAfter(now)), isTrue);
    expect(s.planned.where((p) => p.dueDate.isBefore(dateOnly(now))).length, 1);
    final (receivable, payable) = s.contactTotals;
    expect(receivable, greaterThan(0));
    expect(payable, greaterThan(0));
  });
}
