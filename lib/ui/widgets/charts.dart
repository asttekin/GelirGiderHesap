import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_prefs.dart';
import '../../logic/finance_math.dart';
import '../format.dart';

/// Grafik renkleri. Doğrulanmış kategorik paletin ilk sıraları; açık ve koyu
/// tema için ayrı adımlar. Gelir/gider grafiklerde mavi/turuncu çiftiyle
/// gösterilir (kırmızı/yeşil renk körlüğünde ayırt edilemez).
class ChartColors {
  static const _light = [
    Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100),
    Color(0xFFE87BA4), Color(0xFF008300), Color(0xFF6250D6), Color(0xFFE34948),
  ];
  static const _dark = [
    Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500),
    Color(0xFFD55181), Color(0xFF008300), Color(0xFF9085E9), Color(0xFFE66767),
  ];
  static const otherLight = Color(0xFF9A9A94);
  static const otherDark = Color(0xFF6E6D68);

  static List<Color> of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  static Color income(BuildContext c) => of(c)[0];
  static Color expense(BuildContext c) => of(c)[1];
  static Color other(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? otherDark : otherLight;
}

String _axisMoney(double v) {
  final a = v.abs();
  final s = a >= 1e6
      ? '${(a / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)} Mn'
      : a >= 1e3
          ? '${(a / 1e3).toStringAsFixed(0)} B'
          : a.toStringAsFixed(0);
  return v < 0 ? '−$s' : s;
}

/// Eksen için "güzel" adım (1, 2, 2.5, 5 × 10^n).
double _niceStep(double range, int ticks) {
  if (range <= 0) return 1;
  final raw = range / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (raw <= m * mag) return m * mag;
  }
  return 10 * mag;
}

TextStyle _axisStyle(BuildContext context) =>
    TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant);

