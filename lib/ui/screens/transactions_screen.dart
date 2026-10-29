import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Tüm gelir / gider / transferler: ay, tür, hesap ve metin filtresiyle.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);
  TxnType? _type;
  String? _accountId;
  String _query = '';
  bool _searching = false;

  List<Txn> _filtered(FinanceStore store) {
    final q = _query.trim().toLowerCase();
    return store.txns.where((t) {
      if (_month != null && (t.date.year != _month!.year || t.date.month != _month!.month)) return false;
      if (_type != null && t.type != _type) return false;
      if (_accountId != null && t.accountId != _accountId && t.toAccountId != _accountId) return false;
      if (q.isNotEmpty) {
        final hay = [
          t.note,
          store.category(t.categoryId)?.name ?? '',
          store.contact(t.contactId)?.name ?? '',
          store.account(t.accountId)?.name ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final scheme = Theme.of(context).colorScheme;
    final fc = FinColors.of(context);
    final list = _filtered(store);
    var inc = 0, exp = 0;
    for (final t in list) {
      if (t.type == TxnType.income) inc += t.tryAmount;
      if (t.type == TxnType.expense) exp += t.tryAmount;
    }

    // Güne göre grupla.
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(dateOnly(t.date), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Açıklama, kategori, cari ara…',
                  filled: false,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('İşlemler'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Aramayı kapat' : 'Ara',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: const QuickAddFab(),
      body: ContentWidth(
        maxWidth: 900,
        child: Column(
          children: [
            _MonthBar(
              month: _month,
              onChanged: (m) => setState(() => _month = m),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final (t, label) in [
                    (null, 'Tümü'),
                    (TxnType.income, 'Gelir'),
                    (TxnType.expense, 'Gider'),
                    (TxnType.transfer, 'Transfer'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String?>(
                    tooltip: 'Hesap filtresi',
                    initialValue: _accountId,
                    onSelected: (v) => setState(() => _accountId = v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: null, child: Text('Tüm hesaplar')),
                      for (final a in store.accounts) PopupMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.filter_list, size: 18),
                      label: Text(store.account(_accountId)?.name ?? 'Tüm hesaplar'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _sum('Gelir', inc, fc.income),
                  _sum('Gider', exp, fc.expense),
                  _sum('Net', inc - exp, null, signed: true),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'İşlem bulunamadı',
                      message: 'Filtreleri değiştirin veya yeni bir işlem ekleyin.',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        for (final e in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fmtDateLong(e.key),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Money(
                                  e.value.fold<int>(0, (s, t) => s + switch (t.type) {
                                    TxnType.income => t.tryAmount,
                                    TxnType.expense => -t.tryAmount,
                                    TxnType.transfer => 0,
                                  }),
                                  signed: true,
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          for (final t in e.value) TxnTile(t, showDate: false),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sum(String label, int v, Color? color, {bool signed = false}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Money(v, color: color, colored: signed, signed: signed, compact: true,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    ),
  );
}

/// Ay seçici: ‹ Ekim 2026 › ve "Tüm zamanlar".
class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.onChanged});
  final DateTime? month;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime(DateTime.now().year, DateTime.now().month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki ay',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(addMonths(month ?? now, -1)),
          ),
          Expanded(
            child: Center(
              child: Text(
                month == null ? 'Tüm zamanlar' : fmtMonth(month!),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki ay',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(addMonths(month ?? now, 1)),
          ),
          TextButton(
            onPressed: () => onChanged(month == null ? now : null),
            child: Text(month == null ? 'Bu ay' : 'Tümü'),
          ),
        ],
      ),
    );
  }
}
