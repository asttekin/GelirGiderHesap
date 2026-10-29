import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

import '../logic/currency.dart';
import 'finance_store.dart';

/// USD ve EUR kurlarını internetten otomatik çeker.
///
/// Kaynaklar sırayla denenir; ilk başarılı olan kullanılır:
/// 1. TCMB günlük kurları (döviz satış) — tarayıcıda CORS izni olmadığı
///    için yalnızca mobil uygulamada,
/// 2. Frankfurter (Avrupa Merkez Bankası referans kurları),
/// 3. ExchangeRate-API (open.er-api.com).
///
/// Açılışta kur [staleAfter] süresinden eskiyse yenilenir; uygulama açık
/// kaldıkça her [interval] sürede bir tekrar denenir.
class RateService extends ChangeNotifier {
  RateService(this.store, {http.Client? client}) : _client = client ?? http.Client();

  final FinanceStore store;
  final http.Client _client;

  static const staleAfter = Duration(hours: 2);
  static const interval = Duration(minutes: 30);

  Timer? _timer;
  bool _loading = false;
  String? _lastError;

  bool get loading => _loading;
  String? get lastError => _lastError;

  void start() {
    final r = store.rates;
    if (r.updatedAt == null || DateTime.now().difference(r.updatedAt!) > staleAfter) {
      refresh();
    }
    _timer ??= Timer.periodic(interval, (_) => refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Kurları yeniler. Başarılıysa `null`, değilse hata mesajı döner;
  /// hata durumunda mevcut kurlar korunur.
  Future<String?> refresh() async {
    if (_loading) return null;
    _loading = true;
    notifyListeners();
    final errors = <String>[];
    final sources = <(String, Future<Rates> Function())>[
      if (!kIsWeb) ('TCMB', _tcmb),
      ('Frankfurter', _frankfurter),
      ('ExchangeRate-API', _erApi),
    ];
    Rates? result;
    for (final (name, fetch) in sources) {
      try {
        result = await fetch().timeout(const Duration(seconds: 10));
        break;
      } catch (e) {
        errors.add('$name: $e');
      }
    }
    _loading = false;
    if (result != null) {
      _lastError = null;
      store.setRates(result);
    } else {
      _lastError = 'Kurlar alınamadı. İnternet bağlantınızı kontrol edin.';
      notifyListeners();
    }
    notifyListeners();
    return result == null ? _lastError : null;
  }

  Future<String> _get(String url) async {
    final res = await _client.get(Uri.parse(url));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}');
    return utf8.decode(res.bodyBytes);
  }

  Future<Rates> _tcmb() async =>
      parseTcmb(await _get('https://www.tcmb.gov.tr/kurlar/today.xml'), DateTime.now());

  Future<Rates> _frankfurter() async => parseFrankfurter(
    await _get('https://api.frankfurter.dev/v1/latest?base=TRY&symbols=USD,EUR'),
    DateTime.now(),
  );

  Future<Rates> _erApi() async =>
      parseErApi(await _get('https://open.er-api.com/v6/latest/USD'), DateTime.now());

  // ---- Ayrıştırıcılar (test edilebilir) ----------------------------------

  /// TCMB today.xml: `<Currency Kod="USD">…<ForexSelling>41.9876</ForexSelling>`.
  @visibleForTesting
  static Rates parseTcmb(String xml, DateTime now) {
    double pick(String code) {
      final block = RegExp('<Currency[^>]*Kod="$code"[^>]*>(.*?)</Currency>', dotAll: true)
          .firstMatch(xml)
          ?.group(1);
      final v = block == null
          ? null
          : RegExp(r'<ForexSelling>\s*([\d.,]+)\s*</ForexSelling>').firstMatch(block)?.group(1);
      final d = v == null ? null : parseRate(v);
      if (d == null) throw const FormatException('TCMB yanıtında kur yok');
      return d;
    }

    return Rates(usd: pick('USD'), eur: pick('EUR'), updatedAt: now, source: 'TCMB (döviz satış)');
  }

  /// Frankfurter: `{"base":"TRY","rates":{"EUR":0.0204,"USD":0.0238}}`.
  @visibleForTesting
  static Rates parseFrankfurter(String body, DateTime now) {
    final j = jsonDecode(body) as Map<String, Object?>;
    final rates = j['rates'] as Map<String, Object?>;
    double inv(String c) {
      final v = (rates[c] as num?)?.toDouble();
      if (v == null || v <= 0) throw const FormatException('Frankfurter yanıtında kur yok');
      return 1 / v;
    }

    return Rates(usd: inv('USD'), eur: inv('EUR'), updatedAt: now, source: 'Frankfurter (ECB)');
  }

  /// ExchangeRate-API: `{"result":"success","base_code":"USD","rates":{"TRY":41.9,"EUR":0.86}}`.
  @visibleForTesting
  static Rates parseErApi(String body, DateTime now) {
    final j = jsonDecode(body) as Map<String, Object?>;
    if (j['result'] != 'success') throw const FormatException('ExchangeRate-API hatası');
    final rates = j['rates'] as Map<String, Object?>;
    final tryPerUsd = (rates['TRY'] as num?)?.toDouble();
    final eurPerUsd = (rates['EUR'] as num?)?.toDouble();
    if (tryPerUsd == null || eurPerUsd == null || eurPerUsd <= 0) {
      throw const FormatException('ExchangeRate-API yanıtında kur yok');
    }
    return Rates(usd: tryPerUsd, eur: tryPerUsd / eurPerUsd, updatedAt: now, source: 'ExchangeRate-API');
  }
}
