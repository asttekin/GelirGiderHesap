import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'contact_form.dart';
import 'fields.dart';

/// Cari hareketi: satış faturası (cari borçlanır) veya alış faturası
/// (biz borçlanırız). Kasa/banka bakiyesini etkilemez; isteğe bağlı olarak
/// vadesine planlı tahsilat/ödeme oluşturur.
class ContactEntryFormPage extends StatefulWidget {
  const ContactEntryFormPage({super.key, this.existing, this.contactId, this.initialType});
  final ContactEntry? existing;
  final String? contactId;
  final EntryType? initialType;

  @override
  State<ContactEntryFormPage> createState() => _ContactEntryFormPageState();
}

class _ContactEntryFormPageState extends State<ContactEntryFormPage> {
  final _form = GlobalKey<FormState>();
  late EntryType _type;
  late final TextEditingController _amount, _note;
  late DateTime _date;
  String? _contactId;
  bool _plan = false;
  DateTime _due = dateOnly(DateTime.now()).add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final store = context.read<FinanceStore>();
    _contactId = e?.contactId ?? widget.contactId;
    final c = store.contact(_contactId);
    _type = e?.type ??
        widget.initialType ??
        (c?.type == ContactType.supplier ? EntryType.purchase : EntryType.sale);
    _amount = TextEditingController(text: e == null ? '' : fmtAmountInput(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? DateTime.now();
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
    final amount = parseAmount(_amount.text)!;
    final note = _note.text.trim();
    store.upsertEntry(
      ContactEntry(
        id: e?.id ?? newId(),
        contactId: _contactId!,
        type: _type,
        amount: amount,
        date: e != null && dateOnly(e.date) == dateOnly(_date) ? e.date : withCurrentTime(_date),
        note: note,
      ),
    );
    if (e == null && _plan) {
      final c = store.contact(_contactId)!;
      final sale = _type == EntryType.sale;
      store.upsertPlanned(
        PlannedItem(
          id: newId(),
          kind: sale ? PlannedKind.collection : PlannedKind.payment,
          title: '${c.name} ${sale ? 'tahsilatı' : 'ödemesi'}${note.isEmpty ? '' : ' – $note'}',
          amount: amount,
          dueDate: dateOnly(_due),
          contactId: c.id,
          accountId: store.activeAccounts.isEmpty ? null : store.activeAccounts.first.id,
          categoryId: sale ? 'inc_sales' : 'exp_purchase',
        ),
      );
    }
    toast(context, 'Cari hareketi kaydedildi');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'Kaydı sil', message: 'Bu cari hareketi silinecek.');
    if (!ok || !mounted) return;
    context.read<FinanceStore>().deleteEntry(widget.existing!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final contacts = store.contacts;
    if (contacts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cari hareketi')),
        body: EmptyState(
          icon: Icons.people_outline,
          title: 'Henüz cari yok',
          message: 'Fatura kaydetmek için önce bir müşteri veya tedarikçi ekleyin.',
          action: FilledButton.icon(
            onPressed: () => pushPage(context, const ContactFormPage()),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Cari ekle'),
          ),
        ),
      );
    }
    final sale = _type == EntryType.sale;
    return FormScaffold(
      title: widget.existing == null ? 'Yeni cari hareketi' : 'Cari hareketini düzenle',
      formKey: _form,
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      children: [
        SegmentedButton<EntryType>(
          segments: const [
            ButtonSegment(value: EntryType.sale, label: Text('Satış faturası'), icon: Icon(Icons.outbox_outlined)),
            ButtonSegment(value: EntryType.purchase, label: Text('Alış faturası'), icon: Icon(Icons.move_to_inbox_outlined)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        Text(
          sale
              ? 'Cariye borç yazılır (alacağınız artar). Kasa/banka bakiyesi değişmez.'
              : 'Cariye alacak yazılır (borcunuz artar). Kasa/banka bakiyesi değişmez.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        PickField<String>(
          label: 'Cari',
          icon: Icons.people_outline,
          value: _contactId,
          items: [for (final c in contacts) (c.id, c.name)],
          onChanged: (v) => setState(() => _contactId = v),
          validator: (v) => v == null ? 'Cari seçin' : null,
        ),
        AmountField(controller: _amount, autofocus: widget.existing == null, color: sale ? fc.income : fc.expense),
        DateField(label: 'Fatura tarihi', value: _date, onChanged: (d) => setState(() => _date = d)),
        TextFormField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Açıklama / fatura no', prefixIcon: Icon(Icons.notes)),
        ),
        if (widget.existing == null) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(sale ? 'Vadesine tahsilat planla' : 'Vadesine ödeme planla'),
            subtitle: const Text('Yaklaşan ödemeler / tahsilatlar listesine eklenir.'),
            value: _plan,
            onChanged: (v) => setState(() => _plan = v),
          ),
          if (_plan)
            DateField(label: 'Vade tarihi', value: _due, onChanged: (d) => setState(() => _due = d)),
        ],
      ],
    );
  }
}
