import 'dart:math';

import '../logic/finance_math.dart';
import '../models/models.dart';
import 'finance_store.dart';

/// Uygulamayı denemek için son 6 aya yayılmış örnek veri yükler.
void loadDemoData(FinanceStore store, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final rnd = Random(42);
  int tl(num v) => (v * 100).round();
  DateTime daysAgo(int d) => today.subtract(Duration(days: d));

  final bank = Account(id: newId(), name: 'İş Hesabı', bankName: 'Ziraat Bankası',
      iban: 'TR12 0001 0000 0000 1234 5678 01', openingBalance: tl(185000), colorValue: 0xFF1E88E5);
  final bank2 = Account(id: newId(), name: 'Maaş Hesabı', bankName: 'Garanti BBVA',
      iban: 'TR45 0006 2000 0000 9876 5432 10', openingBalance: tl(42000), colorValue: 0xFF00897B);
  final cash = Account(id: newId(), name: 'Kasa', type: AccountType.cash,
      openingBalance: tl(8500), colorValue: 0xFF43A047);
  final card = Account(id: newId(), name: 'Şirket Kartı', type: AccountType.creditCard,
      bankName: 'Yapı Kredi', openingBalance: tl(-12400), colorValue: 0xFF5E35B1);
  final savings = Account(id: newId(), name: 'Vadeli Mevduat', type: AccountType.savings,
      bankName: 'Ziraat Bankası', openingBalance: tl(250000), colorValue: 0xFFF9A825);

  final c1 = Contact(id: newId(), name: 'Akdeniz Lojistik A.Ş.', phone: '0242 555 10 20',
      email: 'muhasebe@akdenizlojistik.com', taxNumber: '1234567890', openingBalance: tl(18000));
  final c2 = Contact(id: newId(), name: 'Mavi Yazılım Ltd.', phone: '0216 444 33 22',
      email: 'finans@maviyazilim.com', taxNumber: '9876543210');
  final c3 = Contact(id: newId(), name: 'Ege Gıda Ticaret', phone: '0232 333 44 55');
  final s1 = Contact(id: newId(), name: 'Kuzey Kırtasiye', type: ContactType.supplier,
      phone: '0312 222 11 00', openingBalance: tl(-4200));
  final s2 = Contact(id: newId(), name: 'Delta Bilişim', type: ContactType.supplier,
      phone: '0212 777 88 99', email: 'satis@deltabilisim.com');
  final s3 = Contact(id: newId(), name: 'Anadolu Gayrimenkul', type: ContactType.supplier);

  final txns = <Txn>[];
  final entries = <ContactEntry>[];
  void add(TxnType type, num amount, int ago, Account acc,
      {String? cat, Contact? contact, String note = '', Account? to}) {
    txns.add(Txn(id: newId(), type: type, amount: tl(amount), date: daysAgo(ago),
        accountId: acc.id, toAccountId: to?.id, categoryId: cat, contactId: contact?.id, note: note));
  }

  // Aylık tekrar eden hareketler (son 6 ay).
  int? prevSale1;
  for (var m = 5; m >= 0; m--) {
    final monthStart = addMonths(DateTime(today.year, today.month), -m);
    int ago(int day) => today.difference(DateTime(monthStart.year, monthStart.month, day)).inDays;
    bool past(int day) => ago(day) >= 0;

    if (past(1)) add(TxnType.expense, 22000, ago(1), bank, cat: 'exp_rent', contact: s3, note: 'Ofis kirası');
    if (past(5)) add(TxnType.expense, 58000, ago(5), bank, cat: 'exp_salary', note: 'Personel maaşları');
    if (past(26)) add(TxnType.expense, 18500 + rnd.nextInt(2000), ago(26), bank, cat: 'exp_tax', note: 'SGK primi');
    if (past(12)) add(TxnType.expense, 2800 + rnd.nextInt(1800), ago(12), bank, cat: 'exp_bills', note: 'Elektrik + su + doğalgaz');
    if (past(15)) add(TxnType.expense, 1450, ago(15), card, cat: 'exp_software', note: 'Bulut sunucu aboneliği');
    if (past(18)) add(TxnType.expense, 1900 + rnd.nextInt(900), ago(18), card, cat: 'exp_transport', note: 'Akaryakıt');
    if (past(20)) add(TxnType.expense, 9500, ago(20), bank, cat: 'exp_loan', note: 'Taşıt kredisi taksiti');
    if (past(9)) add(TxnType.income, 1650 + rnd.nextInt(400), ago(9), savings, cat: 'inc_interest', note: 'Mevduat faizi');

    // Satış faturaları ve tahsilatları
    // Akdeniz Lojistik her ay bir önceki ayın faturasını öder.
    final sale1 = 70000 + rnd.nextInt(20000);
    if (past(3)) {
      entries.add(ContactEntry(id: newId(), contactId: c1.id, type: EntryType.sale,
          amount: tl(sale1), date: daysAgo(ago(3)), note: 'Taşıma hizmeti faturası'));
    }
    if (past(22) && prevSale1 != null) {
      add(TxnType.income, prevSale1, ago(22), bank, cat: 'inc_service', contact: c1, note: 'Fatura tahsilatı');
    }
    prevSale1 = sale1;

    final sale2 = 35000 + rnd.nextInt(15000);
    if (past(8)) {
      entries.add(ContactEntry(id: newId(), contactId: c2.id, type: EntryType.sale,
          amount: tl(sale2), date: daysAgo(ago(8)), note: 'Danışmanlık hizmeti'));
    }
    if (past(25)) add(TxnType.income, sale2, ago(25), bank, cat: 'inc_service', contact: c2, note: 'Havale');

    for (var k = 0; k < 6; k++) {
      final day = 2 + rnd.nextInt(26);
      if (!past(day)) continue;
      add(TxnType.income, 1200 + rnd.nextInt(6500), ago(day), cash, cat: 'inc_sales', contact: k == 0 ? c3 : null,
          note: 'Peşin satış');
    }
    for (var k = 0; k < 4; k++) {
      final day = 2 + rnd.nextInt(26);
      if (!past(day)) continue;
      add(TxnType.expense, 250 + rnd.nextInt(1200), ago(day), cash, cat: 'exp_food', note: 'Market / ikram');
    }

    // Tedarikçi alımları
    final purchase = 8000 + rnd.nextInt(9000);
    if (past(10)) {
      entries.add(ContactEntry(id: newId(), contactId: s2.id, type: EntryType.purchase,
          amount: tl(purchase), date: daysAgo(ago(10)), note: 'Donanım alımı'));
    }
    if (past(27) && m > 0) add(TxnType.expense, purchase, ago(27), bank, cat: 'exp_purchase', contact: s2, note: 'Tedarikçi ödemesi');
    if (past(14)) add(TxnType.expense, 3200 + rnd.nextInt(1500), ago(14), card, cat: 'exp_marketing', note: 'Dijital reklam');
    if (past(16)) add(TxnType.transfer, 20000, ago(16), cash, to: bank, note: 'Kasadan bankaya yatırılan');
    if (past(11)) add(TxnType.transfer, 7000, ago(11), bank, to: card, note: 'Kredi kartı ödemesi');
  }
  entries.add(ContactEntry(id: newId(), contactId: s1.id, type: EntryType.purchase,
      amount: tl(3600), date: daysAgo(20), note: 'Kırtasiye malzemesi'));

  // Yaklaşan ödeme ve tahsilatlar
  DateTime inDays(int d) => today.add(Duration(days: d));
  DateTime nextDay(int day) {
    var d = DateTime(today.year, today.month, day);
    if (!d.isAfter(today)) d = addMonths(d, 1);
    return d;
  }

  final planned = <PlannedItem>[
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'Ofis kirası', amount: tl(22000),
        dueDate: nextDay(1), accountId: bank.id, categoryId: 'exp_rent', contactId: s3.id, recurrence: Recurrence.monthly),
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'Personel maaşları', amount: tl(58000),
        dueDate: nextDay(5), accountId: bank.id, categoryId: 'exp_salary', recurrence: Recurrence.monthly),
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'SGK primi', amount: tl(19500),
        dueDate: nextDay(26), accountId: bank.id, categoryId: 'exp_tax', recurrence: Recurrence.monthly),
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'Taşıt kredisi taksiti', amount: tl(9500),
        dueDate: nextDay(20), accountId: bank.id, categoryId: 'exp_loan', recurrence: Recurrence.monthly,
        endDate: addMonths(today, 14)),
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'KDV beyannamesi', amount: tl(12400),
        dueDate: nextDay(28), accountId: bank.id, categoryId: 'exp_tax', recurrence: Recurrence.monthly),
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'Kredi kartı ekstresi', amount: tl(7200),
        dueDate: inDays(9), accountId: bank.id, categoryId: 'exp_loan'),
    PlannedItem(id: newId(), kind: PlannedKind.payment, title: 'Kuzey Kırtasiye borcu', amount: tl(7800),
        dueDate: daysAgo(3), accountId: cash.id, categoryId: 'exp_purchase', contactId: s1.id),
    PlannedItem(id: newId(), kind: PlannedKind.collection, title: 'Akdeniz Lojistik fatura tahsilatı',
        amount: tl(prevSale1 ?? 80000), dueDate: nextDay(22), accountId: bank.id, categoryId: 'inc_service',
        contactId: c1.id, recurrence: Recurrence.monthly),
    PlannedItem(id: newId(), kind: PlannedKind.collection, title: 'Mavi Yazılım bakım sözleşmesi',
        amount: tl(18500), dueDate: nextDay(15), accountId: bank.id, categoryId: 'inc_service',
        contactId: c2.id, recurrence: Recurrence.monthly),
    PlannedItem(id: newId(), kind: PlannedKind.collection, title: 'Ege Gıda çek tahsilatı', amount: tl(24000),
        dueDate: inDays(21), accountId: bank.id, categoryId: 'inc_sales', contactId: c3.id),
    PlannedItem(id: newId(), kind: PlannedKind.collection, title: 'Mevduat faizi', amount: tl(1800),
        dueDate: nextDay(9), accountId: savings.id, categoryId: 'inc_interest', recurrence: Recurrence.monthly),
  ];

  store.addAll(
    accounts: [bank, bank2, cash, card, savings],
    contacts: [c1, c2, c3, s1, s2, s3],
    txns: txns,
    entries: entries,
    planned: planned,
  );
}
