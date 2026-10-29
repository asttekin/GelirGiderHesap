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
  late final TextEditingController _rate;
  late final TextEditingController _toAmount;

  /// Kullanıcı karşı tutarı elle değiştirdiyse otomatik hesaplama durur.
  bool _toEdited = false;
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
    final cur = store.account(_accountId)?.currency ?? 'TRY';
    _rate = TextEditingController(
      text: fmtRate(e != null && e.currency != 'TRY' ? e.rate : store.rates.of(cur)),
    );
    _toAmount = TextEditingController(text: e?.toAmount == null ? '' : fmtAmountInput(e!.toAmount!));
    _toEdited = e?.toAmount != null;
    _amount.addListener(_recalc);
    _rate.addListener(_recalc);
  }

  String _currencyOf(String? accountId) =>
      context.read<FinanceStore>().account(accountId)?.currency ?? 'TRY';

  String get _cur => _currencyOf(_accountId);
  String get _toCur => _currencyOf(_toAccountId);
  bool get _crossCurrency => _type == TxnType.transfer && _toAccountId != null && _cur != _toCur;

  /// Girilen kur (yoksa güncel kur).
  double get _enteredRate =>
      _cur == 'TRY' ? 1 : (parseRate(_rate.text) ?? context.read<FinanceStore>().rates.of(_cur));

  /// Hesap seçimi veya tutar değişince kur / karşı tutar alanlarını günceller.
  void _recalc() {
    if (!mounted) return;
    final rates = context.read<FinanceStore>().rates;
    if (_crossCurrency && !_toEdited) {
      final a = parseAmount(_amount.text);
      final tryValue = a == null ? null : (a * _enteredRate).round();
      final text = tryValue == null ? '' : fmtAmountInput(rates.fromTry(tryValue, _toCur));
      if (_toAmount.text != text) _toAmount.text = text;
    }
    setState(() {});
  }

  void _onAccountChanged() {
    final rates = context.read<FinanceStore>().rates;
    _rate.text = fmtRate(rates.of(_cur));
    _recalc();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _rate.dispose();
    _toAmount.dispose();
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
        currency: _cur,
        rate: _enteredRate,
        toAmount: _crossCurrency ? parseAmount(_toAmount.text) : null,
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
        AmountField(controller: _amount, autofocus: widget.existing == null, color: color, currency: _cur),
        DateField(label: 'Tarih', value: _date, onChanged: (d) => setState(() => _date = d)),
        PickField<String>(
          label: _type == TxnType.transfer ? 'Çıkış hesabı' : 'Hesap',
          icon: Icons.account_balance_wallet_outlined,
          value: _accountId,
          items: [for (final a in accounts) (a.id, a.name)],
          onChanged: (v) {
            _accountId = v;
            _onAccountChanged();
          },
          validator: (v) => v == null ? 'Hesap seçin' : null,
        ),
        if (_cur != 'TRY')
          _RateRow(
            controller: _rate,
            currency: _cur,
            amount: parseAmount(_amount.text),
            onUseCurrent: () => _rate.text = fmtRate(store.rates.of(_cur)),
          ),
        if (_type == TxnType.transfer)
          PickField<String>(
            label: 'Giriş hesabı',
            icon: Icons.login,
            value: _toAccountId,
            items: [for (final a in accounts) if (a.id != _accountId) (a.id, a.name)],
            onChanged: (v) {
              _toAccountId = v;
              _toEdited = false;
              _recalc();
            },
            validator: (v) => v == null
                ? 'Hedef hesap seçin'
                : (v == _accountId ? 'Aynı hesaba transfer yapılamaz' : null),
          ),
        if (_crossCurrency)
          Focus(
            onFocusChange: (f) {
              if (f) _toEdited = true;
            },
            child: AmountField(
              controller: _toAmount,
              label: 'Giriş hesabına geçen tutar (${currencySymbol(_toCur)})',
              currency: _toCur,
              color: color,
            ),
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

/// Döviz işleminde kur girişi ve ₺ karşılığı.
class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.controller,
    required this.currency,
    required this.amount,
    required this.onUseCurrent,
  });

  final TextEditingController controller;
  final String currency;
  final int? amount;
  final VoidCallback onUseCurrent;

  @override
  Widget build(BuildContext context) {
    final rates = context.watch<FinanceStore>().rates;
    final r = parseRate(controller.text);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Kur (1 $currency = ? ₺)',
            prefixIcon: const Icon(Icons.currency_exchange),
            suffixIcon: IconButton(
              tooltip: 'Güncel kuru kullan',
              icon: const Icon(Icons.refresh),
              onPressed: onUseCurrent,
            ),
          ),
          validator: (v) => parseRate(v ?? '') == null ? 'Geçerli bir kur girin' : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            [
              if (amount != null && r != null) '≈ ${fmtMoney((amount! * r).round())}',
              'Güncel: ${fmtRate(rates.of(currency))} ₺ · ${rates.source}',
            ].join('   ·   '),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
