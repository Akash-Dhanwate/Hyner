import 'dart:convert';

import '../../../core/storage/local_business_database.dart';
import '../domain/business_report.dart';
import '../domain/reports_repository.dart';

class LocalReportsRepository implements ReportsRepository {
  LocalReportsRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  Future<BusinessReport> load({
    required String uid,
    required String currency,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    if (uid.isEmpty || uid.contains('/')) throw ArgumentError.value(uid, 'uid');
    final db = await _store.databaseFor(uid);
    final from = start.toUtc().toIso8601String();
    final until = endExclusive.toUtc().toIso8601String();
    final rangeDays = endExclusive.difference(start).inDays;
    final monthlyTrend = rangeDays > 90;
    final lastDate = endExclusive
        .subtract(const Duration(microseconds: 1))
        .toLocal();
    final startLocal = start.toLocal();
    final trendStart = monthlyTrend
        ? DateTime(lastDate.year, lastDate.month - 5, 1)
        : DateTime(startLocal.year, startLocal.month, startLocal.day);

    var salesCount = 0;
    var soldUnits = 0;
    var paidSalesCount = 0;
    var unpaidSalesCount = 0;
    var uncostedSalesCount = 0;
    var revenue = BigInt.zero;
    var paidRevenue = BigInt.zero;
    var unpaidRevenue = BigInt.zero;
    var trackedRevenue = BigInt.zero;
    var costOfGoods = BigInt.zero;
    final productStats = <String, _MutableProductStat>{};
    final activityBuckets = <DateTime, _MutableActivityPoint>{};
    final salesRecords = <ReportSaleRecord>[];

    final sales = await db.query(
      'sales',
      where: 'currency = ? AND createdAt >= ? AND createdAt < ?',
      whereArgs: [currency, from, until],
      orderBy: 'createdAt DESC',
    );
    for (final sale in sales) {
      final decoded = jsonDecode(sale['lines']! as String);
      if (decoded is! List) continue;
      final date = DateTime.parse(sale['createdAt']! as String).toLocal();
      salesCount++;
      var saleRevenue = BigInt.zero;
      var saleCost = BigInt.zero;
      var saleUnits = 0;
      var hasCostSnapshot = true;
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic> ||
            raw['sku'] is! String ||
            raw['name'] is! String ||
            raw['quantity'] is! int ||
            raw['unitPriceMinor'] is! int) {
          continue;
        }
        final quantity = raw['quantity'] as int;
        final lineRevenue =
            BigInt.from(raw['unitPriceMinor'] as int) * BigInt.from(quantity);
        saleRevenue += lineRevenue;
        saleUnits += quantity;
        final hasCost =
            raw['unitCostMinor'] is int && (raw['unitCostMinor'] as int) >= 0;
        if (!hasCost) {
          hasCostSnapshot = false;
        } else {
          saleCost +=
              BigInt.from(raw['unitCostMinor'] as int) * BigInt.from(quantity);
        }
        final sku = raw['sku'] as String;
        final stat = productStats.putIfAbsent(
          sku,
          () => _MutableProductStat(sku: sku, name: raw['name'] as String),
        );
        stat.units += quantity;
        stat.revenueMinor += lineRevenue;
      }
      soldUnits += saleUnits;
      revenue += saleRevenue;

      final paidValue = sale['paidMinor'] as int? ?? 0;
      final paidForSale = sale['paymentStatus'] == 'paid' && paidValue == 0
          ? saleRevenue
          : _bounded(BigInt.from(paidValue), BigInt.zero, saleRevenue);
      final remainingForSale = saleRevenue - paidForSale;
      paidRevenue += paidForSale;
      unpaidRevenue += remainingForSale;
      if (remainingForSale == BigInt.zero) {
        paidSalesCount++;
      } else {
        unpaidSalesCount++;
      }

      salesRecords.add(
        ReportSaleRecord(
          date: date,
          reference: sale['id']! as String,
          customer: (sale['customerName'] as String?)?.trim().isNotEmpty == true
              ? sale['customerName'] as String
              : 'Walk-in customer',
          totalMinor: saleRevenue,
          paidMinor: paidForSale,
          remainingMinor: remainingForSale,
        ),
      );
      if (!date.isBefore(trendStart)) {
        final bucket = _bucketStart(date, monthlyTrend);
        activityBuckets
                .putIfAbsent(bucket, _MutableActivityPoint.new)
                .revenueMinor +=
            saleRevenue;
      }

      if (hasCostSnapshot) {
        trackedRevenue += saleRevenue;
        costOfGoods += saleCost;
      } else {
        uncostedSalesCount++;
      }
    }

