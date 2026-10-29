import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../format.dart';
import '../forms/account_form.dart';
import '../forms/contact_form.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_detail_screen.dart';
import 'contact_detail_screen.dart';

/// Banka / kasa hesapları ve cari hesaplar.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onContacts = _tabs.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesaplar'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_outlined), text: 'Banka & Kasa'),
            Tab(icon: Icon(Icons.people_outline), text: 'Cari Hesaplar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => pushPage(context, onContacts ? const ContactFormPage() : const AccountFormPage()),
        icon: Icon(onContacts ? Icons.person_add_alt : Icons.add_card),
        label: Text(onContacts ? 'Cari ekle' : 'Hesap ekle'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_BankAccounts(), _Contacts()],
      ),
    );
  }
}

class _BankAccounts extends StatefulWidget {
  const _BankAccounts();

  @override
  State<_BankAccounts> createState() => _BankAccountsState();
}

class _BankAccountsState extends State<_BankAccounts> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final all = store.accounts;
    final archivedCount = all.where((a) => a.archived).length;
    final visible = all.where((a) => _showArchived || !a.archived).toList();
    if (all.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_outlined,
        title: 'Henüz hesap yok',
        message: 'Banka hesaplarınızı, nakit kasanızı ve kredi kartlarınızı ekleyin.',
      );
    }

    // Türe göre grupla.
    final byType = <AccountType, List<Account>>{};
    for (final a in visible) {
      byType.putIfAbsent(a.type, () => []).add(a);
    }

    return ContentWidth(
      maxWidth: 900,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _TotalCard(label: 'Toplam bakiye', value: store.totalCash),
          for (final t in AccountType.values)
            if (byType[t] != null) ...[
              SectionHeader(accountTypeLabel(t)),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final a in byType[t]!)
                      ListTile(
                        leading: IconBadge(iconForAccount(a.type), Color(a.colorValue)),
                        title: Text(a.name + (a.archived ? ' (arşiv)' : '')),
                        subtitle: Text(
                          [a.bankName, a.iban].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Money(
                          store.balanceOf(a),
                          colored: store.balanceOf(a) < 0,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        onTap: () => pushPage(context, AccountDetailScreen(accountId: a.id)),
                      ),
                  ],
                ),
              ),
            ],
          if (archivedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => _showArchived = !_showArchived),
                icon: Icon(_showArchived ? Icons.visibility_off_outlined : Icons.inventory_2_outlined),
                label: Text(_showArchived ? 'Arşivi gizle' : 'Arşivlenmiş $archivedCount hesabı göster'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value, this.secondLabel, this.secondValue});
  final String label;
  final int value;
  final String? secondLabel;
  final int? secondValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String l, int v, Color? c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: TextStyle(color: scheme.onSecondaryContainer.withValues(alpha: 0.8), fontSize: 12)),
          Money(v, color: c ?? scheme.onSecondaryContainer,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
    final fc = FinColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          cell(label, value, secondLabel == null ? null : fc.income),
          if (secondLabel != null) cell(secondLabel!, secondValue!, fc.expense),
        ],
      ),
    );
  }
}

class _Contacts extends StatefulWidget {
  const _Contacts();

  @override
  State<_Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<_Contacts> {
  String _query = '';
  ContactType? _type;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (receivable, payable) = store.contactTotals;
    final q = _query.toLowerCase();
    final list = store.contacts.where((c) {
      if (_type != null && c.type != _type && c.type != ContactType.both) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    if (store.contacts.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Henüz cari yok',
        message: 'Müşteri ve tedarikçilerinizi ekleyerek alacak ve borçlarınızı takip edin.',
      );
    }

    return ContentWidth(
      maxWidth: 900,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _TotalCard(label: 'Toplam alacak', value: receivable, secondLabel: 'Toplam borç', secondValue: payable),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari ara…'),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (t, l) in [
                (null, 'Tümü'),
                (ContactType.customer, 'Müşteriler'),
                (ContactType.supplier, 'Tedarikçiler'),
              ])
                ChoiceChip(label: Text(l), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in list)
                  Builder(builder: (context) {
                    final b = store.contactBalanceOf(c);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Text(c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase()),
                      ),
                      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(contactTypeLabel(c.type)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Money(b.abs(),
                              color: b > 0 ? fc.income : (b < 0 ? fc.expense : null),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            b > 0 ? 'Alacak' : (b < 0 ? 'Borç' : 'Kapalı'),
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      onTap: () => pushPage(context, ContactDetailScreen(contactId: c.id)),
                    );
                  }),
                if (list.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text('Eşleşen cari yok.')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
