import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../format.dart';
import '../forms/planned_form.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Yaklaşan ödemeler ve tahsilatlar.
class PlannedScreen extends StatefulWidget {
  const PlannedScreen({super.key});

  @override
  State<PlannedScreen> createState() => _PlannedScreenState();
}

class _PlannedScreenState extends State<PlannedScreen> {
  PlannedKind? _kind;
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final today = dateOnly(DateTime.now());
    final items = store.planned
        .where((p) => p.completed == _showCompleted && (_kind == null || p.kind == _kind))
        .toList();

    final sections = <String, List<PlannedItem>>{};
    if (_showCompleted) {
      sections['Tamamlananlar'] = items.reversed.toList();
    } else {
      final weekEnd = today.add(const Duration(days: 7));
      final monthEnd = today.add(const Duration(days: 30));
      for (final p in items) {
        final d = dateOnly(p.dueDate);
        final key = d.isBefore(today)
            ? 'Gecikmiş'
            : d == today
                ? 'Bugün'
                : !d.isAfter(weekEnd)
                    ? 'Bu hafta'
                    : !d.isAfter(monthEnd)
                        ? '30 gün içinde'
                        : 'Daha sonra';
        sections.putIfAbsent(key, () => []).add(p);
      }
    }

    // Önümüzdeki 30 günün toplamları (tekrarlar dahil).
    var inflow = 0, outflow = 0;
    for (final e in upcomingEvents(store.planned, today, today.add(const Duration(days: 30)))) {
      if (e.item.kind == PlannedKind.collection) {
        inflow += store.plannedTry(e.item);
      } else {
        outflow += store.plannedTry(e.item);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yaklaşan Ödeme ve Tahsilatlar')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => pushPage(
          context,
          PlannedFormPage(initialKind: _kind ?? PlannedKind.payment),
        ),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Planla'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(child: _summary(context, 'Beklenen tahsilat (30 gün)', inflow, fc.income)),
                  const SizedBox(width: 12),
                  Expanded(child: _summary(context, 'Beklenen ödeme (30 gün)', outflow, fc.expense)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (k, label) in [
                    (null, 'Tümü'),
                    (PlannedKind.collection, 'Tahsilatlar'),
                    (PlannedKind.payment, 'Ödemeler'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                  FilterChip(
                    label: const Text('Tamamlananlar'),
                    selected: _showCompleted,
                    onSelected: (v) => setState(() => _showCompleted = v),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'Planlı kalem yok',
                  message: 'Kira, maaş, vergi, kredi taksiti gibi düzenli ödemeleri ve '
                      'müşteri tahsilatlarını planlayın; nakit akışı tahmini bunlarla hesaplanır.',
                ),
              ),
            for (final s in sections.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(
                  children: [
                    Text(
                      s.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: s.key == 'Gecikmiş' ? fc.expense : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${s.value.length}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              for (final p in s.value) PlannedTile(p, onTap: () => _actions(context, p)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, String label, int v, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Money(v, color: color, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );

  Future<void> _actions(BuildContext context, PlannedItem p) async {
    final store = context.read<FinanceStore>();
    final isIn = p.kind == PlannedKind.collection;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!p.completed)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(isIn ? 'Tahsil edildi' : 'Ödendi'),
                subtitle: const Text('Hesaba işlem olarak kaydedilir'),
                onTap: () => Navigator.pop(ctx, 'complete'),
              ),
            if (!p.completed && p.recurrence != Recurrence.none)
              ListTile(
                leading: const Icon(Icons.skip_next_outlined),
                title: const Text('Bu vadeyi atla'),
                onTap: () => Navigator.pop(ctx, 'skip'),
              ),
            if (p.completed)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Tekrar aç'),
                onTap: () => Navigator.pop(ctx, 'reopen'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Sil'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'complete':
        await showCompletePlanned(context, p);
      case 'skip':
        store.skipPlanned(p);
      case 'reopen':
        store.upsertPlanned(p.copyWith(completed: false));
      case 'edit':
        await pushPage(context, PlannedFormPage(existing: p));
      case 'delete':
        if (await confirm(context, title: 'Planlı kalemi sil', message: '"${p.title}" silinecek.')) {
          store.deletePlanned(p.id);
        }
    }
  }
}
