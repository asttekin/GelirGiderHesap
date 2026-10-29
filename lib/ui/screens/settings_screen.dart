import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_prefs.dart';
import '../../data/demo_data.dart';
import '../../data/finance_store.dart';
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
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Yedeği kopyala'),
                    subtitle: const Text('Tüm veriyi JSON olarak panoya kopyalar'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: store.exportJson()));
                      toast(context, 'Yedek panoya kopyalandı');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Yedekten geri yükle'),
                    subtitle: const Text('Kopyalanmış JSON yedeğini yapıştırın'),
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
