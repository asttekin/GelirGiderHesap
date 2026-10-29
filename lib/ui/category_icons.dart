import 'package:flutter/material.dart';

import '../models/models.dart';

/// Kategori ikon anahtarları → sabit ikonlar. İkonların sabit tutulması
/// sürüm derlemesinde ikon yazı tipinin küçültülmesine (tree-shaking) izin verir.
const categoryIcons = <String, IconData>{
  'store': Icons.storefront_outlined,
  'work': Icons.work_outline,
  'wallet': Icons.account_balance_wallet_outlined,
  'trending': Icons.trending_up,
  'home': Icons.home_outlined,
  'people': Icons.groups_outlined,
  'bolt': Icons.bolt_outlined,
  'cart': Icons.shopping_cart_outlined,
  'bank': Icons.account_balance_outlined,
  'car': Icons.directions_car_outlined,
  'food': Icons.restaurant_outlined,
  'campaign': Icons.campaign_outlined,
  'cloud': Icons.cloud_outlined,
  'card': Icons.credit_card_outlined,
  'health': Icons.local_hospital_outlined,
  'school': Icons.school_outlined,
  'gift': Icons.card_giftcard_outlined,
  'travel': Icons.flight_outlined,
  'phone': Icons.phone_android_outlined,
  'tools': Icons.build_outlined,
  'other': Icons.category_outlined,
};

IconData iconForCategory(Category? c) =>
    categoryIcons[c?.icon] ?? Icons.category_outlined;

IconData iconForAccount(AccountType t) => switch (t) {
  AccountType.bank => Icons.account_balance_outlined,
  AccountType.cash => Icons.payments_outlined,
  AccountType.creditCard => Icons.credit_card_outlined,
  AccountType.savings => Icons.savings_outlined,
};

String accountTypeLabel(AccountType t) => switch (t) {
  AccountType.bank => 'Vadesiz hesap',
  AccountType.cash => 'Nakit / kasa',
  AccountType.creditCard => 'Kredi kartı',
  AccountType.savings => 'Birikim / vadeli',
};

String contactTypeLabel(ContactType t) => switch (t) {
  ContactType.customer => 'Müşteri',
  ContactType.supplier => 'Tedarikçi',
  ContactType.both => 'Müşteri + tedarikçi',
};

String recurrenceLabel(Recurrence r) => switch (r) {
  Recurrence.none => 'Tek seferlik',
  Recurrence.weekly => 'Her hafta',
  Recurrence.monthly => 'Her ay',
  Recurrence.quarterly => '3 ayda bir',
  Recurrence.yearly => 'Her yıl',
};

/// Hesap / kategori renk seçimi için palet.
const pickerColors = <int>[
  0xFF3F51B5, 0xFF1E88E5, 0xFF00897B, 0xFF43A047, 0xFF7CB342, 0xFFF9A825,
  0xFFEF6C00, 0xFFD84315, 0xFFC62828, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1,
  0xFF6D4C41, 0xFF546E7A, 0xFF212121,
];
