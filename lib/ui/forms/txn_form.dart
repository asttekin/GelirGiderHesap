import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_form.dart';
import 'fields.dart';

/// Gelir / gider / transfer ekleme ve düzenleme.
class TxnFormPage extends StatefulWidget {
  const TxnFormPage({
    super.key,
    this.existing,
    this.initialType = TxnType.expense,
    this.accountId,
    this.contactId,
  });

  final Txn? existing;
  final TxnType initialType;
  final String? accountId;
  final String? contactId;

  @override
  State<TxnFormPage> createState() => _TxnFormPageState();
}

class _TxnFormPageState extends State<TxnFormPage> {
  final _form = GlobalKey<FormState>();
  late TxnType _type;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _contactId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final store = context.read<FinanceStore>();
    final accounts = store.activeAccounts;
    _type = e?.type ?? widget.initialType;
    _amount = TextEditingController(text: e == null ? '' : fmtAmountInput(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? DateTime.now();
    _accountId = e?.accountId ?? widget.accountId ?? (accounts.isEmpty ? null : accounts.first.id);
    _toAccountId = e?.toAccountId;
    _categoryId = e?.categoryId;
    _contactId = e?.contactId ?? widget.contactId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final store = context.read<FinanceStore>();
    final e = widget.existing;
    final sameDay = e != null && dateOnly(e.date) == dateOnly(_date);
    store.upsertTxn(
      Txn(
        id: e?.id ?? newId(),
        type: _type,
        amount: parseAmount(_amount.text)!,
        date: sameDay ? e.date : withCurrentTime(_date),
        accountId: _accountId!,
        toAccountId: _type == TxnType.transfer ? _toAccountId : null,
        categoryId: _type == TxnType.transfer ? null : _categoryId,
        contactId: _type == TxnType.transfer ? null : _contactId,
        note: _note.text.trim(),
        plannedId: e?.plannedId,
      ),
    );
    toast(context, e == null ? 'İşlem eklendi' : 'İşlem güncellendi');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'İşlemi sil', message: 'Bu işlem kalıcı olarak silinecek.');
    if (!ok || !mounted) return;
    context.read<FinanceStore>().deleteTxn(widget.existing!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final accounts = [
      for (final a in store.accounts)
        if (!a.archived || a.id == _accountId || a.id == _toAccountId) a,
    ];
    final color = switch (_type) {
      TxnType.income => fc.income,
      TxnType.expense => fc.expense,
      TxnType.transfer => fc.transfer,
    };
    final cats = store.categoriesOf(_type == TxnType.income ? CategoryKind.income : CategoryKind.expense);

    if (accounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yeni işlem')),
        body: EmptyState(
          icon: Icons.account_balance_outlined,
          title: 'Önce bir hesap ekleyin',
          message: 'İşlemler bir banka hesabı, kasa veya kredi kartına kaydedilir.',
          action: FilledButton.icon(
            onPressed: () => pushPage(context, const AccountFormPage()),
            icon: const Icon(Icons.add),
            label: const Text('Hesap ekle'),
          ),
        ),
      );
    }

    return FormScaffold(
      title: widget.existing == null ? 'Yeni işlem' : 'İşlemi düzenle',
      formKey: _form,
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      children: [
        SegmentedButton<TxnType>(
          segments: const [
            ButtonSegment(value: TxnType.income, label: Text('Gelir'), icon: Icon(Icons.south_west)),
            ButtonSegment(value: TxnType.expense, label: Text('Gider'), icon: Icon(Icons.north_east)),
            ButtonSegment(value: TxnType.transfer, label: Text('Transfer'), icon: Icon(Icons.swap_horiz)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() {
            _type = s.first;
            if (store.category(_categoryId)?.kind !=
                (_type == TxnType.income ? CategoryKind.income : CategoryKind.expense)) {
              _categoryId = null;
            }
          }),
        ),
        AmountField(controller: _amount, autofocus: widget.existing == null, color: color),
        DateField(label: 'Tarih', value: _date, onChanged: (d) => setState(() => _date = d)),
        PickField<String>(
          label: _type == TxnType.transfer ? 'Çıkış hesabı' : 'Hesap',
          icon: Icons.account_balance_wallet_outlined,
          value: _accountId,
          items: [for (final a in accounts) (a.id, a.name)],
          onChanged: (v) => setState(() => _accountId = v),
          validator: (v) => v == null ? 'Hesap seçin' : null,
        ),
        if (_type == TxnType.transfer)
          PickField<String>(
            label: 'Giriş hesabı',
            icon: Icons.login,
            value: _toAccountId,
            items: [for (final a in accounts) if (a.id != _accountId) (a.id, a.name)],
            onChanged: (v) => setState(() => _toAccountId = v),
            validator: (v) => v == null
                ? 'Hedef hesap seçin'
                : (v == _accountId ? 'Aynı hesaba transfer yapılamaz' : null),
          ),
        if (_type != TxnType.transfer) ...[
          Text('Kategori', style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                ChoiceChip(
                  avatar: Icon(iconForCategory(c), size: 18, color: Color(c.colorValue)),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (s) => setState(() => _categoryId = s ? c.id : null),
                ),
            ],
          ),
          PickField<String?>(
            label: 'Cari hesap (isteğe bağlı)',
            icon: Icons.people_outline,
            value: _contactId,
            items: [(null, '—'), for (final c in store.contacts) (c.id, c.name)],
            onChanged: (v) => setState(() => _contactId = v),
          ),
        ],
        TextFormField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Açıklama', prefixIcon: Icon(Icons.notes)),
        ),
        if (_contactId != null && _type != TxnType.transfer)
          Text(
            _type == TxnType.income
                ? 'Bu tahsilat carinin borcundan düşülecek.'
                : 'Bu ödeme cariye olan borcunuzdan düşülecek.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
