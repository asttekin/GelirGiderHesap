import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_prefs.dart';
import '../logic/currency.dart';
import '../logic/finance_math.dart';
import 'theme.dart';

final _money = {
  for (final c in currencyCodes)
    c: NumberFormat.currency(locale: 'tr_TR', symbol: currencySymbol(c), decimalDigits: 2),
};
final _moneyCompact = {
  for (final c in currencyCodes)
    c: NumberFormat.compactCurrency(locale: 'tr_TR', symbol: currencySymbol(c), decimalDigits: 1),
};
final _amountInput = NumberFormat.decimalPatternDigits(locale: 'tr_TR', decimalDigits: 2);
final _rateFmt = NumberFormat.decimalPatternDigits(locale: 'tr_TR', decimalDigits: 4);

/// Kuruş → "₺1.234,56" ([currency] `USD` ise "$1.234,56").
/// [signed] ise pozitif değerlerin önüne "+" konur.
String fmtMoney(int kurus, {bool signed = false, bool compact = false, String currency = 'TRY'}) {
  final v = kurus / 100;
  final s = compact && v.abs() >= 10000
      ? (_moneyCompact[currency] ?? _moneyCompact['TRY']!).format(v)
      : (_money[currency] ?? _money['TRY']!).format(v);
  return signed && kurus > 0 ? '+$s' : s;
}

/// Kur: 41.98765 → "41,9877".
String fmtRate(double r) => _rateFmt.format(r);

/// Yüzde: 12.5 → "%12,5", -3 → "−%3,0".
String fmtPercent(double v) =>
    '${v < 0 ? '−' : ''}%${v.abs().toStringAsFixed(1).replaceAll('.', ',')}';

/// Form alanlarına yazılacak düz tutar ("1.234,56").
String fmtAmountInput(int kurus) => _amountInput.format(kurus / 100);

String fmtDate(DateTime d) => DateFormat('d MMM y', 'tr_TR').format(d);
String fmtDateShort(DateTime d) => DateFormat('d MMM', 'tr_TR').format(d);
String fmtDateLong(DateTime d) => DateFormat('d MMMM y, EEEE', 'tr_TR').format(d);
String fmtMonth(DateTime d) => DateFormat('MMMM y', 'tr_TR').format(d);
String fmtMonthShort(DateTime d) => DateFormat('MMM', 'tr_TR').format(d);

/// "Bugün", "Yarın", "5 gün sonra", "3 gün gecikti".
String fmtDue(DateTime due, {DateTime? today}) {
  final diff = dateOnly(due).difference(dateOnly(today ?? DateTime.now())).inDays;
  if (diff == 0) return 'Bugün';
  if (diff == 1) return 'Yarın';
  if (diff == -1) return 'Dün (gecikti)';
  if (diff < 0) return '${-diff} gün gecikti';
  if (diff < 31) return '$diff gün sonra';
  return fmtDate(due);
}

/// Tutar metni. Tutarları gizle seçeneği açıksa "••••" gösterir.
/// [colored] ise pozitif yeşil, negatif kırmızı boyanır.
class Money extends StatelessWidget {
  const Money(
    this.kurus, {
    super.key,
    this.style,
    this.colored = false,
    this.signed = false,
    this.compact = false,
    this.color,
    this.textAlign,
    this.currency = 'TRY',
  });

  final int kurus;
  final String currency;
  final TextStyle? style;
  final bool colored;
  final bool signed;
  final bool compact;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final hide = context.select<AppPrefs, bool>((p) => p.hideAmounts);
    final fc = FinColors.of(context);
    final c = color ??
        (colored
            ? (kurus > 0 ? fc.income : (kurus < 0 ? fc.expense : null))
            : null);
    return Text(
      hide ? '${currencySymbol(currency)} ••••' : fmtMoney(kurus, signed: signed, compact: compact, currency: currency),
      style: (style ?? const TextStyle()).copyWith(
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Döviz tutarının altında gösterilen "≈ ₺1.234,56" satırı.
class TryHint extends StatelessWidget {
  const TryHint(this.kurus, {super.key, this.fontSize = 12});
  final int kurus;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final hide = context.select<AppPrefs, bool>((p) => p.hideAmounts);
    return Text(
      hide ? '≈ ₺ ••••' : '≈ ${fmtMoney(kurus)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
