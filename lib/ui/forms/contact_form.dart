import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../widgets/common.dart';
import 'fields.dart';

/// Cari hesap (müşteri / tedarikçi) ekleme ve düzenleme.
class ContactFormPage extends StatefulWidget {
  const ContactFormPage({super.key, this.existing});
  final Contact? existing;

  @override
  State<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends State<ContactFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _email, _tax, _note, _opening;
  late ContactType _type;

  /// Açılış bakiyesi yönü: true → cari bize borçlu (alacak).
  late bool _openingIsReceivable;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _tax = TextEditingController(text: e?.taxNumber ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    final ob = e?.openingBalance ?? 0;
    _opening = TextEditingController(text: ob == 0 ? '' : fmtAmountInput(ob.abs()));
    _openingIsReceivable = ob >= 0;
    _type = e?.type ?? ContactType.customer;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _tax, _note, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final e = widget.existing;
    final ob = parseAmount(_opening.text) ?? 0;
    context.read<FinanceStore>().upsertContact(
      Contact(
        id: e?.id ?? newId(),
        name: _name.text.trim(),
        type: _type,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        taxNumber: _tax.text.trim(),
        note: _note.text.trim(),
        openingBalance: _openingIsReceivable ? ob : -ob,
      ),
    );
    toast(context, e == null ? 'Cari eklendi' : 'Cari güncellendi');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Cariyi sil',
      message: 'Cari ve fatura/dekont kayıtları silinecek. Kasa ve banka işlemleri korunur '
          'ancak cari bağlantısı kaldırılır.',
    );
    if (!ok || !mounted) return;
    context.read<FinanceStore>().deleteContact(widget.existing!.id);
    toast(context, 'Cari silindi');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Yeni cari' : 'Cariyi düzenle',
      formKey: _form,
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      children: [
        SegmentedButton<ContactType>(
          segments: [
            for (final t in ContactType.values) ButtonSegment(value: t, label: Text(contactTypeLabel(t))),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Ünvan / ad soyad', prefixIcon: Icon(Icons.badge_outlined)),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Ad girin' : null,
        ),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.alternate_email)),
          validator: (v) {
            final s = (v ?? '').trim();
            return s.isEmpty || s.contains('@') ? null : 'E-posta geçersiz';
          },
        ),
        TextFormField(
          controller: _tax,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Vergi / TC kimlik no', prefixIcon: Icon(Icons.numbers)),
        ),
        AmountField(controller: _opening, label: 'Açılış bakiyesi', allowZero: true),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Cari bize borçlu')),
            ButtonSegment(value: false, label: Text('Biz cariye borçluyuz')),
          ],
          selected: {_openingIsReceivable},
          onSelectionChanged: (s) => setState(() => _openingIsReceivable = s.first),
        ),
        TextFormField(
          controller: _note,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Not', prefixIcon: Icon(Icons.notes)),
        ),
      ],
    );
  }
}
