/// Uygulamanın veri modelleri.
///
/// Tutarlar kuruş cinsinden `int` olarak tutulur (ör. 1.250,75 ₺ → 125075);
/// böylece toplamalarda kayan nokta hatası oluşmaz.
library;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime _date(Object? v) => DateTime.parse(v as String);
DateTime? _dateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String);

// ---------------------------------------------------------------------------
// Banka / kasa hesapları
// ---------------------------------------------------------------------------

enum AccountType { bank, cash, creditCard, savings }

class Account {
  final String id;
  final String name;
  final AccountType type;
  final String bankName;
  final String iban;

  /// Hesap açılış bakiyesi (kuruş). Kredi kartında borç negatif girilir.
  final int openingBalance;
  final int colorValue;
  final bool archived;

  /// Para birimi kodu: `TRY`, `USD` veya `EUR`. Hesabın tüm tutarları bu birimdedir.
  final String currency;

  const Account({
    required this.id,
    required this.name,
    this.type = AccountType.bank,
    this.bankName = '',
    this.iban = '',
    this.openingBalance = 0,
    this.colorValue = 0xFF3F51B5,
    this.archived = false,
    this.currency = 'TRY',
  });

  bool get isForeign => currency != 'TRY';

  Account copyWith({
    String? name,
    AccountType? type,
    String? bankName,
    String? iban,
    int? openingBalance,
    int? colorValue,
    bool? archived,
    String? currency,
  }) => Account(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    bankName: bankName ?? this.bankName,
    iban: iban ?? this.iban,
    openingBalance: openingBalance ?? this.openingBalance,
    colorValue: colorValue ?? this.colorValue,
    archived: archived ?? this.archived,
    currency: currency ?? this.currency,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'bankName': bankName,
    'iban': iban,
    'openingBalance': openingBalance,
    'color': colorValue,
    'archived': archived,
    'currency': currency,
  };

  factory Account.fromJson(Map<String, Object?> j) => Account(
    id: j['id'] as String,
    name: j['name'] as String,
    type: _enumByName(AccountType.values, j['type'], AccountType.bank),
    bankName: (j['bankName'] as String?) ?? '',
    iban: (j['iban'] as String?) ?? '',
    openingBalance: (j['openingBalance'] as num?)?.toInt() ?? 0,
    colorValue: (j['color'] as num?)?.toInt() ?? 0xFF3F51B5,
    archived: (j['archived'] as bool?) ?? false,
    currency: (j['currency'] as String?) ?? 'TRY',
  );
}

// ---------------------------------------------------------------------------
// Cari hesaplar (müşteri / tedarikçi)
// ---------------------------------------------------------------------------

enum ContactType { customer, supplier, both }

class Contact {
  final String id;
  final String name;
  final ContactType type;
  final String phone;
  final String email;
  final String taxNumber;
  final String note;

  /// Açılış bakiyesi (kuruş). Pozitif: cari bize borçlu (alacağımız),
  /// negatif: biz cariye borçluyuz.
  final int openingBalance;

  const Contact({
    required this.id,
    required this.name,
    this.type = ContactType.customer,
    this.phone = '',
    this.email = '',
    this.taxNumber = '',
    this.note = '',
    this.openingBalance = 0,
  });

  Contact copyWith({
    String? name,
    ContactType? type,
    String? phone,
    String? email,
    String? taxNumber,
    String? note,
    int? openingBalance,
  }) => Contact(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    taxNumber: taxNumber ?? this.taxNumber,
    note: note ?? this.note,
    openingBalance: openingBalance ?? this.openingBalance,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'phone': phone,
    'email': email,
    'taxNumber': taxNumber,
    'note': note,
    'openingBalance': openingBalance,
  };

  factory Contact.fromJson(Map<String, Object?> j) => Contact(
    id: j['id'] as String,
    name: j['name'] as String,
    type: _enumByName(ContactType.values, j['type'], ContactType.customer),
    phone: (j['phone'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    taxNumber: (j['taxNumber'] as String?) ?? '',
    note: (j['note'] as String?) ?? '',
    openingBalance: (j['openingBalance'] as num?)?.toInt() ?? 0,
  );
}

// ---------------------------------------------------------------------------
// Kategoriler
// ---------------------------------------------------------------------------

enum CategoryKind { income, expense }

class Category {
  final String id;
  final String name;
  final CategoryKind kind;

  /// `ui/category_icons.dart` içindeki sabit ikon tablosunun anahtarı.
  final String icon;
  final int colorValue;

  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.icon = 'other',
    this.colorValue = 0xFF607D8B,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'icon': icon,
    'color': colorValue,
  };

  factory Category.fromJson(Map<String, Object?> j) => Category(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: _enumByName(CategoryKind.values, j['kind'], CategoryKind.expense),
    icon: (j['icon'] as String?) ?? 'other',
    colorValue: (j['color'] as num?)?.toInt() ?? 0xFF607D8B,
  );
}

// ---------------------------------------------------------------------------
// Gerçekleşen para hareketleri
// ---------------------------------------------------------------------------

enum TxnType { income, expense, transfer }

class Txn {
  final String id;
  final TxnType type;

  /// Her zaman pozitif, hesabın para biriminde kuruş/sent. Yönü [type] belirler.
  final int amount;

  /// [accountId] hesabının para birimi (kayıt anında kopyalanır).
  final String currency;

  /// İşlem anındaki kur: 1 birim [currency] = [rate] ₺. TL işlemlerde 1.
  final double rate;

