import '../../../core/errors/app_failure.dart';

const maxStock = 1000000000;
const maxMoneyMinor = 999999999999;
const inventoryCurrencies = ['INR', 'USD', 'EUR', 'GBP'];

AppFailure inventoryInvalid(String message) =>
    AppFailure(FailureKind.invalidData, message);

String normalizeSku(String value) => value.trim().toUpperCase();

int parseUnits(String value, {bool allowZero = true}) {
  final text = value.trim();
  final number = RegExp(r'^\d{1,10}$').hasMatch(text)
      ? int.tryParse(text)
      : null;
  if (number == null || number > maxStock || number < (allowZero ? 0 : 1)) {
    throw inventoryInvalid(
      allowZero
          ? 'Enter whole units from 0 to 1,000,000,000.'
          : 'Enter whole units from 1 to 1,000,000,000.',
    );
  }
  return number;
}

int parseMoney(String value) {
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$')
      .firstMatch(value.trim());
  if (match == null) {
    throw inventoryInvalid(
      'Enter a non-negative price with up to 2 decimal places.',
    );
  }
  final result =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  if (result > maxMoneyMinor) {
    throw inventoryInvalid('This price is too large.');
  }
  return result;
}

String moneyDecimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
String formatMoney(int minor, String currency) =>
    '$currency ${moneyDecimal(minor)}';

class ProductDraft {
  ProductDraft({
    required this.sku,
    required this.name,
    this.category = '',
    required this.currency,
    required this.costMinor,
    required this.priceMinor,
    required this.openingStock,
    required this.reorderLevel,
    List<ProductParameter> parameters = const [],
  }) : parameters = List.unmodifiable(parameters);
  final String sku;
  final String name;
  final String category;
  final String currency;
  final int costMinor;
  final int priceMinor;
  final int openingStock;
  final int reorderLevel;
  final List<ProductParameter> parameters;

  void validate() {
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$').hasMatch(sku)) {
      throw inventoryInvalid(
        'Use 1–40 letters, numbers, hyphens or underscores for the product code.',
      );
    }
    if (name.trim().isEmpty || name != name.trim() || name.length > 120) {
      throw inventoryInvalid('Enter a product name of 1–120 characters.');
    }
    if (category.length > 80 || category != category.trim()) {
      throw inventoryInvalid('Category must be at most 80 characters.');
    }
    if (!inventoryCurrencies.contains(currency)) {
      throw inventoryInvalid('Choose a supported currency.');
    }
    if (costMinor < 0 ||
        priceMinor < 0 ||
        costMinor > maxMoneyMinor ||
        priceMinor > maxMoneyMinor) {
      throw inventoryInvalid('Enter valid, non-negative prices.');
    }
    if (openingStock < 0 ||
        openingStock > maxStock ||
        reorderLevel < 0 ||
        reorderLevel > maxStock) {
      throw inventoryInvalid(
        'Stock and low-stock threshold must be valid whole units.',
      );
    }
    ProductParameter.validateList(parameters);
  }
}

class ProductParameter {
  const ProductParameter({required this.name, required this.value});

  final String name;
  final String value;

  Map<String, String> toMap() => {'name': name, 'value': value};

  static ProductParameter fromMap(Map<dynamic, dynamic> map) =>
      ProductParameter(
        name: map['name'] as String,
        value: map['value'] as String,
      );

  static void validateList(List<ProductParameter> parameters) {
    if (parameters.length > 20) {
      throw inventoryInvalid('Add up to 20 product parameters.');
    }
    final names = <String>{};
    for (final parameter in parameters) {
      final name = parameter.name.trim();
      final value = parameter.value.trim();
      if (name.isEmpty ||
          name.length > 60 ||
          value.isEmpty ||
          value.length > 120) {
        throw inventoryInvalid(
          'Each product parameter needs a name (up to 60 characters) and value (up to 120 characters).',
        );
      }
      if (!names.add(name.toLowerCase())) {
        throw inventoryInvalid('Product parameter names must be unique.');
      }
    }
  }
}

class Product {
  const Product({
    required this.sku,
    required this.name,
    required this.category,
    required this.currency,
    required this.costMinor,
    required this.priceMinor,
    required this.quantity,
    required this.reorderLevel,
    required this.archived,
    required this.revision,
    required this.lastMovementId,
    required this.createdAt,
    required this.updatedAt,
    this.parameters = const [],
  });
  final String sku;
  final String name;
  final String category;
  final String currency;
  final int costMinor;
  final int priceMinor;
  final int quantity;
  final int reorderLevel;
  final bool archived;
  final int revision;
  final String lastMovementId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductParameter> parameters;
  bool get isLowStock => !archived && quantity <= reorderLevel;

  ProductDraft get draft => ProductDraft(
    sku: sku,
    name: name,
    category: category,
    currency: currency,
    costMinor: costMinor,
    priceMinor: priceMinor,
    openingStock: quantity,
    reorderLevel: reorderLevel,
    parameters: parameters,
  );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.type,
    required this.beforeQuantity,
    required this.afterQuantity,
    required this.delta,
    required this.reason,
    required this.actorUid,
    required this.revision,
    required this.createdAt,
  });
  final String id;
  final String type;
  final int beforeQuantity;
  final int afterQuantity;
  final int delta;
  final String reason;
  final String actorUid;
  final int revision;
  final DateTime createdAt;
}
