class ProductSalesStat {
  const ProductSalesStat({
    required this.sku,
    required this.name,
    required this.units,
    required this.revenueMinor,
  });
  final String sku;
  final String name;
  final int units;
  final BigInt revenueMinor;
}

class ReportActivityPoint {
  const ReportActivityPoint({
    required this.periodStart,
    required this.label,
    required this.revenueMinor,
    required this.expenseMinor,
  });

  final DateTime periodStart;
  final String label;
  final BigInt revenueMinor;
  final BigInt expenseMinor;
}

class ReportSaleRecord {
  const ReportSaleRecord({
    required this.date,
    required this.reference,
    required this.customer,
    required this.totalMinor,
    required this.paidMinor,
    required this.remainingMinor,
  });

  final DateTime date;
  final String reference;
  final String customer;
  final BigInt totalMinor;
  final BigInt paidMinor;
  final BigInt remainingMinor;
}

class ReportPurchaseRecord {
  const ReportPurchaseRecord({
    required this.date,
    required this.reference,
    required this.supplier,
    required this.amountMinor,
  });

  final DateTime date;
  final String reference;
  final String supplier;
  final BigInt amountMinor;
}

class ReportExpenseRecord {
  const ReportExpenseRecord({
    required this.date,
    required this.category,
    required this.description,
    required this.amountMinor,
  });

  final DateTime date;
  final String category;
  final String description;
  final BigInt amountMinor;
}

class BusinessReport {
  const BusinessReport({
    required this.currency,
    required this.start,
    required this.end,
    required this.salesCount,
    required this.soldUnits,
    required this.paidSalesCount,
    required this.unpaidSalesCount,
    required this.revenueMinor,
    required this.paidRevenueMinor,
    required this.unpaidRevenueMinor,
    required this.trackedRevenueMinor,
    required this.costOfGoodsMinor,
    required this.grossProfitMinor,
    required this.uncostedSalesCount,
    required this.purchaseCount,
    required this.purchaseSpendMinor,
    required this.returnValueMinor,
    required this.inventoryValueMinor,
    required this.topProducts,
    this.activity = const [],
    this.salesRecords = const [],
    this.purchaseRecords = const [],
    this.otherExpenseCount = 0,
    this.otherExpenseMinor,
    this.expenseRecords = const [],
  });

  final String currency;
  final DateTime start;
  final DateTime end;
  final int salesCount;
  final int soldUnits;
  final int paidSalesCount;
  final int unpaidSalesCount;
  final BigInt revenueMinor;
  final BigInt paidRevenueMinor;
  final BigInt unpaidRevenueMinor;
  final BigInt trackedRevenueMinor;
  final BigInt costOfGoodsMinor;
  final BigInt grossProfitMinor;
  final int uncostedSalesCount;
  final int purchaseCount;
  final BigInt purchaseSpendMinor;
  final BigInt returnValueMinor;
  final BigInt inventoryValueMinor;
  final List<ProductSalesStat> topProducts;
  final List<ReportActivityPoint> activity;
  final List<ReportSaleRecord> salesRecords;
  final List<ReportPurchaseRecord> purchaseRecords;
  final int otherExpenseCount;
  final BigInt? otherExpenseMinor;
  final List<ReportExpenseRecord> expenseRecords;
  BigInt get operatingExpensesMinor => otherExpenseMinor ?? BigInt.zero;
  BigInt get netPurchasesMinor => purchaseSpendMinor - returnValueMinor;
  BigInt get totalExpenseMinor => netPurchasesMinor + operatingExpensesMinor;
}

String formatBigMoney(BigInt minor, String currency) {
  final absolute = minor.abs();
  final whole = absolute ~/ BigInt.from(100);
  final fraction = (absolute % BigInt.from(100)).toString().padLeft(2, '0');
  return '${minor.isNegative ? '-' : ''}$currency $whole.$fraction';
}
