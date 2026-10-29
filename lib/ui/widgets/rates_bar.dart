import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../data/rate_service.dart';
import '../format.dart';
import '../screens/settings_screen.dart';
import 'common.dart';

/// Güncel USD / EUR kurları, son güncelleme zamanı ve yenile düğmesi.
class RatesBar extends StatelessWidget {
  const RatesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final service = context.watch<RateService?>();
    final r = store.rates;
    final scheme = Theme.of(context).colorScheme;
    final fc = r.isFallback || service?.lastError != null ? scheme.error : scheme.onSurfaceVariant;
    final when = r.updatedAt == null
        ? 'güncellenmedi'
        : '${fmtDateShort(r.updatedAt!)} ${r.updatedAt!.hour.toString().padLeft(2, '0')}:'
            '${r.updatedAt!.minute.toString().padLeft(2, '0')}';
    Widget pill(String code, double v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$code ', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          TextSpan(text: fmtRate(v), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushPage(context, const SettingsScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Icon(Icons.currency_exchange, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    pill('USD', r.usd),
                    pill('EUR', r.eur),
                    Text(
                      service?.lastError != null ? 'Kur alınamadı · $when' : '${r.source} · $when',
                      style: TextStyle(fontSize: 11, color: fc),
                    ),
                  ],
                ),
              ),
              if (service != null)
                service.loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Kurları güncelle',
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          final err = await service.refresh();
                          if (context.mounted) toast(context, err ?? 'Kurlar güncellendi');
                        },
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
