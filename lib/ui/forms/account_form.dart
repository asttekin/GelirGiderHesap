import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/currency.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../widgets/common.dart';
import 'fields.dart';

/// Banka hesabı / kasa / kredi kartı ekleme ve düzenleme.
class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key, this.existing});
  final Account? existing;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bank;
  late final TextEditingController _iban;
  late final TextEditingController _opening;
  late AccountType _type;
  late int _color;
  late bool _archived;
  late String _currency;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _bank = TextEditingController(text: e?.bankName ?? '');
    _iban = TextEditingController(text: e?.iban ?? '');
    _opening = TextEditingController(text: e == null ? '' : fmtAmountInput(e.openingBalance));
    _type = e?.type ?? AccountType.bank;
    _color = e?.colorValue ?? pickerColors.first;
    _archived = e?.archived ?? false;
    _currency = e?.currency ?? 'TRY';
  }

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _iban.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final e = widget.existing;
    final a = Account(
      id: e?.id ?? newId(),
      name: _name.text.trim(),
      type: _type,
      bankName: _bank.text.trim(),
      iban: _iban.text.trim().toUpperCase(),
      openingBalance: parseAmount(_opening.text) ?? 0,
      colorValue: _color,
      archived: _archived,
      currency: _currency,
    );
    context.read<FinanceStore>().upsertAccount(a);
    toast(context, e == null ? 'Hesap eklendi' : 'Hesap güncellendi');
    Navigator.pop(context, a);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Hesabı sil',
      message: 'İşlem geçmişi olan hesaplar silinmez, arşivlenir. Devam edilsin mi?',
    );
    if (!ok || !mounted) return;
    final deleted = context.read<FinanceStore>().deleteAccount(widget.existing!.id);
    toast(context, deleted ? 'Hesap silindi' : 'Hesap arşivlendi');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final showBank = _type != AccountType.cash;
    return FormScaffold(
      title: widget.existing == null ? 'Yeni hesap' : 'Hesabı düzenle',
      formKey: _form,
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in AccountType.values)
              ChoiceChip(
                avatar: Icon(iconForAccount(t), size: 18),
                label: Text(accountTypeLabel(t)),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Hesap adı', prefixIcon: Icon(Icons.label_outline)),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Hesap adı girin' : null,
        ),
        if (showBank)
          TextFormField(
            controller: _bank,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Banka', prefixIcon: Icon(Icons.account_balance_outlined)),
          ),
        if (showBank && _type != AccountType.creditCard)
          TextFormField(
            controller: _iban,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'IBAN', prefixIcon: Icon(Icons.numbers)),
            validator: (v) {
              final s = (v ?? '').replaceAll(' ', '');
              if (s.isEmpty) return null;
              return RegExp(r'^[A-Za-z]{2}\d{2}[A-Za-z0-9]{10,30}$').hasMatch(s) ? null : 'IBAN biçimi geçersiz';
            },
          ),
        Builder(builder: (context) {
          final store = context.read<FinanceStore>();
          final e = widget.existing;
          final locked = e != null && store.txns.any((t) => t.accountId == e.id || t.toAccountId == e.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: [
                  for (final c in currencyCodes)
                    ButtonSegment(value: c, label: Text('${currencySymbol(c)} $c')),
                ],
                selected: {_currency},
                onSelectionChanged: locked ? null : (v) => setState(() => _currency = v.first),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'İşlemi olan hesabın para birimi değiştirilemez.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          );
        }),
        AmountField(
          currency: _currency,
          controller: _opening,
          label: _type == AccountType.creditCard ? 'Açılış bakiyesi (borç için eksi)' : 'Açılış bakiyesi',
          allowNegative: true,
          allowZero: true,
        ),
        Text('Renk', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in pickerColors)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(c),
                  child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              ),
          ],
        ),
        if (widget.existing != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Arşivlendi'),
            subtitle: const Text('Arşivlenen hesaplar toplam bakiyeye dahil edilmez.'),
            value: _archived,
            onChanged: (v) => setState(() => _archived = v),
          ),
      ],
    );
  }
}
