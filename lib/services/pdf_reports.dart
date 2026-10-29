import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/finance_store.dart';
import '../logic/currency.dart';
import '../logic/finance_math.dart';
import '../models/models.dart';
import '../ui/category_icons.dart';
import '../ui/format.dart';

/// PDF finansal rapor ve cari ekstresi üretimi (A4).
class PdfReports {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    return _theme = pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static const _primary = PdfColor.fromInt(0xFF00695C);
  static const _muted = PdfColor.fromInt(0xFF6B6B6B);
  static const _line = PdfColor.fromInt(0xFFE0E0E0);
  static const _income = PdfColor.fromInt(0xFF1B7F45);
  static const _expense = PdfColor.fromInt(0xFFB3261E);
  static const _barIncome = PdfColor.fromInt(0xFF2A78D6);
  static const _barExpense = PdfColor.fromInt(0xFFEB6834);

  static String _now() {
    final n = DateTime.now();
    return '${fmtDate(n)} ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  static pw.Widget _header(String title, String subtitle) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    margin: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 2))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _primary)),
              pw.SizedBox(height: 2),
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
        pw.Text('Oluşturulma: ${_now()}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  );

  static pw.Widget _footer(pw.Context ctx) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
  );

  static pw.Widget _section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _kpi(String label, String value, {PdfColor? color}) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(6)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    ),
  );

  static pw.Widget _table(List<String> headers, List<List<String>> rows, {List<int> rightAligned = const []}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        border: null,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5))),
        cellAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
        headerAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
      );

  /// Kategori dağılımı: ad, yüzde çubuğu, tutar.
  static pw.Widget _breakdown(List<(String, int)> slices, PdfColor color) {
    final sorted = [...slices.where((s) => s.$2 > 0)]..sort((a, b) => b.$2.compareTo(a.$2));
    final total = sorted.fold<int>(0, (s, e) => s + e.$2);
    if (total == 0) {
      return pw.Text('Bu dönemde kayıt yok.', style: const pw.TextStyle(fontSize: 9, color: _muted));
    }
    return pw.Column(
      children: [
        for (final s in sorted)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 120, child: pw.Text(s.$1, style: const pw.TextStyle(fontSize: 9), maxLines: 1)),
                pw.Expanded(
                  child: pw.LayoutBuilder(
                    builder: (ctx, c) => pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        height: 7,
                        width: (c?.maxWidth ?? 100) * s.$2 / sorted.first.$2,
                        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 34,
                  child: pw.Text('%${(s.$2 / total * 100).toStringAsFixed(0)}',
                      textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: _muted)),
                ),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(fmtMoney(s.$2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Aylık gelir / gider çubuk grafiği.
  static pw.Widget _monthlyChart(List<MonthBucket> buckets) {
    var maxV = 1;
    for (final b in buckets) {
      if (b.income > maxV) maxV = b.income;
      if (b.expense > maxV) maxV = b.expense;
    }
    const h = 90.0;
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Container(width: 8, height: 8, color: _barIncome),
            pw.SizedBox(width: 4),
            pw.Text('Gelir', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(width: 12),
            pw.Container(width: 8, height: 8, color: _barExpense),
            pw.SizedBox(width: 4),
            pw.Text('Gider', style: const pw.TextStyle(fontSize: 8)),
            pw.Spacer(),
            pw.Text('En yüksek: ${fmtMoney(maxV, compact: true)}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: h + 14,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _muted, width: 0.5))),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(width: 7, height: h * b.income / maxV, color: _barIncome),
                          pw.SizedBox(width: 1.5),
                          pw.Container(width: 7, height: h * b.expense / maxV, color: _barExpense),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(fmtMonthShort(b.month), style: const pw.TextStyle(fontSize: 7, color: _muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Dönem finansal raporu.
  static Future<Uint8List> financialReport({
    required FinanceStore store,
    required DateTime from,
    required DateTime to,
  }) async {
    final theme = await _loadTheme();
    final r = buildReport(store.txns, from, to);
    final rates = store.rates;
    String catName(String id) => id.isEmpty ? 'Kategorisiz' : (store.category(id)?.name ?? 'Silinmiş kategori');
    final exp = [for (final e in r.expenseByCategory.entries) (catName(e.key), e.value)];
    final inc = [for (final e in r.incomeByCategory.entries) (catName(e.key), e.value)];
    final buckets = monthlyBuckets(store.txns, to, 12);
    final (receivable, payable) = store.contactTotals;
    final today = dateOnly(DateTime.now());
    final upcoming = upcomingEvents(store.planned, today, today.add(const Duration(days: 30)));
    final projection = projectCashFlow(
      startBalance: store.totalCash,
      planned: store.planned,
      today: today,
      days: 90,
      rates: rates,
    );
    final low = projection.reduce((a, b) => b.balance < a.balance ? b : a);

    final contacts = store.contacts
        .map((c) => (c, store.contactBalanceOf(c), r.byContact[c.id] ?? (0, 0)))
        .where((x) => x.$2 != 0 || x.$3.$1 != 0 || x.$3.$2 != 0)
        .toList()
      ..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));

    final doc = pw.Document(title: 'Finansal Rapor', author: 'Finans', theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        header: (ctx) => ctx.pageNumber == 1
            ? _header('Finansal Rapor', '${fmtDate(from)} – ${fmtDate(to)}')
            : pw.SizedBox(),
        footer: _footer,
        build: (ctx) => [
          pw.GridView(
            crossAxisCount: 4,
            childAspectRatio: 0.42,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _kpi('Toplam gelir', fmtMoney(r.income), color: _income),
              _kpi('Toplam gider', fmtMoney(r.expense), color: _expense),
              _kpi('Net sonuç', fmtMoney(r.net, signed: true), color: r.net >= 0 ? _income : _expense),
              _kpi('Tasarruf oranı', r.savingsRate == null ? '—' : fmtPercent(r.savingsRate!)),
              _kpi('Güncel toplam nakit', fmtMoney(store.totalCash)),
              _kpi('Carilerden alacak', fmtMoney(receivable), color: _income),
              _kpi('Carilere borç', fmtMoney(payable), color: _expense),
              _kpi('İşlem sayısı', '${r.txnCount}'),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Döviz kurları: 1 USD = ${fmtRate(rates.usd)} ₺ · 1 EUR = ${fmtRate(rates.eur)} ₺ '
            '(${rates.source}${rates.updatedAt == null ? '' : ', ${fmtDate(rates.updatedAt!)}'}). '
            'Döviz işlemleri işlem tarihindeki kurla, bakiyeler güncel kurla ₺\'ye çevrilmiştir.',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
          _section('Aylık gelir ve gider (son 12 ay)'),
          _monthlyChart(buckets),
          pw.SizedBox(height: 8),
          _table(
            ['Ay', 'Gelir', 'Gider', 'Net'],
            [
              for (final b in buckets.where((b) => b.income != 0 || b.expense != 0))
                [fmtMonth(b.month), fmtMoney(b.income), fmtMoney(b.expense), fmtMoney(b.net, signed: true)],
            ],
            rightAligned: const [1, 2, 3],
          ),
          _section('Gider dağılımı'),
          _breakdown(exp, _barExpense),
          _section('Gelir dağılımı'),
          _breakdown(inc, _barIncome),
          _section('Hesap bakiyeleri'),
          _table(
            ['Hesap', 'Tür', 'Banka', 'Bakiye', '₺ karşılığı'],
            [
              for (final a in store.activeAccounts)
                [
                  a.name,
                  accountTypeLabel(a.type),
                  a.bankName,
                  fmtMoney(store.balanceOf(a), currency: a.currency),
                  fmtMoney(store.tryBalanceOf(a)),
                ],
              ['Toplam', '', '', '', fmtMoney(store.totalCash)],
            ],
            rightAligned: const [3, 4],
          ),
          if (contacts.isNotEmpty) ...[
            _section('Cari özeti'),
            _table(
              ['Cari', 'Dönem tahsilat', 'Dönem ödeme', 'Bakiye', 'Durum'],
              [
                for (final c in contacts)
                  [
                    c.$1.name,
                    fmtMoney(c.$3.$1),
                    fmtMoney(c.$3.$2),
                    fmtMoney(c.$2.abs()),
                    c.$2 > 0 ? 'Alacak' : (c.$2 < 0 ? 'Borç' : 'Kapalı'),
                  ],
              ],
              rightAligned: const [1, 2, 3],
            ),
          ],
          _section('Önümüzdeki 30 günün ödeme ve tahsilatları'),
          if (upcoming.isEmpty)
            pw.Text('Planlı kalem yok.', style: const pw.TextStyle(fontSize: 9, color: _muted))
          else
            _table(
              ['Vade', 'Açıklama', 'Cari', 'Tür', 'Tutar'],
              [
                for (final e in upcoming)
                  [
                    '${fmtDate(e.date)}${e.overdue ? ' (gecikmiş)' : ''}',
                    e.item.title,
                    store.contact(e.item.contactId)?.name ?? '',
                    e.item.kind == PlannedKind.collection ? 'Tahsilat' : 'Ödeme',
                    fmtMoney(e.item.signedAmount, signed: true, currency: e.item.currency),
                  ],
              ],
              rightAligned: const [4],
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            '90 günlük nakit akışı tahmini: en düşük bakiye ${fmtMoney(low.balance)} (${fmtDate(low.date)}), '
            '90 gün sonra ${fmtMoney(projection.last.balance)}.',
            style: pw.TextStyle(fontSize: 9, color: low.balance < 0 ? _expense : null),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Cari hesap ekstresi.
  static Future<Uint8List> statement({required FinanceStore store, required Contact contact}) async {
    final theme = await _loadTheme();
    final lines = contactStatement(contact, store.entries, store.txns);
    final balance = store.contactBalanceOf(contact);
    var debit = 0, credit = 0;
    for (final l in lines) {
      debit += l.debit;
      credit += l.credit;
    }
    final info = [
      contactTypeLabel(contact.type),
      if (contact.taxNumber.isNotEmpty) 'VKN/TCKN ${contact.taxNumber}',
      if (contact.phone.isNotEmpty) contact.phone,
      if (contact.email.isNotEmpty) contact.email,
    ].join(' · ');

    final doc = pw.Document(title: 'Cari Ekstresi - ${contact.name}', author: 'Finans', theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        header: (ctx) => ctx.pageNumber == 1 ? _header('Cari Hesap Ekstresi', contact.name) : pw.SizedBox(),
        footer: _footer,
        build: (ctx) => [
          pw.Text(info, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(child: _kpi('Toplam borç (satış + ödeme)', fmtMoney(debit))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpi('Toplam alacak (alış + tahsilat)', fmtMoney(credit))),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpi(
                  balance > 0 ? 'Bakiye — cari borçlu' : (balance < 0 ? 'Bakiye — biz borçluyuz' : 'Bakiye'),
                  fmtMoney(balance.abs()),
                  color: balance > 0 ? _income : (balance < 0 ? _expense : null),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _table(
            ['Tarih', 'Açıklama', 'Borç', 'Alacak', 'Bakiye'],
            [
              if (contact.openingBalance != 0) ['', 'Açılış bakiyesi', '', '', fmtMoney(contact.openingBalance)],
              for (final l in lines)
                [
                  fmtDate(l.date),
                  l.description,
                  l.debit == 0 ? '' : fmtMoney(l.debit),
                  l.credit == 0 ? '' : fmtMoney(l.credit),
                  fmtMoney(l.balance),
                ],
            ],
            rightAligned: const [2, 3, 4],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Bakiye pozitif ise cari firmaya borçludur, negatif ise firma cariye borçludur. '
            'Döviz işlemleri işlem tarihindeki kurla ₺\'ye çevrilmiştir. '
            '${currencyName('TRY')} cinsinden hazırlanmıştır.',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
