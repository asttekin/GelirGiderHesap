import 'package:flutter/material.dart';

/// Gelir / gider / transfer için anlamsal renkler (açık ve koyu temada ayrı).
class FinColors extends ThemeExtension<FinColors> {
  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;

  const FinColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warning,
  });

  static const light = FinColors(
    income: Color(0xFF1B8A4B),
    expense: Color(0xFFC62828),
    transfer: Color(0xFF1565C0),
    warning: Color(0xFFE65100),
  );
  static const dark = FinColors(
    income: Color(0xFF5FD38D),
    expense: Color(0xFFFF7A7A),
    transfer: Color(0xFF82B1FF),
    warning: Color(0xFFFFB74D),
  );

  static FinColors of(BuildContext context) =>
      Theme.of(context).extension<FinColors>() ?? light;

  @override
  FinColors copyWith({Color? income, Color? expense, Color? transfer, Color? warning}) =>
      FinColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
        warning: warning ?? this.warning,
      );

  @override
  FinColors lerp(FinColors? other, double t) {
    if (other == null) return this;
    return FinColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

ThemeData buildTheme(Brightness brightness, Color seed) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? scheme.surface : scheme.surfaceContainerLowest,
    extensions: [dark ? FinColors.dark : FinColors.light],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: dark ? scheme.surface : scheme.surfaceContainerLowest,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? scheme.surfaceContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.5 : 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
