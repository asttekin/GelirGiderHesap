import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_prefs.dart';
import '../../data/demo_data.dart';
import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../forms/account_form.dart';
import '../forms/planned_form.dart';
import '../home_shell.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'account_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final prefs = context.watch<AppPrefs>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans Özeti'),
        actions: [
          IconButton(
            tooltip: prefs.hideAmounts ? 'Tutarları göster' : 'Tutarları gizle',
            icon: Icon(prefs.hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => prefs.hideAmounts = !prefs.hideAmounts,
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => pushPage(context, const SettingsScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: store.isEmpty ? null : const QuickAddFab(),
      body: store.isEmpty ? const _Welcome() : const _DashboardBody(),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Finanslarınızı tek yerden yönetin',
    message: 'Banka hesaplarınızı, kasanızı ve cari hesaplarınızı ekleyin; gelir, gider, '
        'yaklaşan ödeme ve tahsilatlarınızı takip edin.',
    action: Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () => pushPage(context, const AccountFormPage()),
          icon: const Icon(Icons.add),
          label: const Text('İlk hesabı ekle'),
        ),
        OutlinedButton.icon(
          onPressed: () => loadDemoData(context.read<FinanceStore>()),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Örnek veriyle dene'),
        ),
      ],
    ),
  );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    const left = [_HeroCard(), _KpiRow(), _OverdueBanner(), _CashFlowCard(), _AccountsStrip()];
    const right = [_UpcomingCard(), _RecentCard()];
    return ContentWidth(
      child: wide
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Column(children: _spaced(left))),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: Column(children: _spaced(right))),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: _spaced([...left, ...right]),
            ),
    );
  }

  static List<Widget> _spaced(List<Widget> w) => [
    for (final x in w) Padding(padding: const EdgeInsets.only(bottom: 16), child: x),
  ];
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final r = buildReport(store.txns, DateTime(now.year, now.month), now);
    final onHero = scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.55)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Toplam nakit varlık', style: TextStyle(color: onHero.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          Money(
            store.totalCash,
            color: onHero,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          Text(
            '${store.activeAccounts.length} hesap · ${fmtDateLong(now)}',
            style: TextStyle(color: onHero.withValues(alpha: 0.75), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _heroStat('Bu ay gelir', r.income, Icons.south_west, onHero),
                _heroStat('Bu ay gider', r.expense, Icons.north_east, onHero),
                _heroStat('Net', r.net, Icons.drag_handle, onHero, signed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, int v, IconData icon, Color c, {bool signed = false}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: c.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.withValues(alpha: 0.85), fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Money(v, compact: true, signed: signed, color: c,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    ),
  );
}

class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final (receivable, payable) = store.contactTotals;
    final today = DateTime.now();
    final events = upcomingEvents(store.planned, today, today.add(const Duration(days: 30)));
    var expIn = 0, expOut = 0;
    for (final e in events) {
      if (e.item.kind == PlannedKind.collection) {
        expIn += e.item.amount;
      } else {
        expOut += e.item.amount;
      }
    }
    final tiles = [
      _Kpi('Carilerden alacak', receivable, Icons.call_received, fc.income,
          () => HomeShell.goTo(context, HomeShell.tabAccounts)),
      _Kpi('Carilere borç', payable, Icons.call_made, fc.expense,
          () => HomeShell.goTo(context, HomeShell.tabAccounts)),
      _Kpi('30 gün beklenen tahsilat', expIn, Icons.event_available, fc.income,
          () => HomeShell.goTo(context, HomeShell.tabPlanned)),
      _Kpi('30 gün beklenen ödeme', expOut, Icons.event_busy, fc.expense,
          () => HomeShell.goTo(context, HomeShell.tabPlanned)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.color, this.onTap);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon, color, size: 32),
            const SizedBox(height: 10),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Money(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final today = dateOnly(DateTime.now());
    final overdue = store.planned.where((p) => !p.completed && p.dueDate.isBefore(today)).toList();

    // Projeksiyonda bakiye eksiye düşüyor mu?
    final proj = projectCashFlow(startBalance: store.totalCash, planned: store.planned, today: today, days: 60);
    final firstNeg = proj.where((p) => p.balance < 0).firstOrNull;

    if (overdue.isEmpty && firstNeg == null) return const SizedBox.shrink();
    return Column(
      children: [
        if (overdue.isNotEmpty)
          _banner(
            context,
            Icons.warning_amber_rounded,
            fc.expense,
            '${overdue.length} gecikmiş kalem',
            'Toplam ${fmtMoney(overdue.fold<int>(0, (s, p) => s + p.amount))} vadesi geçti.',
            () => HomeShell.goTo(context, HomeShell.tabPlanned),
          ),
        if (overdue.isNotEmpty && firstNeg != null) const SizedBox(height: 10),
        if (firstNeg != null)
          _banner(
            context,
            Icons.trending_down,
            fc.warning,
            'Nakit açığı riski',
            '${fmtDate(firstNeg.date)} tarihinde toplam bakiye '
                '${fmtMoney(firstNeg.balance)} seviyesine düşebilir.',
            () => HomeShell.goTo(context, HomeShell.tabReports),
          ),
      ],
    );
  }

  Widget _banner(BuildContext context, IconData icon, Color color, String title, String msg, VoidCallback onTap) {
    final hide = context.read<AppPrefs>().hideAmounts;
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    if (!hide) Text(msg, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final history = historicalBalance(
      store.accounts,
      store.txns,
      today.subtract(const Duration(days: 30)),
      today,
    );
    final projection = projectCashFlow(
      startBalance: store.totalCash,
      planned: store.planned,
      today: today,
      days: 60,
    );
    final end = projection.last.balance;
    final change = end - store.totalCash;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nakit akışı', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Son 30 gün ve 60 günlük tahmin',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('60 gün sonra', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Money(end, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Money(change, colored: true, signed: true, compact: true, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            CashFlowChart(history: history, projection: projection),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _lineKey(context, false, 'Gerçekleşen'),
                _lineKey(context, true, 'Tahmini (planlı kalemlerle)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineKey(BuildContext context, bool dashed, String label) {
    final c = ChartColors.income(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          child: dashed
              ? Row(children: [
                  Container(width: 6, height: 2, color: c),
                  const SizedBox(width: 3),
                  Container(width: 6, height: 2, color: c),
                ])
              : Container(height: 2, color: c),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _AccountsStrip extends StatelessWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final accounts = store.activeAccounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Hesaplarım',
            action: 'Tümü', onAction: () => HomeShell.goTo(context, HomeShell.tabAccounts)),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == accounts.length) {
                return SizedBox(
                  width: 120,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => pushPage(context, const AccountFormPage()),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.add), SizedBox(height: 6), Text('Hesap ekle')],
                      ),
                    ),
                  ),
                );
              }
              final a = accounts[i];
              final color = Color(a.colorValue);
              return SizedBox(
                width: 190,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => pushPage(context, AccountDetailScreen(accountId: a.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconBadge(iconForAccount(a.type), color, size: 34),
                          const Spacer(),
                          Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Money(store.balanceOf(a), colored: store.balanceOf(a) < 0,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final today = DateTime.now();
    final events = upcomingEvents(store.planned, today, today.add(const Duration(days: 30)))
        .where((e) => e.date == dateOnly(e.item.dueDate)) // her kalemin yalnızca sıradaki vadesi
        .take(6)
        .toList();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: SectionHeader('Yaklaşan ödeme ve tahsilatlar',
                action: 'Tümü', onAction: () => HomeShell.goTo(context, HomeShell.tabPlanned)),
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text('Önümüzdeki 30 günde planlı kalem yok.'),
            )
          else
            for (final e in events)
              PlannedTile(
                e.item,
                onTap: () => showCompletePlanned(context, e.item),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final recent = store.txns.take(6).toList();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: SectionHeader('Son işlemler',
                action: 'Tümü', onAction: () => HomeShell.goTo(context, HomeShell.tabTransactions)),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text('Henüz işlem yok.'),
            )
          else
            for (final t in recent) TxnTile(t),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
