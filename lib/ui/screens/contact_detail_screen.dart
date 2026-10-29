import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../forms/contact_entry_form.dart';
import '../forms/contact_form.dart';
import '../forms/planned_form.dart';
import '../forms/txn_form.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Cari kartı: bakiye, iletişim bilgisi, ekstre ve planlı kalemler.
class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final c = store.contact(contactId);
    if (c == null) return const Scaffold(body: Center(child: Text('Cari bulunamadı')));
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balance = store.contactBalanceOf(c);
    final statement = contactStatement(c, store.entries, store.txns);
    final planned = store.planned.where((p) => p.contactId == c.id && !p.completed).toList();

    final statusColor = balance > 0 ? fc.income : (balance < 0 ? fc.expense : scheme.onSurfaceVariant);
    final statusText = balance > 0
        ? 'Cari size borçlu (alacağınız)'
        : balance < 0
            ? 'Siz cariye borçlusunuz'
            : 'Hesap kapalı';

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            tooltip: 'Ekstreyi kopyala (CSV)',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _statementCsv(c, statement)));
              toast(context, 'Ekstre panoya kopyalandı');
            },
          ),
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => pushPage(context, ContactFormPage(existing: c)),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(contactTypeLabel(c.type)), visualDensity: VisualDensity.compact),
                        const Spacer(),
                        if (c.taxNumber.isNotEmpty)
                          Text('VKN ${c.taxNumber}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                    Money(balance.abs(), color: statusColor,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    if (c.phone.isNotEmpty || c.email.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          if (c.phone.isNotEmpty) _info(context, Icons.phone_outlined, c.phone),
                          if (c.email.isNotEmpty) _info(context, Icons.alternate_email, c.email),
                        ],
                      ),
                    ],
                    if (c.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(c.note, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => pushPage(context, TxnFormPage(initialType: TxnType.income, contactId: c.id)),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Tahsilat al'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => pushPage(context, TxnFormPage(initialType: TxnType.expense, contactId: c.id)),
                  icon: const Icon(Icons.north_east),
                  label: const Text('Ödeme yap'),
                ),
                OutlinedButton.icon(
                  onPressed: () => pushPage(context, ContactEntryFormPage(contactId: c.id)),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Fatura / dekont'),
                ),
                OutlinedButton.icon(
                  onPressed: () => pushPage(
                    context,
                    PlannedFormPage(
                      contactId: c.id,
                      initialKind: balance < 0 ? PlannedKind.payment : PlannedKind.collection,
                      initialAmount: balance == 0 ? null : balance.abs(),
                      initialTitle: '${c.name} ${balance < 0 ? 'ödemesi' : 'tahsilatı'}',
                    ),
                  ),
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Vade planla'),
                ),
              ],
            ),
            if (planned.isNotEmpty) ...[
              const SectionHeader('Planlı ödeme / tahsilatlar'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final p in planned) PlannedTile(p, onTap: () => showCompletePlanned(context, p)),
                  ],
                ),
              ),
            ],
            const SectionHeader('Cari ekstresi'),
            if (statement.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Henüz hareket yok.', style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (c.openingBalance != 0)
                      ListTile(
                        dense: true,
                        title: const Text('Açılış bakiyesi'),
                        trailing: Money(c.openingBalance, signed: true),
                      ),
                    for (final l in statement.reversed) _StatementRow(line: l),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 4),
      Flexible(child: SelectableText(text, maxLines: 1)),
    ],
  );

  String _statementCsv(Contact c, List<StatementLine> lines) {
    String m(int v) => (v / 100).toStringAsFixed(2).replaceAll('.', ',');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Tarih;Açıklama;Borç;Alacak;Bakiye\n');
    if (c.openingBalance != 0) b.writeln(';Açılış bakiyesi;;;${m(c.openingBalance)}');
    for (final l in lines) {
      b.writeln([
        fmtDate(l.date),
        q(l.description),
        l.debit == 0 ? '' : m(l.debit),
        l.credit == 0 ? '' : m(l.credit),
        m(l.balance),
      ].join(';'));
    }
    return b.toString();
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.line});
  final StatementLine line;

  @override
  Widget build(BuildContext context) {
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final src = line.source;
    final isEntry = src is ContactEntry;
    final debit = line.debit > 0;
    final label = switch (src) {
      ContactEntry(type: EntryType.sale) => 'Satış faturası',
      ContactEntry() => 'Alış faturası',
      Txn(type: TxnType.income) => 'Tahsilat',
      _ => 'Ödeme',
    };
    return ListTile(
      leading: IconBadge(
        isEntry ? Icons.request_quote_outlined : (debit ? Icons.north_east : Icons.south_west),
        debit ? fc.income : fc.expense,
        size: 36,
      ),
      title: Text(line.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${fmtDate(line.date)} · $label', style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Money(debit ? line.debit : -line.credit, signed: true, style: const TextStyle(fontWeight: FontWeight.w600)),
          Money(line.balance, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
      onTap: () => pushPage(
        context,
        src is ContactEntry ? ContactEntryFormPage(existing: src) : TxnFormPage(existing: src as Txn),
      ),
    );
  }
}
