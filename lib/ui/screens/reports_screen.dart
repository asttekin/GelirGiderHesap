import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

enum _Period { thisMonth, lastMonth, last3, thisYear, lastYear, custom }

const _periodLabels = {
  _Period.thisMonth: 'Bu ay',
  _Period.lastMonth: 'Geçen ay',
  _Period.last3: 'Son 3 ay',
  _Period.thisYear: 'Bu yıl',
  _Period.lastYear: 'Geçen yıl',
  _Period.custom: 'Özel',
};

/// Finansal raporlar: gelir-gider özeti, kategori dağılımı, aylık trend,
/// bakiye geçmişi, nakit akışı tahmini, cari ve hesap tabloları.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.thisMonth;
  DateTimeRange? _custom;

  DateTimeRange _range() {
    final now = dateOnly(DateTime.now());
    final m = DateTime(now.year, now.month);
    return switch (_period) {
      _Period.thisMonth => DateTimeRange(start: m, end: now),
      _Period.lastMonth => DateTimeRange(start: addMonths(m, -1), end: m.subtract(const Duration(days: 1))),
      _Period.last3 => DateTimeRange(start: addMonths(m, -2), end: now),
      _Period.thisYear => DateTimeRange(start: DateTime(now.year), end: now),
      _Period.lastYear => DateTimeRange(start: DateTime(now.year - 1), end: DateTime(now.year - 1, 12, 31)),
      _Period.custom => _custom ?? DateTimeRange(start: m, end: now),
    };
  }

  /// Karşılaştırma için bir önceki eşit uzunluktaki dönem.
  DateTimeRange _previous(DateTimeRange r) {
    final days = r.end.difference(r.start).inDays + 1;
    final end = r.start.subtract(const Duration(days: 1));
    return DateTimeRange(start: end.subtract(Duration(days: days - 1)), end: end);
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? _range(),
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _period = _Period.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final range = _range();
    final report = buildReport(store.txns, range.start, range.end);
    final prev = buildReport(store.txns, _previous(range).start, _previous(range).end);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    String catName(String id) => id.isEmpty ? 'Kategorisiz' : (store.category(id)?.name ?? 'Silinmiş kategori');
    final expSlices = [for (final e in report.expenseByCategory.entries) (catName(e.key), e.value)];
    final incSlices = [for (final e in report.incomeByCategory.entries) (catName(e.key), e.value)];

    final endMonth = range.end;
    final buckets = monthlyBuckets(store.txns, endMonth, 12);

    final history = historicalBalance(store.accounts, store.txns, range.start, range.end);
    final today = dateOnly(DateTime.now());
    final projection = projectCashFlow(
      startBalance: store.totalCash,
      planned: store.planned,
      today: today,
      days: 90,
    );

    final cards = <Widget>[
      _SummaryGrid(report: report, prev: prev),
      _card(
        context,
        'Aylık gelir ve gider',
        'Son 12 ay · ${fmtMonth(addMonths(endMonth, -11))} – ${fmtMonth(endMonth)}',
        MonthlyBarChart(buckets: buckets),
      ),
      _card(context, 'Gider dağılımı', 'Kategoriye göre', CategoryBreakdown(slices: expSlices)),
      _card(context, 'Gelir dağılımı', 'Kategoriye göre', CategoryBreakdown(slices: incSlices)),
      _card(
        context,
        'Bakiye geçmişi',
        'Dönem içinde gün sonu toplam bakiye',
        CashFlowChart(history: history, projection: const []),
      ),
      _ForecastCard(projection: projection),
      _ContactsTable(report: report),
      _AccountsTable(asOf: range.end),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Dışa aktar',
            icon: const Icon(Icons.ios_share),
            onSelected: (v) {
              final text = v == 'csv'
                  ? _txnCsv(store, range)
                  : _summaryText(store, report, range, expSlices, incSlices);
              Clipboard.setData(ClipboardData(text: text));
              toast(context, v == 'csv' ? 'İşlemler CSV olarak panoya kopyalandı' : 'Rapor özeti panoya kopyalandı');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'summary', child: ListTile(leading: Icon(Icons.summarize_outlined), title: Text('Rapor özetini kopyala'))),
              PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_view_outlined), title: Text('İşlemleri CSV kopyala'))),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in _Period.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_periodLabels[p]!),
                        avatar: p == _Period.custom ? const Icon(Icons.date_range, size: 18) : null,
                        selected: _period == p,
                        onSelected: (_) => p == _Period.custom ? _pickCustom() : setState(() => _period = p),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                '${fmtDate(range.start)} – ${fmtDate(range.end)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            if (wide)
              _TwoColumn(children: cards)
            else
              for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
          ],
        ),
      ),
    );
  }

  static Widget _card(BuildContext context, String title, String subtitle, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );

  String _txnCsv(FinanceStore store, DateTimeRange r) {
    String m(int v) => (v / 100).toStringAsFixed(2).replaceAll('.', ',');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Tarih;Tür;Tutar;Hesap;Hedef hesap;Kategori;Cari;Açıklama\n');
    final limit = dateOnly(r.end).add(const Duration(days: 1));
    for (final t in store.txns.reversed) {
      if (t.date.isBefore(dateOnly(r.start)) || !t.date.isBefore(limit)) continue;
      b.writeln([
        fmtDate(t.date),
        switch (t.type) { TxnType.income => 'Gelir', TxnType.expense => 'Gider', TxnType.transfer => 'Transfer' },
        m(t.type == TxnType.expense ? -t.amount : t.amount),
        q(store.account(t.accountId)?.name ?? ''),
        q(store.account(t.toAccountId)?.name ?? ''),
        q(store.category(t.categoryId)?.name ?? ''),
        q(store.contact(t.contactId)?.name ?? ''),
        q(t.note),
      ].join(';'));
    }
    return b.toString();
  }

  String _summaryText(
    FinanceStore store,
    Report r,
    DateTimeRange range,
    List<(String, int)> exp,
    List<(String, int)> inc,
  ) {
    final (receivable, payable) = store.contactTotals;
    final b = StringBuffer()
      ..writeln('FİNANSAL RAPOR')
      ..writeln('${fmtDate(range.start)} – ${fmtDate(range.end)}')
      ..writeln()
      ..writeln('Toplam gelir : ${fmtMoney(r.income)}')
      ..writeln('Toplam gider : ${fmtMoney(r.expense)}')
      ..writeln('Net sonuç    : ${fmtMoney(r.net, signed: true)}');
    if (r.savingsRate != null) b.writeln('Tasarruf oranı: ${fmtPercent(r.savingsRate!)}');
    b
      ..writeln('İşlem sayısı : ${r.txnCount}')
      ..writeln()
      ..writeln('Güncel toplam nakit: ${fmtMoney(store.totalCash)}')
      ..writeln('Carilerden alacak  : ${fmtMoney(receivable)}')
      ..writeln('Carilere borç      : ${fmtMoney(payable)}');
    void list(String title, List<(String, int)> l) {
      if (l.isEmpty) return;
      b
        ..writeln()
        ..writeln(title);
      for (final e in [...l]..sort((a, b) => b.$2.compareTo(a.$2))) {
        b.writeln('  ${e.$1}: ${fmtMoney(e.$2)}');
      }
    }

    list('Giderler (kategori)', exp);
    list('Gelirler (kategori)', inc);
    b
      ..writeln()
      ..writeln('Hesap bakiyeleri');
    for (final a in store.activeAccounts) {
      b.writeln('  ${a.name}: ${fmtMoney(store.balanceOf(a))}');
    }
    return b.toString();
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // İlk kart (özet) tam genişlikte, kalanlar ikili sütunda.
    final rest = children.skip(1).toList();
    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 16), child: children.first),
        for (var i = 0; i < rest.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: rest[i]),
                const SizedBox(width: 16),
                Expanded(child: i + 1 < rest.length ? rest[i + 1] : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report, required this.prev});
  final Report report;
  final Report prev;

  @override
  Widget build(BuildContext context) {
    final fc = FinColors.of(context);
    final rate = report.savingsRate;
    final tiles = [
      _SummaryTile('Toplam gelir', report.income, prev.income, fc.income, higherIsBetter: true),
      _SummaryTile('Toplam gider', report.expense, prev.expense, fc.expense, higherIsBetter: false),
      _SummaryTile('Net sonuç', report.net, prev.net, null, higherIsBetter: true, signed: true),
      _PlainTile(
        'Tasarruf oranı',
        rate == null ? '—' : fmtPercent(rate),
        '${report.txnCount} işlem',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(this.label, this.value, this.previous, this.color,
      {required this.higherIsBetter, this.signed = false});
  final String label;
  final int value;
  final int previous;
  final Color? color;
  final bool higherIsBetter;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget? delta;
    if (previous != 0) {
      final pct = (value - previous) / previous.abs() * 100;
      final good = higherIsBetter ? pct >= 0 : pct <= 0;
      delta = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pct >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: good ? fc.income : fc.expense),
          Flexible(
            child: Text(
              '%${pct.abs().toStringAsFixed(0)} önceki döneme göre',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: good ? fc.income : fc.expense),
            ),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Money(value, color: color, colored: signed, signed: signed,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            delta ?? Text('Önceki dönem verisi yok', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PlainTile extends StatelessWidget {
  const _PlainTile(this.label, this.value, this.sub);
  final String label, value, sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.projection});
  final List<CashPoint> projection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fc = FinColors.of(context);
    final low = projection.reduce((a, b) => b.balance < a.balance ? b : a);
    final end = projection.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nakit akışı tahmini',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('Planlı ödeme ve tahsilatlara göre önümüzdeki 90 gün',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            CashFlowChart(history: const [], projection: projection),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('En düşük nokta', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      Money(low.balance, color: low.balance < 0 ? fc.expense : null,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(fmtDate(low.date), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('90 gün sonra', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      Money(end.balance, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Money(end.balance - projection.first.balance, colored: true, signed: true,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsTable extends StatelessWidget {
  const _ContactsTable({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final scheme = Theme.of(context).colorScheme;
    final rows = store.contacts
        .map((c) => (c, store.contactBalanceOf(c), report.byContact[c.id] ?? (0, 0)))
        .where((r) => r.$2 != 0 || r.$3.$1 != 0 || r.$3.$2 != 0)
        .toList()
      ..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cari özeti', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('Dönem içi tahsilat/ödeme ve güncel bakiye',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Cari hareketi yok', style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            else ...[
              _row(context, 'Cari', 'Tahsilat', 'Ödeme', 'Bakiye', header: true),
              for (final r in rows.take(8))
                _rowMoney(context, r.$1.name, r.$3.$1, r.$3.$2, r.$2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String a, String b, String c, String d, {bool header = false}) {
    final st = TextStyle(
      fontSize: 12,
      fontWeight: header ? FontWeight.w600 : null,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(a, style: st)),
          Expanded(flex: 2, child: Text(b, style: st, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(c, style: st, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(d, style: st, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _rowMoney(BuildContext context, String name, int inc, int exp, int bal) {
    const st = TextStyle(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: st, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Money(inc, compact: true, style: st, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Money(exp, compact: true, style: st, textAlign: TextAlign.right)),
          Expanded(
            flex: 2,
            child: Money(bal, compact: true, colored: true,
                style: st.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _AccountsTable extends StatelessWidget {
  const _AccountsTable({required this.asOf});
  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final scheme = Theme.of(context).colorScheme;
    final accounts = store.activeAccounts;
    final total = totalBalance(accounts, store.txns, until: asOf);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hesap bakiyeleri',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('${fmtDate(asOf)} gün sonu itibarıyla',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final a in accounts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: Color(a.colorValue), borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Money(accountBalance(a, store.txns, until: asOf),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Toplam', style: TextStyle(fontWeight: FontWeight.w700))),
                Money(total, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
