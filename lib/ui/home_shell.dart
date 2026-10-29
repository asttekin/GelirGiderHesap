import 'package:flutter/material.dart';

import 'screens/accounts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/planned_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/transactions_screen.dart';

/// Ana iskelet. Geniş ekranda (≥ 840) sol tarafta NavigationRail,
/// telefonda altta NavigationBar kullanılır.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Alt ekranlardan sekme değiştirmek için (ör. özetten "Tümünü gör").
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?._select(index);

  static const tabDashboard = 0;
  static const tabTransactions = 1;
  static const tabPlanned = 2;
  static const tabAccounts = 3;
  static const tabReports = 4;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  static const _destinations = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Özet'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'İşlemler'),
    (Icons.event_note_outlined, Icons.event_note, 'Planlı'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Hesaplar'),
    (Icons.insights_outlined, Icons.insights, 'Raporlar'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final page = IndexedStack(
      index: _index,
      children: const [
        DashboardScreen(),
        TransactionsScreen(),
        PlannedScreen(),
        AccountsScreen(),
        ReportsScreen(),
      ],
    );

    if (wide) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.85,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.account_balance_wallet, color: scheme.onPrimaryContainer),
                  ),
                ),
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
