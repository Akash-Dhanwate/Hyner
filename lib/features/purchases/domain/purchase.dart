import '../../inventory/domain/product.dart';

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SupplierDraft {
  const SupplierDraft({required this.name, this.phone = '', this.notes = ''});
  final String name;
  final String phone;
  final String notes;

  void validate() {
    if (name.trim().isEmpty || name != name.trim() || name.length > 120) {
      throw const FormatException('Enter a supplier name of 1–120 characters.');
    }
    if (phone.length > 40 || notes.length > 500) {
      throw const FormatException(
        'Phone must be under 40 characters and notes under 500.',
      );
    }
  }
}

class PurchaseLine {
  const PurchaseLine({
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unitCostMinor,
  });

  final String sku;
  final String name;
  final int quantity;
  final int unitCostMinor;
  int get totalMinor => quantity * unitCostMinor;

  void validate() {
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$').hasMatch(sku) ||
        name.trim().isEmpty ||
        name.length > 120 ||
        quantity < 1 ||
        quantity > maxStock ||
        unitCostMinor < 0 ||
        unitCostMinor > maxMoneyMinor ~/ quantity) {
      throw inventoryInvalid(
        'Enter a valid product, quantity and purchase cost.',
      );
    }
  }
}

class PurchaseDraft {
  PurchaseDraft({
    required this.currency,
    required List<PurchaseLine> lines,
    this.supplierId,
    this.supplierName,
    this.supplierPhone,
  }) : lines = List.unmodifiable(lines);

  final String currency;
  final List<PurchaseLine> lines;
  final String? supplierId;
  final String? supplierName;
  final String? supplierPhone;
  int get totalMinor => lines.fold(0, (sum, line) => sum + line.totalMinor);
  int get units => lines.fold(0, (sum, line) => sum + line.quantity);

  void validate() {
    if (!inventoryCurrencies.contains(currency) ||
        lines.isEmpty ||
        lines.map((line) => line.sku).toSet().length != lines.length) {
      throw inventoryInvalid('Choose different products in the same currency.');
    }
    if ((supplierId == null) != (supplierName == null) ||
        supplierName != null && supplierName!.trim().isEmpty ||
        supplierName != null && supplierName!.length > 120) {
      throw inventoryInvalid(
        'Choose a valid supplier or leave the supplier blank.',
      );
    }
    for (final line in lines) {
      line.validate();
    }
    if (totalMinor > maxMoneyMinor) {
      throw inventoryInvalid('This purchase total is too large.');
    }
  }

  bool matches(PurchaseDraft other) =>
      currency == other.currency &&
      supplierId == other.supplierId &&
      supplierName == other.supplierName &&
      lines.length == other.lines.length &&
      lines.every(
        (line) => other.lines.any(
          (otherLine) =>
              otherLine.sku == line.sku &&
              otherLine.quantity == line.quantity &&
              otherLine.unitCostMinor == line.unitCostMinor,
        ),
      );
}

enum PurchasePaymentStatus { unpaid, paid }

class Purchase {
  const Purchase({
    required this.id,
    required this.draft,
    required this.createdAt,
    required this.returnedQuantities,
    this.paymentStatus = PurchasePaymentStatus.unpaid,
    this.paidAt,
  });

  final String id;
  final PurchaseDraft draft;
  final DateTime createdAt;
  final Map<String, int> returnedQuantities;
  final PurchasePaymentStatus paymentStatus;
  final DateTime? paidAt;

  int returnedQuantity(String sku) => returnedQuantities[sku] ?? 0;
  int get returnedTotalMinor => draft.lines.fold(
    0,
    (sum, line) => sum + line.unitCostMinor * returnedQuantity(line.sku),
  );
}

class PurchaseReturnLine {
  const PurchaseReturnLine({
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unitCostMinor,
  });
  final String sku, name;
  final int quantity, unitCostMinor;
  int get totalMinor => quantity * unitCostMinor;
}

class PurchaseReturn {
  const PurchaseReturn({
    required this.id,
    required this.purchaseId,
    required this.lines,
    required this.reason,
    required this.createdAt,
  });
  final String id, purchaseId, reason;
  final List<PurchaseReturnLine> lines;
  final DateTime createdAt;
  int get totalMinor => lines.fold(0, (sum, line) => sum + line.totalMinor);
}
