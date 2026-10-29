import '../models/models.dart';

/// İlk açılışta yüklenen kategoriler. Id'ler sabittir; demo verisi bunlara bağlanır.
List<Category> defaultCategories() => const [
  // Gelir
  Category(id: 'inc_sales', name: 'Satış', kind: CategoryKind.income, icon: 'store', colorValue: 0xFF2E7D32),
  Category(id: 'inc_service', name: 'Hizmet geliri', kind: CategoryKind.income, icon: 'work', colorValue: 0xFF00897B),
  Category(id: 'inc_salary', name: 'Maaş', kind: CategoryKind.income, icon: 'wallet', colorValue: 0xFF43A047),
  Category(id: 'inc_interest', name: 'Faiz / yatırım', kind: CategoryKind.income, icon: 'trending', colorValue: 0xFF7CB342),
  Category(id: 'inc_rent', name: 'Kira geliri', kind: CategoryKind.income, icon: 'home', colorValue: 0xFF26A69A),
  Category(id: 'inc_other', name: 'Diğer gelir', kind: CategoryKind.income, icon: 'other', colorValue: 0xFF66BB6A),
  // Gider
  Category(id: 'exp_rent', name: 'Kira', kind: CategoryKind.expense, icon: 'home', colorValue: 0xFF5E35B1),
  Category(id: 'exp_salary', name: 'Personel / maaş', kind: CategoryKind.expense, icon: 'people', colorValue: 0xFF3949AB),
  Category(id: 'exp_bills', name: 'Faturalar', kind: CategoryKind.expense, icon: 'bolt', colorValue: 0xFFF9A825),
  Category(id: 'exp_purchase', name: 'Mal / hizmet alımı', kind: CategoryKind.expense, icon: 'cart', colorValue: 0xFFEF6C00),
  Category(id: 'exp_tax', name: 'Vergi / SGK', kind: CategoryKind.expense, icon: 'bank', colorValue: 0xFFC62828),
  Category(id: 'exp_transport', name: 'Ulaşım / yakıt', kind: CategoryKind.expense, icon: 'car', colorValue: 0xFF00838F),
  Category(id: 'exp_food', name: 'Yemek / market', kind: CategoryKind.expense, icon: 'food', colorValue: 0xFFD81B60),
  Category(id: 'exp_marketing', name: 'Pazarlama', kind: CategoryKind.expense, icon: 'campaign', colorValue: 0xFF8E24AA),
  Category(id: 'exp_software', name: 'Yazılım / abonelik', kind: CategoryKind.expense, icon: 'cloud', colorValue: 0xFF1E88E5),
  Category(id: 'exp_loan', name: 'Kredi / taksit', kind: CategoryKind.expense, icon: 'card', colorValue: 0xFF6D4C41),
  Category(id: 'exp_other', name: 'Diğer gider', kind: CategoryKind.expense, icon: 'other', colorValue: 0xFF757575),
];