    final allPurchases = await db.query(
      'purchases',
      columns: ['id', 'currency', 'items', 'createdAt', 'supplierName'],
      where: 'currency = ?',
      whereArgs: [currency],
    );
    final purchaseCurrencyById = <String, String>{};
    var purchaseCount = 0;
    var purchaseSpend = BigInt.zero;
    final purchaseRecords = <ReportPurchaseRecord>[];
    for (final purchase in allPurchases) {
      final id = purchase['id']! as String;
      purchaseCurrencyById[id] = purchase['currency']! as String;
      final createdString = purchase['createdAt']! as String;
      if (createdString.compareTo(from) < 0 ||
          createdString.compareTo(until) >= 0) {
        continue;
      }
      final date = DateTime.parse(createdString).toLocal();
      purchaseCount++;
      final items = jsonDecode(purchase['items']! as String);
      if (items is! List) continue;
      var purchaseTotal = BigInt.zero;
      for (final item in items) {
        if (item is! Map<String, dynamic> ||
            item['quantity'] is! int ||
            item['unitCostMinor'] is! int) {
          continue;
        }
        purchaseTotal +=
            BigInt.from(item['quantity'] as int) *
            BigInt.from(item['unitCostMinor'] as int);
      }
      purchaseSpend += purchaseTotal;
      purchaseRecords.add(
        ReportPurchaseRecord(
          date: date,
          reference: id,
          supplier:
              (purchase['supplierName'] as String?)?.trim().isNotEmpty == true
              ? purchase['supplierName'] as String
              : 'Supplier not set',
          amountMinor: purchaseTotal,
        ),
      );
      if (!date.isBefore(trendStart)) {
        final bucket = _bucketStart(date, monthlyTrend);
        activityBuckets
                .putIfAbsent(bucket, _MutableActivityPoint.new)
                .expenseMinor +=
            purchaseTotal;
      }
    }

    var returnValue = BigInt.zero;
    final returns = await db.query(
      'purchase_returns',
      where: 'createdAt >= ? AND createdAt < ?',
      whereArgs: [from, until],
    );
    for (final record in returns) {
      if (purchaseCurrencyById[record['purchaseId']] != currency) continue;
      final amount = BigInt.from(record['totalMinor']! as int);
      returnValue += amount;
      final date = DateTime.parse(record['createdAt']! as String).toLocal();
      if (!date.isBefore(trendStart)) {
        final bucket = _bucketStart(date, monthlyTrend);
        activityBuckets
                .putIfAbsent(bucket, _MutableActivityPoint.new)
                .expenseMinor -=
            amount;
      }
    }

    var otherExpenseMinor = BigInt.zero;
    var otherExpenseCount = 0;
    final expenseRecords = <ReportExpenseRecord>[];
    final expenses = await db.query(
      'operating_expenses',
      where: 'currency = ? AND occurredAt >= ? AND occurredAt < ?',
      whereArgs: [currency, from, until],
      orderBy: 'occurredAt DESC, id DESC',
    );
    for (final expense in expenses) {
      final date = DateTime.parse(expense['occurredAt']! as String).toLocal();
      final amount = BigInt.from(expense['amountMinor']! as int);
      otherExpenseCount++;
      otherExpenseMinor += amount;
      expenseRecords.add(
        ReportExpenseRecord(
          date: date,
          category: expense['category']! as String,
          description: expense['description']! as String,
          amountMinor: amount,
        ),
      );
      if (!date.isBefore(trendStart)) {
        final bucket = _bucketStart(date, monthlyTrend);
        activityBuckets
                .putIfAbsent(bucket, _MutableActivityPoint.new)
                .expenseMinor +=
            amount;
      }
    }

