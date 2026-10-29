import '../../inventory/domain/product.dart';

const expenseCategories = [
  'Rent',
  'Salary',
  'Utilities',
  'Transport',
  'Marketing',
  'Maintenance',
  'Other',
];

class OperatingExpense {
  const OperatingExpense({
    required this.id,
    required this.category,
    required this.description,
    required this.currency,
    required this.amountMinor,
    required this.occurredAt,
  });

  final String id;
  final String category;
  final String description;
  final String currency;
  final int amountMinor;
  final DateTime occurredAt;
}

class OperatingExpenseDraft {
  const OperatingExpenseDraft({
    required this.category,
    required this.description,
    required this.currency,
    required this.amountMinor,
    required this.occurredAt,
  });

  final String category;
  final String description;
  final String currency;
  final int amountMinor;
  final DateTime occurredAt;

  void validate() {
    if (!expenseCategories.contains(category) ||
        description.trim().isEmpty ||
        description.trim().length > 120 ||
        !inventoryCurrencies.contains(currency) ||
        amountMinor < 1 ||
        amountMinor > maxMoneyMinor) {
      throw const FormatException('Enter a valid expense and amount.');
    }
  }
}
