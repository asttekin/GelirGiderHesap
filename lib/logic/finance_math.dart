/// Bakiye, nakit akışı projeksiyonu ve rapor hesapları.
///
/// Buradaki fonksiyonlar saftır (yan etkisi yoktur); arayüzden bağımsız
/// olarak test edilebilir.
library;

import '../models/models.dart';
import 'currency.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ay sonuna taşmayı engelleyerek ay ekler (31 Ocak + 1 ay → 28/29 Şubat).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

/// [base] tarihinden itibaren [r] tekrarına göre [n]. vade.
/// Her vade [base]'den hesaplanır; böylece ay sonu kayması birikmez.
DateTime occurrenceAt(DateTime base, Recurrence r, int n) => switch (r) {
  Recurrence.none => base,
  Recurrence.weekly => DateTime(base.year, base.month, base.day + 7 * n),
  Recurrence.monthly => addMonths(base, n),
  Recurrence.quarterly => addMonths(base, 3 * n),
  Recurrence.yearly => addMonths(base, 12 * n),
};

DateTime nextOccurrence(DateTime d, Recurrence r) => occurrenceAt(d, r, 1);

// ---------------------------------------------------------------------------
// Bakiyeler
// ---------------------------------------------------------------------------

/// Bir işlemin [accountId] hesabının bakiyesine etkisi (hesabın biriminde).
int txnEffectOn(Txn t, String accountId) {
  switch (t.type) {
    case TxnType.income:
      return t.accountId == accountId ? t.amount : 0;
    case TxnType.expense:
      return t.accountId == accountId ? -t.amount : 0;
    case TxnType.transfer:
      var e = 0;
      if (t.accountId == accountId) e -= t.amount;
      if (t.toAccountId == accountId) e += t.toAmount ?? t.amount;
      return e;
  }
}

/// Hesap bakiyesi (hesabın kendi biriminde). [until] verilirse o günün
/// sonuna kadarki işlemler sayılır.
int accountBalance(Account a, Iterable<Txn> txns, {DateTime? until}) {
  final limit = until == null ? null : dateOnly(until).add(const Duration(days: 1));
  var b = a.openingBalance;
  for (final t in txns) {
    if (limit != null && !t.date.isBefore(limit)) continue;
    b += txnEffectOn(t, a.id);
  }
  return b;
}

/// Tüm (arşivlenmemiş) hesapların ₺ cinsinden toplam bakiyesi. Döviz
/// hesapları [rates] (güncel kur) ile çevrilir.
int totalBalance(
  Iterable<Account> accounts,
  Iterable<Txn> txns, {
  DateTime? until,
  Rates rates = Rates.fallback,
}) {
  var sum = 0;
  for (final a in accounts) {
    if (a.archived) continue;
    sum += rates.toTry(accountBalance(a, txns, until: until), a.currency);
  }
  return sum;
}

/// Cari bakiyesi (₺). Pozitif: cari bize borçlu (alacak), negatif: biz borçluyuz.
///
/// Satış faturası alacağı artırır, alış faturası azaltır. Cariden gelen
/// tahsilat (gelir) alacağı kapatır, cariye yapılan ödeme (gider) borcu kapatır.
/// Döviz hesabından yapılan işlemler işlem anındaki kurla ₺'ye çevrilir.
int contactBalance(Contact c, Iterable<ContactEntry> entries, Iterable<Txn> txns) {
  var b = c.openingBalance;
  for (final e in entries) {
    if (e.contactId != c.id) continue;
    b += e.type == EntryType.sale ? e.amount : -e.amount;
  }
  for (final t in txns) {
    if (t.contactId != c.id) continue;
    if (t.type == TxnType.income) b -= t.tryAmount;
    if (t.type == TxnType.expense) b += t.tryAmount;
  }
  return b;
}

/// Cari ekstresinin bir satırı.
class StatementLine {
  final DateTime date;
  final String description;
  final int debit; // carinin borcu (alacağımız) artar
  final int credit; // carinin borcu azalır
  final int balance;
  final Object source; // ContactEntry veya Txn
  const StatementLine({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.source,
  });
}