    var inventoryValue = BigInt.zero;
    final products = await db.query(
      'products',
      columns: ['quantity', 'costMinor'],
      where: 'currency = ? AND archived = 0',
      whereArgs: [currency],
    );
    for (final product in products) {
      inventoryValue +=
          BigInt.from(product['quantity']! as int) *
          BigInt.from(product['costMinor']! as int);
    }

    final activity = <ReportActivityPoint>[];
    if (monthlyTrend) {
      for (var offset = 5; offset >= 0; offset--) {
        final date = DateTime(lastDate.year, lastDate.month - offset, 1);
        final point = activityBuckets[date] ?? _MutableActivityPoint();
        activity.add(
          ReportActivityPoint(
            periodStart: date,
            label: _monthName(date.month),
            revenueMinor: point.revenueMinor,
            expenseMinor: point.expenseMinor,
          ),
        );
      }
    } else {
      for (
        var date = trendStart;
        date.isBefore(endExclusive.toLocal());
        date = date.add(const Duration(days: 1))
      ) {
        final day = DateTime(date.year, date.month, date.day);
        final point = activityBuckets[day] ?? _MutableActivityPoint();
        activity.add(
          ReportActivityPoint(
            periodStart: day,
            label: '${day.day}',
            revenueMinor: point.revenueMinor,
            expenseMinor: point.expenseMinor,
          ),
        );
      }
    }

    final top = productStats.values.toList()
      ..sort((a, b) {
        final byRevenue = b.revenueMinor.compareTo(a.revenueMinor);
        return byRevenue == 0 ? b.units.compareTo(a.units) : byRevenue;
      });
    return BusinessReport(
      currency: currency,
      start: start,
      end: endExclusive,
      salesCount: salesCount,
      soldUnits: soldUnits,
      paidSalesCount: paidSalesCount,
      unpaidSalesCount: unpaidSalesCount,
      revenueMinor: revenue,
      paidRevenueMinor: paidRevenue,
      unpaidRevenueMinor: unpaidRevenue,
      trackedRevenueMinor: trackedRevenue,
      costOfGoodsMinor: costOfGoods,
      grossProfitMinor: trackedRevenue - costOfGoods,
      uncostedSalesCount: uncostedSalesCount,
      purchaseCount: purchaseCount,
      purchaseSpendMinor: purchaseSpend,
      returnValueMinor: returnValue,
      otherExpenseCount: otherExpenseCount,
      otherExpenseMinor: otherExpenseMinor,
      expenseRecords: expenseRecords,
      inventoryValueMinor: inventoryValue,
      activity: activity,
      salesRecords: salesRecords,
      purchaseRecords: purchaseRecords,
      topProducts: [
        for (final stat in top.take(5))
          ProductSalesStat(
            sku: stat.sku,
            name: stat.name,
            units: stat.units,
            revenueMinor: stat.revenueMinor,
          ),
      ],
    );
  }
}

DateTime _bucketStart(DateTime date, bool monthly) => monthly
    ? DateTime(date.year, date.month)
    : DateTime(date.year, date.month, date.day);

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

BigInt _bounded(BigInt value, BigInt minimum, BigInt maximum) {
  if (value < minimum) return minimum;
  if (value > maximum) return maximum;
  return value;
}

class _MutableProductStat {
  _MutableProductStat({required this.sku, required this.name});
  final String sku;
  final String name;
  int units = 0;
  BigInt revenueMinor = BigInt.zero;
}

class _MutableActivityPoint {
  _MutableActivityPoint();
  BigInt revenueMinor = BigInt.zero;
  BigInt expenseMinor = BigInt.zero;
}
