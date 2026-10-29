import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/currency.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'fields.dart';

/// Yaklaşan ödeme / tahsilat ekleme ve düzenleme.
class PlannedFormPage extends StatefulWidget {
  const PlannedFormPage({
    super.key,
    this.existing,
    this.initialKind = PlannedKind.payment,
    this.contactId,
    this.initialAmount,
    this.initialTitle,
  });

  final PlannedItem? existing;
  final PlannedKind initialKind;
  final String? contactId;
  final int? initialAmount;
  final String? initialTitle;

  @override
  State<PlannedFormPage> createState() => _PlannedFormPageState();
}

class _PlannedFormPageState extends State<PlannedFormPage> {
  final _form = GlobalKey<FormState>();
  late PlannedKind _kind;
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _due;
  DateTime? _end;
  late Recurrence _recurrence;
  String? _accountId;
  String? _categoryId;
  String? _contactId;
  late String _currency;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final accounts = context.read<FinanceStore>().activeAccounts;
    _kind = e?.kind ?? widget.initialKind;
    _title = TextEditingController(text: e?.title ?? widget.initialTitle ?? '');
    final amt = e?.amount ?? widget.initialAmount;
    _amount = TextEditingController(text: amt == null ? '' : fmtAmountInput(amt));
    _note = TextEditingController(text: e?.note ?? '');
    _due = e?.dueDate ?? dateOnly(DateTime.now()).add(const Duration(days: 7));
    _end = e?.endDate;
    _recurrence = e?.recurrence ?? Recurrence.none;
    _accountId = e?.accountId ?? (accounts.isEmpty ? null : accounts.first.id);
    _categoryId = e?.categoryId;
    _contactId = e?.contactId ?? widget.contactId;
    _currency = e?.currency ?? context.read<FinanceStore>().account(_accountId)?.currency ?? 'TRY';
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final e = widget.existing;
    context.read<FinanceStore>().upsertPlanned(
      PlannedItem(
        id: e?.id ?? newId(),
        kind: _kind,
        title: _title.text.trim(),
        amount: parseAmount(_amount.text)!,
        dueDate: dateOnly(_due),
        accountId: _accountId,
        categoryId: _categoryId,
        contactId: _contactId,
        note: _note.text.trim(),
        recurrence: _recurrence,
        endDate: _recurrence == Recurrence.none || _end == null ? null : dateOnly(_end!),
        completed: e?.completed ?? false,
        currency: _currency,
      ),
    );
    toast(context, e == null ? 'Planlı kalem eklendi' : 'Planlı kalem güncellendi');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Planlı kalemi sil',
      message: 'Bu kalem ve (tekrarlıysa) gelecekteki tüm vadeleri silinecek. '
          'Daha önce gerçekleşen işlemler korunur.',
    );
    if (!ok || !mounted) return;
    context.read<FinanceStore>().deletePlanned(widget.existing!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final isIn = _kind == PlannedKind.collection;
    final cats = store.categoriesOf(isIn ? CategoryKind.income : CategoryKind.expense);
    return FormScaffold(
      title: widget.existing == null
          ? (isIn ? 'Yeni planlı tahsilat' : 'Yeni planlı ödeme')
          : 'Planlı kalemi düzenle',
      formKey: _form,
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      children: [
        SegmentedButton<PlannedKind>(
          segments: const [
            ButtonSegment(value: PlannedKind.collection, label: Text('Tahsilat'), icon: Icon(Icons.south_west)),
            ButtonSegment(value: PlannedKind.payment, label: Text('Ödeme'), icon: Icon(Icons.north_east)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            _categoryId = null;
          }),
        ),
        TextFormField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Başlık', prefixIcon: Icon(Icons.title)),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Başlık girin' : null,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AmountField(controller: _amount, color: isIn ? fc.income : fc.expense, currency: _currency),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 104,
              child: PickField<String>(
                label: 'Birim',
                value: _currency,
                items: [for (final c in currencyCodes) (c, '${currencySymbol(c)} $c')],
                onChanged: (v) => setState(() => _currency = v ?? 'TRY'),
              ),
            ),
          ],
        ),
        if (_currency != 'TRY')
          Text(
            '≈ ${fmtMoney(store.rates.toTry(parseAmount(_amount.text) ?? 0, _currency))} (güncel kurla)',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        DateField(label: 'Vade tarihi', value: _due, onChanged: (d) => setState(() => _due = d)),
        PickField<Recurrence>(
          label: 'Tekrar',
          icon: Icons.repeat,
          value: _recurrence,
          items: [for (final r in Recurrence.values) (r, recurrenceLabel(r))],
          onChanged: (v) => setState(() => _recurrence = v ?? Recurrence.none),
        ),
        if (_recurrence != Recurrence.none)
          DateField(
            label: 'Son vade (isteğe bağlı)',
            icon: Icons.event_busy_outlined,
            value: _end,
            firstDate: _due,
            onChanged: (d) => setState(() => _end = d),
            onClear: () => setState(() => _end = null),
          ),
        PickField<String?>(
          label: 'Hesap',
          icon: Icons.account_balance_wallet_outlined,
          value: _accountId,
          items: [(null, '—'), for (final a in store.activeAccounts) (a.id, '${a.name} (${a.currency})')],
          onChanged: (v) => setState(() {
            _accountId = v;
            final c = store.account(v)?.currency;
            if (c != null) _currency = c;
          }),
        ),
        PickField<String?>(
          label: 'Kategori',
          icon: Icons.category_outlined,
          value: _categoryId,
          items: [(null, '—'), for (final c in cats) (c.id, c.name)],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        PickField<String?>(
          label: 'Cari hesap',
          icon: Icons.people_outline,
          value: _contactId,
          items: [(null, '—'), for (final c in store.contacts) (c.id, c.name)],
          onChanged: (v) => setState(() => _contactId = v),
        ),
        TextFormField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Not', prefixIcon: Icon(Icons.notes)),
        ),
      ],
    );
  }
}

