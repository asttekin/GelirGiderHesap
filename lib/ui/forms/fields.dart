import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/currency.dart';
import '../../logic/finance_math.dart';
import '../format.dart';

/// Tutar girişi. Değer kuruş olarak [parseAmount] ile okunur.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Tutar',
    this.allowNegative = false,
    this.allowZero = false,
    this.autofocus = false,
    this.color,
    this.currency = 'TRY',
  });

  final TextEditingController controller;
  final String currency;
  final String label;
  final bool allowNegative;
  final bool allowZero;
  final bool autofocus;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: allowNegative),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allowNegative ? r'[0-9.,\- ]' : r'[0-9., ]'))],
    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color),
    decoration: InputDecoration(
      labelText: label,
      prefixText: '${currencySymbol(currency)} ',
      prefixStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color),
      hintText: '0,00',
    ),
    validator: (v) {
      final a = parseAmount(v ?? '');
      if (a == null) return allowZero && (v ?? '').trim().isEmpty ? null : 'Geçerli bir tutar girin';
      if (!allowNegative && a < 0) return 'Tutar negatif olamaz';
      if (!allowZero && a == 0) return 'Tutar sıfırdan büyük olmalı';
      return null;
    },
  );
}

/// Tarih seçici satırı.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.event_outlined,
    this.firstDate,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final IconData icon;
  final DateTime? firstDate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () async {
      final now = DateTime.now();
      final d = await showDatePicker(
        context: context,
        initialDate: value ?? now,
        firstDate: firstDate ?? DateTime(now.year - 20),
        lastDate: DateTime(now.year + 20),
      );
      if (d != null) onChanged(d);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: value != null && onClear != null
            ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
            : null,
      ),
      child: Text(value == null ? 'Seçilmedi' : fmtDateLong(value!)),
    ),
  );
}

/// Basit açılır liste. [items] (değer, etiket) çiftleridir.
class PickField<T> extends StatelessWidget {
  const PickField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.validator,
  });

  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: items.any((i) => i.$1 == value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
    items: [
      for (final i in items)
        DropdownMenuItem(value: i.$1, child: Text(i.$2, overflow: TextOverflow.ellipsis)),
    ],
    onChanged: onChanged,
    validator: validator,
  );
}

/// Form sayfalarının ortak iskeleti: kaydet düğmesi altta sabit.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSave,
    this.onDelete,
    this.saveLabel = 'Kaydet',
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final String saveLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        if (onDelete != null)
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
      ],
    ),
    body: Form(
      key: formKey,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check),
                label: Text(saveLabel),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Seçili tarihi koruyarak saat bilgisini şimdiki saate ayarlar; aynı güne
/// girilen işlemler giriş sırasıyla listelenir.
DateTime withCurrentTime(DateTime day) {
  final now = DateTime.now();
  return DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second);
}

DateTime normalizeDay(DateTime d) => dateOnly(d);
