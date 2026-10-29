import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../logic/finance_math.dart';
import '../models/models.dart';
import 'default_categories.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Tüm finans verisinin tek kaynağı. Her değişiklikten sonra veriyi
/// cihazda JSON olarak saklar ve dinleyicileri bilgilendirir.
class FinanceStore extends ChangeNotifier {
  static const _storageKey = 'finance_data_v1';
  static const schemaVersion = 1;

  FinanceStore([this._prefs]);

  SharedPreferences? _prefs;

  final List<Account> _accounts = [];
  final List<Contact> _contacts = [];
  final List<Category> _categories = [];
  final List<Txn> _txns = [];
  final List<ContactEntry> _entries = [];
  final List<PlannedItem> _planned = [];

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<Account> get activeAccounts =>
      _accounts.where((a) => !a.archived).toList(growable: false);
  List<Contact> get contacts {
    final l = [..._contacts]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> categoriesOf(CategoryKind k) =>
      _categories.where((c) => c.kind == k).toList(growable: false);

  /// Tarihe göre yeniden eskiye sıralı işlemler.
  List<Txn> get txns {
    final l = [..._txns]..sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  List<ContactEntry> get entries => List.unmodifiable(_entries);
  List<PlannedItem> get planned {
    final l = [..._planned]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return l;
  }

  bool get isEmpty =>
      _accounts.isEmpty && _txns.isEmpty && _contacts.isEmpty && _planned.isEmpty;

  Account? account(String? id) => _find(_accounts, id, (a) => a.id);
  Contact? contact(String? id) => _find(_contacts, id, (c) => c.id);
  Category? category(String? id) => _find(_categories, id, (c) => c.id);
  PlannedItem? plannedItem(String? id) => _find(_planned, id, (p) => p.id);

  static T? _find<T>(List<T> list, String? id, String Function(T) key) {
    if (id == null) return null;
    for (final x in list) {
      if (key(x) == id) return x;
    }
    return null;
  }

  // ---- Hesaplanan değerler -----------------------------------------------

  int balanceOf(Account a) => accountBalance(a, _txns);
  int get totalCash => totalBalance(_accounts, _txns);
  int contactBalanceOf(Contact c) => contactBalance(c, _entries, _txns);

  /// Toplam alacak (carilerin bize borcu) ve toplam borç (bizim carilere borcumuz).
  (int receivable, int payable) get contactTotals {
    var r = 0, p = 0;
    for (final c in _contacts) {
      final b = contactBalanceOf(c);
      if (b > 0) r += b;
      if (b < 0) p -= b;
    }
    return (r, p);
  }

  // ---- Yükleme / kaydetme ------------------------------------------------

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw == null) {
      _categories
        ..clear()
        ..addAll(defaultCategories());
      await _save();
    } else {
      try {
        _apply(jsonDecode(raw) as Map<String, Object?>);
      } catch (e) {
        debugPrint('Veri okunamadı: $e');
        _categories
          ..clear()
          ..addAll(defaultCategories());
      }
    }
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'accounts': [for (final x in _accounts) x.toJson()],
    'contacts': [for (final x in _contacts) x.toJson()],
    'categories': [for (final x in _categories) x.toJson()],
    'txns': [for (final x in _txns) x.toJson()],
    'entries': [for (final x in _entries) x.toJson()],
    'planned': [for (final x in _planned) x.toJson()],
  };

  void _apply(Map<String, Object?> j) {
    List<Map<String, Object?>> list(String k) =>
        ((j[k] as List?) ?? const []).cast<Map<String, Object?>>();
    final accounts = list('accounts').map(Account.fromJson).toList();
    final contacts = list('contacts').map(Contact.fromJson).toList();
    final categories = list('categories').map(Category.fromJson).toList();
    final txns = list('txns').map(Txn.fromJson).toList();
    final entries = list('entries').map(ContactEntry.fromJson).toList();
    final planned = list('planned').map(PlannedItem.fromJson).toList();
    // Hepsi başarıyla ayrıştırıldıktan sonra değiştir: yarım veri kalmasın.
    _accounts
      ..clear()
      ..addAll(accounts);
    _contacts
      ..clear()
      ..addAll(contacts);
    _categories
      ..clear()
      ..addAll(categories.isEmpty ? defaultCategories() : categories);
    _txns
      ..clear()
      ..addAll(txns);
    _entries
      ..clear()
      ..addAll(entries);
    _planned
      ..clear()
      ..addAll(planned);
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, jsonEncode(toJson()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  /// Yedekten geri yükler. Geçersiz JSON'da [FormatException] fırlatır,
  /// mevcut veriye dokunmaz.
  Future<void> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?> || !decoded.containsKey('accounts')) {
      throw const FormatException('Bu bir finans yedeği değil.');
    }
    _apply(decoded);
    notifyListeners();
    await _save();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<void> resetAll() async {
    _accounts.clear();
    _contacts.clear();
    _txns.clear();
    _entries.clear();
    _planned.clear();
    _categories
      ..clear()
      ..addAll(defaultCategories());
    notifyListeners();
    await _save();
  }

  // ---- Hesaplar ----------------------------------------------------------

  void upsertAccount(Account a) {
    _upsert(_accounts, a, (x) => x.id);
    _changed();
  }

  /// Hesaba bağlı işlem varsa silinmez, arşivlenir. Silindiyse `true`.
  bool deleteAccount(String id) {
    final used = _txns.any((t) => t.accountId == id || t.toAccountId == id);
    if (used) {
      final a = account(id);
      if (a != null) _upsert(_accounts, a.copyWith(archived: true), (x) => x.id);
    } else {
      _accounts.removeWhere((a) => a.id == id);
      for (var i = 0; i < _planned.length; i++) {
        final p = _planned[i];
        if (p.accountId == id) {
          _planned[i] = PlannedItem.fromJson({...p.toJson(), 'accountId': null});
        }
      }
    }
    _changed();
    return !used;
  }

  // ---- Cariler -----------------------------------------------------------

  void upsertContact(Contact c) {
    _upsert(_contacts, c, (x) => x.id);
    _changed();
  }

  /// Cariyi ve cari hareketlerini siler; işlemler kalır ama cari bağlantısı kalkar.
  void deleteContact(String id) {
    _contacts.removeWhere((c) => c.id == id);
    _entries.removeWhere((e) => e.contactId == id);
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      if (t.contactId == id) _txns[i] = _withoutContact(t);
    }
    for (var i = 0; i < _planned.length; i++) {
      final p = _planned[i];
      if (p.contactId == id) {
        _planned[i] = PlannedItem.fromJson({...p.toJson(), 'contactId': null});
      }
    }
    _changed();
  }