/// Planlı kalemi gerçekleştirme sayfası (tutar / hesap / tarih onayı).
Future<void> showCompletePlanned(BuildContext context, PlannedItem item) async {
  final store = context.read<FinanceStore>();
  final accounts = store.activeAccounts;
  if (accounts.isEmpty) {
    toast(context, 'Önce bir hesap ekleyin');
    return;
  }
  // Önce kalemin para birimindeki hesabı öner.
  var accountId = accounts.any((a) => a.id == item.accountId)
      ? item.accountId!
      : (accounts.where((a) => a.currency == item.currency).firstOrNull ?? accounts.first).id;
  String curOf(String id) => store.account(id)?.currency ?? 'TRY';
  final amount = TextEditingController(
    text: fmtAmountInput(store.rates.convert(item.amount, item.currency, curOf(accountId))),
  );
  var date = DateTime.now();
  final formKey = GlobalKey<FormState>();
  final isIn = item.kind == PlannedKind.collection;

  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Form(
            key: formKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isIn ? 'Tahsilatı kaydet' : 'Ödemeyi kaydet',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(item.title, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  AmountField(controller: amount, currency: curOf(accountId)),
                  if (curOf(accountId) != item.currency)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Planlanan: ${fmtMoney(item.amount, currency: item.currency)} — güncel kurla çevrildi',
                        style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 12),
                  PickField<String>(
                    label: isIn ? 'Paranın girdiği hesap' : 'Ödemenin yapıldığı hesap',
                    icon: Icons.account_balance_wallet_outlined,
                    value: accountId,
                    items: [for (final a in accounts) (a.id, '${a.name} (${a.currency})')],
                    onChanged: (v) => setState(() {
                      accountId = v ?? accountId;
                      amount.text =
                          fmtAmountInput(store.rates.convert(item.amount, item.currency, curOf(accountId)));
                    }),
                  ),
                  const SizedBox(height: 12),
                  DateField(label: 'İşlem tarihi', value: date, onChanged: (d) => setState(() => date = d)),
                  if (item.recurrence != Recurrence.none) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sonraki vade: ${fmtDate(nextOccurrence(item.dueDate, item.recurrence))}',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Gerçekleşti olarak işaretle'),
                      onPressed: () {
                        if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (done == true) {
    store.completePlanned(
      item,
      accountId: accountId,
      date: withCurrentTime(date),
      amount: parseAmount(amount.text),
    );
    if (context.mounted) toast(context, isIn ? 'Tahsilat kaydedildi' : 'Ödeme kaydedildi');
  }
}