/// Gerçekleşen (düz) + tahmini (kesikli) toplam bakiye çizgisi.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    super.key,
    required this.history,
    required this.projection,
    this.height = 220,
  });

  final List<CashPoint> history;
  final List<CashPoint> projection;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hide = context.select<AppPrefs, bool>((p) => p.hideAmounts);
    final scheme = Theme.of(context).colorScheme;
    final color = ChartColors.income(context);
    if (history.isEmpty && projection.isEmpty) return SizedBox(height: height);
    final origin = (history.isNotEmpty ? history.first : projection.first).date;
    double x(DateTime d) => dateOnly(d).difference(origin).inDays.toDouble();
    FlSpot spot(CashPoint p) => FlSpot(x(p.date), p.balance / 100);

    final hist = history.map(spot).toList();
    final proj = projection.map(spot).toList();
    final all = [...hist, ...proj];
    var minY = all.map((s) => s.y).reduce(math.min);
    var maxY = all.map((s) => s.y).reduce(math.max);
    minY = math.min(minY, 0);
    if (maxY == minY) maxY = minY + 1;
    final step = _niceStep(maxY - minY, 4);
    minY = (minY / step).floor() * step;
    maxY = (maxY / step).ceil() * step;
    final todayX = x(DateTime.now());
    final maxX = all.map((s) => s.x).reduce(math.max);

    LineChartBarData line(List<FlSpot> spots, {bool dashed = false}) => LineChartBarData(
      spots: spots,
      isCurved: false,
      barWidth: 2,
      color: color,
      dashArray: dashed ? [6, 4] : null,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: !dashed,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ),
      ),
    );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (v) => FlLine(
              color: v == 0 ? scheme.outline : scheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: v == 0 ? 1 : 0.6,
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              if (hist.isNotEmpty && proj.isNotEmpty)
                VerticalLine(
                  x: todayX,
                  color: scheme.outline,
                  strokeWidth: 1,
                  dashArray: [3, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: _axisStyle(context),
                    labelResolver: (_) => 'Bugün',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !hide,
                reservedSize: 44,
                interval: step,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min && v != 0
                    ? const SizedBox.shrink()
                    : Text(_axisMoney(v), style: _axisStyle(context)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: math.max(7, (maxX / 5).roundToDouble()),
                getTitlesWidget: (v, meta) {
                  if (v == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(fmtDateShort(origin.add(Duration(days: v.round()))),
                        style: _axisStyle(context)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (bar, idx) => [
              for (final _ in idx)
                TouchedSpotIndicatorData(
                  FlLine(color: scheme.outline, strokeWidth: 1),
                  FlDotData(
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 5,
                      color: color,
                      strokeWidth: 2,
                      strokeColor: scheme.surface,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) {
                // İki seri bugünde kesişir; tek ipucu göster.
                final seen = <double>{};
                return [
                  for (final s in spots)
                    if (seen.add(s.x))
                      LineTooltipItem(
                        '${fmtDate(origin.add(Duration(days: s.x.round())))}\n',
                        TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                        children: [
                          TextSpan(
                            text: hide ? '₺ ••••' : fmtMoney((s.y * 100).round()),
                            style: TextStyle(
                              color: scheme.onInverseSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (s.barIndex == 1 && s.x > todayX)
                            TextSpan(
                              text: '  tahmini',
                              style: TextStyle(color: scheme.onInverseSurface.withValues(alpha: 0.7), fontSize: 11),
                            ),
                        ],
                      )
                    else
                      null,
                ];
              },
            ),
          ),
          lineBarsData: [
            if (hist.isNotEmpty) line(hist),
            if (proj.isNotEmpty) line(proj, dashed: true),
          ],
        ),
      ),
    );
  }
}

/// Aylık gelir / gider çubuk grafiği.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.buckets, this.height = 240});
  final List<MonthBucket> buckets;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hide = context.select<AppPrefs, bool>((p) => p.hideAmounts);
    final scheme = Theme.of(context).colorScheme;
    final inc = ChartColors.income(context), exp = ChartColors.expense(context);
    var maxY = 0.0;
    for (final b in buckets) {
      maxY = math.max(maxY, math.max(b.income, b.expense) / 100);
    }
    final step = _niceStep(maxY == 0 ? 1 : maxY, 4);
    maxY = math.max(step, (maxY / step).ceil() * step);
    final barW = buckets.length > 8 ? 7.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Legend(items: [('Gelir', inc), ('Gider', exp)]),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: v == 0 ? scheme.outline : scheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: v == 0 ? 1 : 0.6,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: !hide,
                    reservedSize: 44,
                    interval: step,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : Text(_axisMoney(v), style: _axisStyle(context)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                      if (buckets.length > 8 && i.isOdd && i != buckets.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(fmtMonthShort(buckets[i].month), style: _axisStyle(context)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, gi, rod, ri) {
                    final b = buckets[group.x];
                    final st = TextStyle(color: scheme.onInverseSurface, fontSize: 12);
                    String m(int v) => hide ? '₺ ••••' : fmtMoney(v);
                    return BarTooltipItem(
                      '${fmtMonth(b.month)}\n',
                      st.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.left,
                      children: [
                        TextSpan(text: 'Gelir  ${m(b.income)}\n', style: st),
                        TextSpan(text: 'Gider  ${m(b.expense)}\n', style: st),
                        TextSpan(text: 'Net  ${m(b.net)}', style: st.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: buckets[i].income / 100,
                        color: inc,
                        width: barW,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: buckets[i].expense / 100,
                        color: exp,
                        width: barW,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Legend extends StatelessWidget {
  const Legend({super.key, required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 6,
    children: [
      for (final i in items)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: i.$2, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 6),
            Text(i.$1, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
    ],
  );
}

/// Kategori dağılımı: halka grafik + değerli liste. En büyük 6 dilim
/// renklenir, kalanı "Diğer" altında toplanır.
class CategoryBreakdown extends StatefulWidget {
  const CategoryBreakdown({super.key, required this.slices});

  /// (etiket, tutar) — büyükten küçüğe sıralı olması gerekmez.
  final List<(String, int)> slices;

  @override
  State<CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<CategoryBreakdown> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final palette = ChartColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...widget.slices.where((s) => s.$2 > 0)]..sort((a, b) => b.$2.compareTo(a.$2));
    const maxSlices = 6;
    final shown = sorted.take(maxSlices).toList();
    final rest = sorted.skip(maxSlices).fold<int>(0, (s, e) => s + e.$2);
    final slices = [
      for (var i = 0; i < shown.length; i++) (shown[i].$1, shown[i].$2, palette[i]),
      if (rest > 0) ('Diğer', rest, ChartColors.other(context)),
    ];
    final total = slices.fold<int>(0, (s, e) => s + e.$2);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Bu dönemde kayıt yok', style: TextStyle(color: scheme.onSurfaceVariant))),
      );
    }

    final chart = SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 52,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (e, r) => setState(() {
                  _touched = e.isInterestedForInteractions ? r?.touchedSection?.touchedSectionIndex : null;
                  if (_touched != null && _touched! < 0) _touched = null;
                }),
              ),
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].$2.toDouble(),
                    color: slices[i].$3,
                    radius: _touched == i ? 30 : 24,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _touched == null ? 'Toplam' : slices[_touched!].$1,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(
                width: 96,
                child: FittedBox(
                  child: Money(
                    _touched == null ? total : slices[_touched!].$2,
                    compact: true,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final list = Column(
      children: [
        for (var i = 0; i < slices.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _touched = _touched == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: slices[i].$3, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      slices[i].$1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: _touched == i ? FontWeight.w700 : null),
                    ),
                  ),
                  Text(
                    '%${(slices[i].$2 / total * 100).toStringAsFixed(0)}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 104,
                    child: Money(slices[i].$2, textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 480
          ? Row(
              children: [
                chart,
                const SizedBox(width: 24),
                Expanded(child: list),
              ],
            )
          : Column(children: [chart, const SizedBox(height: 12), list]),
    );
  }
}
