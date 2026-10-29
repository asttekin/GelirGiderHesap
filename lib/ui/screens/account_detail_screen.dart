import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/finance_store.dart';
import '../../logic/finance_math.dart';
import '../category_icons.dart';
import '../format.dart';
import '../forms/account_form.dart';
import '../forms/txn_form.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final a = store.account(accountId);
    if (a == null) return const Scaffold(body: Center(child: Text('Hesap bulunamadı')));
    final fc = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final txns = store.txns.where((t) => t.accountId == a.id || t.toAccountId == a.id).toList();
    final balance = store.balanceOf(a);
    final now = DateTime.now();
    var mIn = 0, mOut = 0;
    for (final t in txns) {
      if (t.date.year != now.year || t.date.month != now.month) continue;
      final e = txnEffectOn(t, a.id);
      if (e > 0) {
        mIn += e;
      } else {
        mOut -= e;
      }
    }
    final color = Color(a.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => pushPage(context, AccountFormPage(existing: a)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Bu hesaba işlem ekle',
        onPressed: () => pushPage(context, TxnFormPage(accountId: a.id)),
        child: const Icon(Icons.add),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(iconForAccount(a.type), color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [accountTypeLabel(a.type), a.bankName].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Güncel bakiye', style: TextStyle(color: Colors.white70)),
                  Money(balance, currency: a.currency, color: Colors.white,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  if (a.isForeign)
                    Text(
                      '≈ ${fmtMoney(store.tryBalanceOf(a))} · 1 ${a.currency} = ${fmtRate(store.rates.of(a.currency))} ₺',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (a.iban.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: a.iban.replaceAll(' ', '')));
                        toast(context, 'IBAN kopyalandı');
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(a.iban,
                                style: const TextStyle(color: Colors.white, letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy, size: 16, color: Colors.white70),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _stat(context, 'Bu ay giriş', mIn, fc.income, a.currency)),
                const SizedBox(width: 12),
                Expanded(child: _stat(context, 'Bu ay çıkış', mOut, fc.expense, a.currency)),
              ],
            ),
            const SectionHeader('Hesap hareketleri'),
            if (txns.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Bu hesapta henüz işlem yok.', style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [for (final t in txns) TxnTile(t, perspectiveAccountId: a.id)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int v, Color c, String currency) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Money(v, currency: currency, color: c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ],
      ),
    ),
  );
}
