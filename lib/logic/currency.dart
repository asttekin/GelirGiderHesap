/// Para birimleri ve döviz kurları.
library;

const currencyCodes = ['TRY', 'USD', 'EUR'];

String currencySymbol(String code) => switch (code) {
  'USD' => r'$',
  'EUR' => '€',
  _ => '₺',
};

String currencyName(String code) => switch (code) {
  'USD' => 'ABD doları',
  'EUR' => 'Euro',
  _ => 'Türk lirası',
};

/// Güncel kurlar: 1 USD / 1 EUR kaç ₺.
class Rates {
  final double usd;
  final double eur;
  final DateTime? updatedAt;

  /// Kurun alındığı kaynak ("TCMB", "Frankfurter (ECB)", "Elle" …).
  final String source;

  const Rates({required this.usd, required this.eur, this.updatedAt, this.source = ''});

  /// İnternet yokken ve hiç kur alınmamışken kullanılan yaklaşık değerler.
  static const fallback = Rates(usd: 42.0, eur: 49.0, source: 'Varsayılan (güncel değil)');

  bool get isFallback => updatedAt == null;

  double of(String code) => switch (code) {
    'USD' => usd,
    'EUR' => eur,
    _ => 1,
  };

  /// [amount] (kuruş/sent, [code] biriminde) → ₺ kuruş.
  int toTry(int amount, String code) => code == 'TRY' ? amount : (amount * of(code)).round();

  /// ₺ kuruş → [code] biriminde kuruş/sent.
  int fromTry(int tryAmount, String code) =>
      code == 'TRY' ? tryAmount : (tryAmount / of(code)).round();

  /// [amount]'u [from] biriminden [to] birimine çevirir.
  int convert(int amount, String from, String to) =>
      from == to ? amount : fromTry(toTry(amount, from), to);

  Rates copyWith({double? usd, double? eur, DateTime? updatedAt, String? source}) => Rates(
    usd: usd ?? this.usd,
    eur: eur ?? this.eur,
    updatedAt: updatedAt ?? this.updatedAt,
    source: source ?? this.source,
  );

  Map<String, Object?> toJson() => {
    'usd': usd,
    'eur': eur,
    'updatedAt': updatedAt?.toIso8601String(),
    'source': source,
  };

  factory Rates.fromJson(Map<String, Object?> j) => Rates(
    usd: (j['usd'] as num).toDouble(),
    eur: (j['eur'] as num).toDouble(),
    updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
    source: (j['source'] as String?) ?? '',
  );
}

/// "34,5678" veya "34.5678" → 34.5678. Geçersiz ya da sıfır/negatifse `null`.
double? parseRate(String input) {
  final s = input.trim().replaceAll(' ', '').replaceAll(',', '.');
  final v = double.tryParse(s);
  return v == null || v <= 0 || v.isNaN || v.isInfinite ? null : v;
}
