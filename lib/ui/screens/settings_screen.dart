import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_prefs.dart';
import '../../data/demo_data.dart';
import '../../data/finance_store.dart';
import '../../data/rate_service.dart';
import '../../logic/currency.dart';
import '../../services/share_service.dart';
import '../format.dart';
import '../../models/models.dart';
import '../category_icons.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _seeds = [0xFF00796B, 0xFF3F51B5, 0xFF1E88E5, 0xFF6A1B9A, 0xFFEF6C00, 0xFF2E7D32, 0xFF37474F];

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    final store = context.read<FinanceStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SectionHeader('Görünüm'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto)),
                        ButtonSegment(value: ThemeMode.light, label: Text('Açık'), icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Koyu'), icon: Icon(Icons.dark_mode_outlined)),
                      ],
                      selected: {prefs.themeMode},
                      onSelectionChanged: (s) => prefs.themeMode = s.first,
                    ),
                    const SizedBox(height: 16),
                    const Text('Tema rengi'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (final c in _seeds)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => prefs.seedColor = c,
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: Color(c),
                              child: prefs.seedColor == c
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tutarları gizle'),
                      subtitle: const Text('Toplantıda veya kalabalık ortamda bakiyeleri gizler.'),
                      value: prefs.hideAmounts,
                      onChanged: (v) => prefs.hideAmounts = v,
                    ),
                  ],
                ),
              ),
            ),
            const SectionHeader('Döviz kurları'),
            const _RatesCard(),
            const SectionHeader('Veri'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Kategoriler'),
                    subtitle: const Text('Gelir ve gider kategorilerini yönet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => pushPage(context, const CategoriesScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: const Text('Yedek dosyası oluştur'),
                    subtitle: const Text('JSON dosyasını paylaşın veya indirin (Drive, e-posta, Dosyalar…)'),
                    onTap: () async {
                      try {
                        await ShareService.shareJson(store.exportJson(), 'finans-yedek_${ShareService.stamp()}.json');
                      } catch (e) {
                        if (context.mounted) toast(context, 'Yedek paylaşılamadı: $e');
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_open_outlined),
                    title: const Text('Dosyadan geri yükle'),
                    subtitle: const Text('Daha önce oluşturulan .json yedek dosyasını seçin'),
                    onTap: () => _importFile(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Yedeği panoya kopyala'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: store.exportJson()));
                      toast(context, 'Yedek panoya kopyalandı');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.content_paste),
                    title: const Text('Panodan geri yükle'),
                    onTap: () => _import(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('Örnek veri ekle'),
                    subtitle: const Text('Uygulamayı denemek için hesap, cari ve işlem ekler'),
                    onTap: () {
                      loadDemoData(store);
                      toast(context, 'Örnek veri eklendi');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                    title: Text('Tüm veriyi sil', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    onTap: () async {
                      final ok = await confirm(
                        context,
                        title: 'Tüm veriyi sil',
                        message: 'Hesaplar, cariler, işlemler ve planlı kalemler kalıcı olarak silinecek. '
                            'Önce yedek almanız önerilir.',
                        action: 'Hepsini sil',
                      );
                      if (ok) {
                        await store.resetAll();
                        if (context.mounted) toast(context, 'Tüm veri silindi');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Veriler yalnızca bu cihazda saklanır. Cihaz değiştirmeden önce yedeği kopyalayıp güvenli bir yere kaydedin.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFile(BuildContext context) async {
    final store = context.read<FinanceStore>();
    try {
      final raw = await ShareService.pickJsonFile();
      if (raw == null || !context.mounted) return;
      final ok = await confirm(
        context,
        title: 'Yedekten geri yükle',
        message: 'Mevcut verinin yerini seçilen yedek alacak. Devam edilsin mi?',
        action: 'Geri yükle',
      );
      if (!ok) return;
      await store.importJson(raw);
      if (context.mounted) toast(context, 'Yedek geri yüklendi');
    } catch (e) {
      if (context.mounted) toast(context, 'Geri yüklenemedi: geçersiz yedek dosyası');
    }
  }

  Future<void> _import(BuildContext context) async {
    final ctrl = TextEditingController(text: (await Clipboard.getData('text/plain'))?.text ?? '');
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedekten geri yükle'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mevcut verinin yerini alır.'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(hintText: '{ "accounts": … }'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri yükle')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<FinanceStore>().importJson(ctrl.text);
      if (context.mounted) toast(context, 'Yedek geri yüklendi');
    } catch (e) {
      if (context.mounted) toast(context, 'Geri yüklenemedi: geçersiz yedek');
    }
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategoriler'),
          bottom: const TabBar(tabs: [Tab(text: 'Gider'), Tab(text: 'Gelir')]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            heroTag: null,
            tooltip: 'Kategori ekle',
            onPressed: () => _edit(
              ctx,
              null,
              DefaultTabController.of(ctx).index == 0 ? CategoryKind.expense : CategoryKind.income,
            ),
            child: const Icon(Icons.add),
          ),
        ),
        body: TabBarView(
          children: [
            for (final k in [CategoryKind.expense, CategoryKind.income])
              ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final c in store.categoriesOf(k))
                    ListTile(
                      leading: IconBadge(iconForCategory(c), Color(c.colorValue)),
                      title: Text(c.name),
                      trailing: IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(
                            context,
                            title: 'Kategoriyi sil',
                            message: '"${c.name}" silinecek; bu kategorideki işlemler kategorisiz kalır.',
                          )) {
                            store.deleteCategory(c.id);
                          }
                        },
                      ),
                      onTap: () => _edit(context, c, k),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Category? existing, CategoryKind kind) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var icon = existing?.icon ?? 'other';
    var color = existing?.colorValue ?? pickerColors.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Yeni kategori' : 'Kategoriyi düzenle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Ad'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in categoryIcons.entries)
                        IconButton.filledTonal(
                          isSelected: icon == e.key,
                          onPressed: () => setState(() => icon = e.key),
                          icon: Icon(e.value, color: icon == e.key ? Color(color) : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in pickerColors)
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => color = c),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(c),
                            child: color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(ctx, true);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      context.read<FinanceStore>().upsertCategory(
        Category(
          id: existing?.id ?? newId(),
          name: name.text.trim(),
          kind: kind,
          icon: icon,
          colorValue: color,
        ),
      );
    }
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final service = context.watch<RateService?>();
    final r = store.rates;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final c in ['USD', 'EUR'])
            ListTile(
              leading: CircleAvatar(child: Text(currencySymbol(c))),
              title: Text('1 $c = ${fmtRate(r.of(c))} ₺'),
              subtitle: Text(currencyName(c)),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(r.source.isEmpty ? 'Kaynak bilinmiyor' : r.source),
            subtitle: Text(
              [
                if (r.updatedAt != null)
                  'Son güncelleme: ${fmtDate(r.updatedAt!)} '
                      '${r.updatedAt!.hour.toString().padLeft(2, '0')}:${r.updatedAt!.minute.toString().padLeft(2, '0')}',
                if (service?.lastError != null) service!.lastError!,
                'Kurlar açılışta ve uygulama açıkken 30 dakikada bir otomatik güncellenir.',
              ].join('\n'),
              style: TextStyle(color: service?.lastError != null ? scheme.error : null),
            ),
            isThreeLine: true,
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _manual(context, r),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Elle gir'),
              ),
              if (service != null)
                FilledButton.tonalIcon(
                  onPressed: service.loading
                      ? null
                      : () async {
                          final err = await service.refresh();
                          if (context.mounted) toast(context, err ?? 'Kurlar güncellendi');
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Şimdi güncelle'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _manual(BuildContext context, Rates r) async {
    final usd = TextEditingController(text: fmtRate(r.usd));
    final eur = TextEditingController(text: fmtRate(r.eur));
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kurları elle gir'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (c, ctrl) in [('USD', usd), ('EUR', eur)])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: '1 $c = ? ₺'),
                    validator: (v) => parseRate(v ?? '') == null ? 'Geçerli bir kur girin' : null,
                  ),
                ),
              const Text('Bir sonraki otomatik güncellemede internetten alınan kur kullanılır.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<FinanceStore>().setRates(
        Rates(usd: parseRate(usd.text)!, eur: parseRate(eur.text)!, updatedAt: DateTime.now(), source: 'Elle girildi'),
      );
    }
  }
}