  /// Farklı para birimli hesaplar arası transferde hedef hesaba geçen tutar
  /// (hedef hesabın biriminde). `null` ise [amount] ile aynıdır.
  final int? toAmount;
  final DateTime date;
  final String accountId;

  /// Yalnızca transferlerde: paranın gittiği hesap.
  final String? toAccountId;
  final String? categoryId;
  final String? contactId;
  final String note;

  /// Bu işlem planlı bir ödeme/tahsilatın gerçekleşmesiyle oluştuysa onun id'si.
  final String? plannedId;

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.contactId,
    this.note = '',
    this.plannedId,
    this.currency = 'TRY',
    this.rate = 1,
    this.toAmount,
  });

  /// İşlemin işlem anındaki kurla ₺ karşılığı (kuruş).
  int get tryAmount => currency == 'TRY' ? amount : (amount * rate).round();

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'currency': currency,
    'rate': rate,
    'toAmount': toAmount,
    'date': date.toIso8601String(),
    'accountId': accountId,
    'toAccountId': toAccountId,
    'categoryId': categoryId,
    'contactId': contactId,
    'note': note,
    'plannedId': plannedId,
  };

  factory Txn.fromJson(Map<String, Object?> j) => Txn(
    id: j['id'] as String,
    type: _enumByName(TxnType.values, j['type'], TxnType.expense),
    amount: (j['amount'] as num).toInt(),
    date: _date(j['date']),
    accountId: j['accountId'] as String,
    toAccountId: j['toAccountId'] as String?,
    categoryId: j['categoryId'] as String?,
    contactId: j['contactId'] as String?,
    note: (j['note'] as String?) ?? '',
    plannedId: j['plannedId'] as String?,
    currency: (j['currency'] as String?) ?? 'TRY',
    rate: (j['rate'] as num?)?.toDouble() ?? 1,
    toAmount: (j['toAmount'] as num?)?.toInt(),
  );
}

// ---------------------------------------------------------------------------
// Cari hareketleri (fatura / borçlandırma — kasaya dokunmaz)
// ---------------------------------------------------------------------------

enum EntryType {
  /// Cariye satış / borç dekontu: carinin bize borcu artar.
  sale,

  /// Cariden alış / alacak dekontu: bizim cariye borcumuz artar.
  purchase,
}

class ContactEntry {
  final String id;
  final String contactId;
  final EntryType type;
  final int amount;
  final DateTime date;
  final String note;

  const ContactEntry({
    required this.id,
    required this.contactId,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'contactId': contactId,
    'type': type.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory ContactEntry.fromJson(Map<String, Object?> j) => ContactEntry(
    id: j['id'] as String,
    contactId: j['contactId'] as String,
    type: _enumByName(EntryType.values, j['type'], EntryType.sale),
    amount: (j['amount'] as num).toInt(),
    date: _date(j['date']),
    note: (j['note'] as String?) ?? '',
  );
}

// ---------------------------------------------------------------------------
// Yaklaşan ödemeler / tahsilatlar
// ---------------------------------------------------------------------------

enum PlannedKind { payment, collection }

enum Recurrence { none, weekly, monthly, quarterly, yearly }

class PlannedItem {
  final String id;
  final PlannedKind kind;
  final String title;
  final int amount;

  /// Bir sonraki vade tarihi.
  final DateTime dueDate;
  final String? accountId;
  final String? categoryId;
  final String? contactId;
  final String note;
  final Recurrence recurrence;

  /// Tekrarlayan kalemlerde son vade (dahil). `null` ise süresiz.
  final DateTime? endDate;
  final bool completed;

  /// Tutarın para birimi.
  final String currency;

  const PlannedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.accountId,
    this.categoryId,
    this.contactId,
    this.note = '',
    this.recurrence = Recurrence.none,
    this.endDate,
    this.completed = false,
    this.currency = 'TRY',
  });

  PlannedItem copyWith({DateTime? dueDate, bool? completed}) => PlannedItem(
    id: id,
    kind: kind,
    title: title,
    amount: amount,
    dueDate: dueDate ?? this.dueDate,
    accountId: accountId,
    categoryId: categoryId,
    contactId: contactId,
    note: note,
    recurrence: recurrence,
    endDate: endDate,
    completed: completed ?? this.completed,
    currency: currency,
  );

  /// Nakit akışına etkisi: tahsilat +, ödeme −.
  int get signedAmount => kind == PlannedKind.collection ? amount : -amount;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'amount': amount,
    'dueDate': dueDate.toIso8601String(),
    'accountId': accountId,
    'categoryId': categoryId,
    'contactId': contactId,
    'note': note,
    'recurrence': recurrence.name,
    'endDate': endDate?.toIso8601String(),
    'completed': completed,
    'currency': currency,
  };

  factory PlannedItem.fromJson(Map<String, Object?> j) => PlannedItem(
    id: j['id'] as String,
    kind: _enumByName(PlannedKind.values, j['kind'], PlannedKind.payment),
    title: j['title'] as String,
    amount: (j['amount'] as num).toInt(),
    dueDate: _date(j['dueDate']),
    accountId: j['accountId'] as String?,
    categoryId: j['categoryId'] as String?,
    contactId: j['contactId'] as String?,
    note: (j['note'] as String?) ?? '',
    recurrence: _enumByName(Recurrence.values, j['recurrence'], Recurrence.none),
    endDate: _dateOrNull(j['endDate']),
    completed: (j['completed'] as bool?) ?? false,
    currency: (j['currency'] as String?) ?? 'TRY',
  );
}