/// Cari ekstresi: tarih sırasına göre yürüyen bakiyeli satırlar.
List<StatementLine> contactStatement(
  Contact c,
  Iterable<ContactEntry> entries,
  Iterable<Txn> txns,
) {
  final rows = <(DateTime, String, int, int, Object)>[];
  for (final e in entries.where((e) => e.contactId == c.id)) {
    final desc = e.note.isNotEmpty
        ? e.note
        : (e.type == EntryType.sale ? 'Satış / borç dekontu' : 'Alış / alacak dekontu');
    rows.add(
      e.type == EntryType.sale
          ? (e.date, desc, e.amount, 0, e)
          : (e.date, desc, 0, e.amount, e),
    );
  }
  for (final t in txns.where((t) => t.contactId == c.id)) {
    var desc = t.note.isNotEmpty ? t.note : (t.type == TxnType.income ? 'Tahsilat' : 'Ödeme');
    if (t.currency != 'TRY') {
      final fx = (t.amount / 100).toStringAsFixed(2).replaceAll('.', ',');
      desc += ' ($fx ${t.currency} × ${t.rate.toStringAsFixed(4).replaceAll('.', ',')})';
    }
    if (t.type == TxnType.income) {
      rows.add((t.date, desc, 0, t.tryAmount, t));
    } else if (t.type == TxnType.expense) {
      rows.add((t.date, desc, t.tryAmount, 0, t));
    }
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  var bal = c.openingBalance;
  return [
    for (final r in rows)
      StatementLine(
        date: r.$1,
        description: r.$2,
        debit: r.$3,
        credit: r.$4,
        balance: bal += r.$3 - r.$4,
        source: r.$5,
      ),
  ];
}

// ---------------------------------------------------------------------------
// Planlı kalemler ve nakit akışı projeksiyonu
// ---------------------------------------------------------------------------

/// Planlı bir kalemin [from]–[to] (dahil) arasındaki gerçekleşme günleri.
///
/// [from]'dan önceki (gecikmiş) vadeler [from] gününe taşınır: o para hâlâ
/// ödenecek / tahsil edilecek kabul edilir.
List<DateTime> occurrencesBetween(PlannedItem p, DateTime from, DateTime to) {
  if (p.completed) return const [];
  final start = dateOnly(from);
  final end = dateOnly(to);
  final base = dateOnly(p.dueDate);
  final last = p.endDate == null ? null : dateOnly(p.endDate!);
  final out = <DateTime>[];
  for (var n = 0; n < 2000; n++) {
    final d = occurrenceAt(base, p.recurrence, n);
    if (d.isAfter(end)) break;
    if (last != null && d.isAfter(last)) break;
    out.add(d.isBefore(start) ? start : d);
    if (p.recurrence == Recurrence.none) break;
  }
  return out;
}

/// Projeksiyonda tek bir beklenen hareket.
class ProjectedEvent {
  final DateTime date;
  final PlannedItem item;
  final bool overdue;
  const ProjectedEvent(this.date, this.item, {this.overdue = false});
}

List<ProjectedEvent> upcomingEvents(
  Iterable<PlannedItem> planned,
  DateTime today,
  DateTime to,
) {
  final t = dateOnly(today);
  final events = <ProjectedEvent>[];
  for (final p in planned) {
    if (p.completed) continue;
    final base = dateOnly(p.dueDate);
    for (var n = 0; n < 2000; n++) {
      final d = occurrenceAt(base, p.recurrence, n);
      if (d.isAfter(dateOnly(to))) break;
      if (p.endDate != null && d.isAfter(dateOnly(p.endDate!))) break;
      events.add(ProjectedEvent(d, p, overdue: d.isBefore(t)));
      if (p.recurrence == Recurrence.none) break;
    }
  }
  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}

class CashPoint {
  final DateTime date;
  final int balance;
  const CashPoint(this.date, this.balance);
}

/// Bugünden itibaren [days] gün boyunca günlük tahmini toplam bakiye (₺).
/// Döviz cinsinden planlı kalemler [rates] ile çevrilir.
List<CashPoint> projectCashFlow({
  required int startBalance,
  required Iterable<PlannedItem> planned,
  required DateTime today,
  int days = 90,
  Rates rates = Rates.fallback,
}) {
  final start = dateOnly(today);
  final end = start.add(Duration(days: days));
  final delta = <DateTime, int>{};
  for (final p in planned) {
    for (final d in occurrencesBetween(p, start, end)) {
      delta[d] = (delta[d] ?? 0) + rates.toTry(p.signedAmount, p.currency);
    }
  }
  var bal = startBalance;
  return [
    for (var i = 0; i <= days; i++)
      () {
        final d = DateTime(start.year, start.month, start.day + i);
        bal += delta[d] ?? 0;
        return CashPoint(d, bal);
      }(),
  ];
}

// ---------------------------------------------------------------------------
// Raporlar
// ---------------------------------------------------------------------------

class MonthBucket {
  final DateTime month;
  final int income;
  final int expense;
  const MonthBucket(this.month, this.income, this.expense);
  int get net => income - expense;
}

class Report {
  final DateTime from;
  final DateTime to;
  final int income;
  final int expense;

  /// Kategori id → tutar. Kategorisiz işlemler `''` anahtarındadır.
  final Map<String, int> incomeByCategory;
  final Map<String, int> expenseByCategory;

  /// Cari id → (tahsilat, ödeme).
  final Map<String, (int, int)> byContact;
  final int txnCount;

  const Report({
    required this.from,
    required this.to,
    required this.income,
    required this.expense,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.byContact,
    required this.txnCount,
  });

  int get net => income - expense;

  /// Gelirin ne kadarının harcanmadan kaldığı (%). Gelir yoksa `null`.
  double? get savingsRate => income == 0 ? null : net / income * 100;
}

bool _inRange(DateTime d, DateTime from, DateTime to) =>
    !d.isBefore(dateOnly(from)) &&
    d.isBefore(dateOnly(to).add(const Duration(days: 1)));

Report buildReport(Iterable<Txn> txns, DateTime from, DateTime to) {
  var income = 0, expense = 0, count = 0;
  final inc = <String, int>{}, exp = <String, int>{};
  final byContact = <String, (int, int)>{};
  for (final t in txns) {
    if (!_inRange(t.date, from, to) || t.type == TxnType.transfer) continue;
    count++;
    final key = t.categoryId ?? '';
    final v = t.tryAmount;
    if (t.type == TxnType.income) {
      income += v;
      inc[key] = (inc[key] ?? 0) + v;
    } else {
      expense += v;
      exp[key] = (exp[key] ?? 0) + v;
    }
    if (t.contactId != null) {
      final cur = byContact[t.contactId!] ?? (0, 0);
      byContact[t.contactId!] = t.type == TxnType.income
          ? (cur.$1 + v, cur.$2)
          : (cur.$1, cur.$2 + v);
    }
  }
  return Report(
    from: from,
    to: to,
    income: income,
    expense: expense,
    incomeByCategory: inc,
    expenseByCategory: exp,
    byContact: byContact,
    txnCount: count,
  );
}

/// [months] aylık gelir/gider dağılımı; son eleman [endMonth] ayıdır.
List<MonthBucket> monthlyBuckets(Iterable<Txn> txns, DateTime endMonth, int months) {
  final first = addMonths(DateTime(endMonth.year, endMonth.month), -(months - 1));
  final inc = List.filled(months, 0), exp = List.filled(months, 0);
  for (final t in txns) {
    if (t.type == TxnType.transfer) continue;
    final idx = (t.date.year - first.year) * 12 + (t.date.month - first.month);
    if (idx < 0 || idx >= months) continue;
    if (t.type == TxnType.income) {
      inc[idx] += t.tryAmount;
    } else {
      exp[idx] += t.tryAmount;
    }
  }
  return [
    for (var i = 0; i < months; i++) MonthBucket(addMonths(first, i), inc[i], exp[i]),
  ];
}

/// [from]–[to] arasında gün sonu toplam bakiyeleri (₺, gerçekleşen
/// işlemlerden). Döviz hesapları güncel kurla [rates] çevrilir.
List<CashPoint> historicalBalance(
  Iterable<Account> accounts,
  Iterable<Txn> txns,
  DateTime from,
  DateTime to, {
  Rates rates = Rates.fallback,
}) {
  final active = [for (final a in accounts) if (!a.archived) a];
  final start = dateOnly(from), end = dateOnly(to);
  var bal = 0;
  for (final a in active) {
    bal += rates.toTry(a.openingBalance, a.currency);
  }
  final delta = <DateTime, int>{};
  for (final t in txns) {
    var e = 0;
    for (final a in active) {
      e += rates.toTry(txnEffectOn(t, a.id), a.currency);
    }
    if (e == 0) continue;
    final d = dateOnly(t.date);
    if (d.isBefore(start)) {
      bal += e;
    } else if (!d.isAfter(end)) {
      delta[d] = (delta[d] ?? 0) + e;
    }
  }
  final out = <CashPoint>[];
  for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    bal += delta[d] ?? 0;
    out.add(CashPoint(d, bal));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Tutar ayrıştırma
// ---------------------------------------------------------------------------

/// Kullanıcının yazdığı tutarı kuruşa çevirir. "1.234,56", "1234.56",
/// "1 234,5" ve "1234" biçimlerini kabul eder. Geçersizse `null`.
int? parseAmount(String input) {
  var s = input.trim().replaceAll(' ', '').replaceAll('₺', '').replaceAll('TL', '');
  if (s.isEmpty) return null;
  final neg = s.startsWith('-');
  if (neg) s = s.substring(1);
  final lastComma = s.lastIndexOf(','), lastDot = s.lastIndexOf('.');
  String intPart, frac = '';
  if (lastComma >= 0 && lastDot >= 0) {
    // Hangisi sonda ise ondalık ayırıcıdır.
    final sep = lastComma > lastDot ? lastComma : lastDot;
    intPart = s.substring(0, sep).replaceAll(RegExp(r'[.,]'), '');
    frac = s.substring(sep + 1);
  } else if (lastComma >= 0 || lastDot >= 0) {
    final ch = lastComma >= 0 ? ',' : '.';
    final parts = s.split(ch);
    // "1.234.567" ya da "1.234" (3 haneli grup) binlik ayırıcı kabul edilir,
    // virgül her zaman ondalıktır (Türkçe kullanım).
    if (ch == '.' && parts.length > 1 && parts.skip(1).every((p) => p.length == 3)) {
      intPart = parts.join();
    } else if (parts.length == 2) {
      intPart = parts[0];
      frac = parts[1];
    } else {
      return null;
    }
  } else {
    intPart = s;
  }
  if (intPart.isEmpty) intPart = '0';
  if (!RegExp(r'^\d+$').hasMatch(intPart)) return null;
  if (frac.isNotEmpty && !RegExp(r'^\d{1,2}$').hasMatch(frac)) return null;
  final v = int.parse(intPart) * 100 + (frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0')));
  return neg ? -v : v;
}
