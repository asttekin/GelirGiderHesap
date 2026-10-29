import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../forms/contact_entry_form.dart';
import '../forms/planned_form.dart';
import '../forms/txn_form.dart';
import '../theme.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Sil',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void toast(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action, behavior: SnackBarBehavior.floating));
}

/// İçeriği geniş ekranlarda ortalayıp genişliğini sınırlar.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1180});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(icon, size: 34, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Renkli yuvarlak ikon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, this.color, {super.key, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Icon(icon, color: color, size: size * 0.55),
  );
}

/// İşlem satırı.
class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {super.key, this.perspectiveAccountId, this.showDate = true});
  final Txn txn;

  /// Hesap detayında transferin yönünü göstermek için.
  final String? perspectiveAccountId;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FinanceStore>();
    final fc = FinColors.of(context);
    final cat = store.category(txn.categoryId);
    final acc = store.account(txn.accountId);
    final contact = store.contact(txn.contactId);

    final IconData icon;
    final Color color;
    final String title;
    final int signed;
    switch (txn.type) {
      case TxnType.transfer:
        icon = Icons.swap_horiz;
        color = fc.transfer;
        final to = store.account(txn.toAccountId);
        title = txn.note.isNotEmpty ? txn.note : 'Transfer';
        signed = perspectiveAccountId == null ? 0 : txnEffectOn(txn, perspectiveAccountId!);
        final sub = '${acc?.name ?? '?'} → ${to?.name ?? '?'}';
        return _tile(context, icon, color, title, sub, signed, neutral: perspectiveAccountId == null);
      case TxnType.income:
        icon = iconForCategory(cat);
        color = cat != null ? Color(cat.colorValue) : fc.income;
        signed = txn.amount;
      case TxnType.expense:
        icon = iconForCategory(cat);
        color = cat != null ? Color(cat.colorValue) : fc.expense;
        signed = -txn.amount;
    }
    title = txn.note.isNotEmpty ? txn.note : (cat?.name ?? (txn.type == TxnType.income ? 'Gelir' : 'Gider'));
    final parts = [
      if (cat != null && txn.note.isNotEmpty) cat.name,
      ?contact?.name,
      ?acc?.name,
    ];
    return _tile(context, icon, color, title, parts.join(' · '), signed);
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    int signed, {
    bool neutral = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: IconBadge(icon, color),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          neutral
              ? Money(txn.amount, style: const TextStyle(fontWeight: FontWeight.w600))
              : Money(signed, colored: true, signed: true, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (showDate)
            Text(fmtDateShort(txn.date), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
      onTap: () => pushPage(context, TxnFormPage(existing: txn)),
    );
  }
}

/// Vade çipi: gecikmiş kırmızı, 3 gün içinde turuncu.
class DueChip extends StatelessWidget {
  const DueChip(this.due, {super.key});
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final diff = dateOnly(due).difference(dateOnly(DateTime.now())).inDays;
    final color = diff < 0 ? fc.expense : (diff <= 3 ? fc.warning : scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        fmtDue(due),
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Gelir / gider / transfer / planlı kalem / cari hareket ekleme menüsü.
Future<void> showQuickAdd(BuildContext context) async {
  final fc = FinColors.of(context);
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickItem(Icons.south_west, 'Gelir', fc.income, () => Navigator.pop(ctx, 0)),
            _QuickItem(Icons.north_east, 'Gider', fc.expense, () => Navigator.pop(ctx, 1)),
            _QuickItem(Icons.swap_horiz, 'Transfer', fc.transfer, () => Navigator.pop(ctx, 2)),
            _QuickItem(Icons.event_available, 'Planlı tahsilat', fc.income, () => Navigator.pop(ctx, 3)),
            _QuickItem(Icons.event_busy, 'Planlı ödeme', fc.expense, () => Navigator.pop(ctx, 4)),
            _QuickItem(Icons.request_quote_outlined, 'Cari fatura', fc.warning, () => Navigator.pop(ctx, 5)),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final page = switch (choice) {
    0 => const TxnFormPage(initialType: TxnType.income),
    1 => const TxnFormPage(initialType: TxnType.expense),
    2 => const TxnFormPage(initialType: TxnType.transfer),
    3 => const PlannedFormPage(initialKind: PlannedKind.collection),
    4 => const PlannedFormPage(initialKind: PlannedKind.payment),
    _ => const ContactEntryFormPage(),
  };
  await pushPage(context, page);
}

class _QuickItem extends StatelessWidget {
  const _QuickItem(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            IconBadge(icon, color, size: 52),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

class QuickAddFab extends StatelessWidget {
  const QuickAddFab({super.key});

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    heroTag: null,
    onPressed: () => showQuickAdd(context),
    icon: const Icon(Icons.add),
    label: const Text('Ekle'),
  );
}

/// Planlı kalem satırı.
class PlannedTile extends StatelessWidget {
  const PlannedTile(this.item, {super.key, this.date, this.onTap});
  final PlannedItem item;

  /// Gösterilecek vade (projeksiyondaki tekrar için). Yoksa [PlannedItem.dueDate].
  final DateTime? date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FinanceStore>();
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isIn = item.kind == PlannedKind.collection;
    final contact = store.contact(item.contactId);
    final due = date ?? item.dueDate;
    final sub = [
      fmtDate(due),
      if (item.recurrence != Recurrence.none) recurrenceLabel(item.recurrence),
      ?contact?.name,
    ].join(' · ');
    return ListTile(
      leading: IconBadge(isIn ? Icons.south_west : Icons.north_east, isIn ? fc.income : fc.expense),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Money(item.signedAmount, colored: true, signed: true,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          if (!item.completed) DueChip(due),
        ],
      ),
      onTap: onTap,
    );
  }
}