  static Txn _withoutContact(Txn t) => Txn.fromJson({...t.toJson(), 'contactId': null});

  void upsertEntry(ContactEntry e) {
    _upsert(_entries, e, (x) => x.id);
    _changed();
  }

  void deleteEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    _changed();
  }

  // ---- Kategoriler -------------------------------------------------------

  void upsertCategory(Category c) {
    _upsert(_categories, c, (x) => x.id);
    _changed();
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      if (t.categoryId == id) {
        _txns[i] = Txn.fromJson({...t.toJson(), 'categoryId': null});
      }
    }
    _changed();
  }

  // ---- İşlemler ----------------------------------------------------------

  void upsertTxn(Txn t) {
    _upsert(_txns, t, (x) => x.id);
    _changed();
  }

  void deleteTxn(String id) {
    _txns.removeWhere((t) => t.id == id);
    _changed();
  }

  // ---- Planlı ödeme / tahsilatlar ----------------------------------------

  void upsertPlanned(PlannedItem p) {
    _upsert(_planned, p, (x) => x.id);
    _changed();
  }

  void deletePlanned(String id) {
    _planned.removeWhere((p) => p.id == id);
    _changed();
  }

  /// Planlı kalemi gerçekleştirir: [accountId] hesabında bir gelir/gider işlemi
  /// oluşturur. Tekrarlayan kalemde vade bir sonrakine ilerler; son vade
  /// geçildiyse ya da tekrar yoksa kalem tamamlanır.
  Txn completePlanned(
    PlannedItem p, {
    required String accountId,
    DateTime? date,
    int? amount,
  }) {
    final txn = Txn(
      id: newId(),
      type: p.kind == PlannedKind.collection ? TxnType.income : TxnType.expense,
      amount: amount ?? p.amount,
      date: date ?? DateTime.now(),
      accountId: accountId,
      categoryId: p.categoryId,
      contactId: p.contactId,
      note: p.title,
      plannedId: p.id,
    );
    _txns.add(txn);
    final next = nextOccurrence(p.dueDate, p.recurrence);
    final finished =
        p.recurrence == Recurrence.none ||
        (p.endDate != null && next.isAfter(dateOnly(p.endDate!)));
    _upsert(
      _planned,
      finished ? p.copyWith(completed: true) : p.copyWith(dueDate: next),
      (x) => x.id,
    );
    _changed();
    return txn;
  }

  /// Tekrarlayan kalemin yalnızca bu vadesini atlar.
  void skipPlanned(PlannedItem p) {
    final next = nextOccurrence(p.dueDate, p.recurrence);
    final finished =
        p.recurrence == Recurrence.none ||
        (p.endDate != null && next.isAfter(dateOnly(p.endDate!)));
    _upsert(
      _planned,
      finished ? p.copyWith(completed: true) : p.copyWith(dueDate: next),
      (x) => x.id,
    );
    _changed();
  }

  static void _upsert<T>(List<T> list, T item, String Function(T) key) {
    final i = list.indexWhere((x) => key(x) == key(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  /// Toplu veri ekleme (demo verisi için) — tek kayıt, tek bildirim.
  void addAll({
    List<Account> accounts = const [],
    List<Contact> contacts = const [],
    List<Txn> txns = const [],
    List<ContactEntry> entries = const [],
    List<PlannedItem> planned = const [],
  }) {
    _accounts.addAll(accounts);
    _contacts.addAll(contacts);
    _txns.addAll(txns);
    _entries.addAll(entries);
    _planned.addAll(planned);
    _changed();
  }
}
