import 'dart:convert';
import 'dart:math';

import '../../../core/storage/local_business_database.dart';
import '../../inventory/data/inventory_codec.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

const _pageSize = 30;

class LocalSalesRepository implements SalesRepository {
  LocalSalesRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  String newSaleId() => _localId();

  @override
  Future<SalesPage> list(String uid, {SalesCursor? after}) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query('sales', orderBy: 'createdAt DESC, id DESC');
    final all = rows.map(_saleFromRow).where((sale) {
      if (after == null) return true;
      final dateOrder = sale.createdAt.compareTo(after.time);
      return dateOrder < 0 ||
          (dateOrder == 0 && sale.id.compareTo(after.id) < 0);
    }).toList();
    final hasNext = all.length > _pageSize;
    final page = all.take(_pageSize).toList();
    final last = page.lastOrNull;
    return SalesPage(
      page,
      hasNext && last != null ? SalesCursor(last.createdAt, last.id) : null,
    );
  }

  @override
  Future<List<Sale>> forCustomer(String uid, String customerId) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'sales',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC, id DESC',
    );
    return rows.map(_saleFromRow).toList();
  }

  @override
  Future<List<Sale>> remainingPayments(String uid) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query('sales', orderBy: 'createdAt DESC, id DESC');
    return rows
        .map(_saleFromRow)
        .where((sale) => sale.remainingMinor > 0)
        .toList();
  }

  @override
  Future<List<Sale>> scheduledFollowUps(String uid) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'sales',
      where: 'followupAt IS NOT NULL',
      orderBy: 'followupAt ASC',
    );
    return rows
        .map(_saleFromRow)
        .where(
          (sale) => sale.remainingMinor > 0 && sale.draft.customerId != null,
        )
        .toList();
  }

  @override
  Future<void> setFollowUp(String uid, String id, DateTime? followupAt) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      final rows = await tx.query(
        'sales',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw inventoryInvalid('This sale could not be found. Refresh sales.');
      }
      final sale = _saleFromRow(rows.single);
      if (sale.remainingMinor == 0) {
        throw inventoryInvalid(
          'A fully paid bill has no balance to follow up.',
        );
      }
      if (followupAt != null &&
          (sale.draft.customerId == null ||
              sale.draft.customerPhone?.trim().isNotEmpty != true)) {
        throw inventoryInvalid(
          'Add a customer with a phone number before scheduling a follow-up.',
        );
      }
      if (followupAt != null &&
          (followupAt.isBefore(DateTime.now()) ||
              followupAt.isAfter(
                DateTime.now().add(const Duration(days: 365)),
              ))) {
        throw inventoryInvalid('Choose a follow-up date within the next year.');
      }
      await tx.update(
        'sales',
        {'followupAt': followupAt?.toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<Sale> get(String uid, String id) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw inventoryInvalid('This sale could not be found. Refresh sales.');
    }
    return _saleFromRow(rows.single);
  }

  @override
  Future<void> create(String uid, String id, SaleDraft draft) async {
    _checkOwner(uid);
    if (!InventoryCodec.validOperationId(id)) {
      throw inventoryInvalid('Invalid sale reference.');
    }
    draft.validate();
    final db = await _store.databaseFor(uid);
    final now = DateTime.now().toUtc();
    await db.transaction((tx) async {
      final existing = await tx.query(
        'sales',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        if (_saleFromRow(existing.single).draft.matches(draft)) return;
        throw inventoryInvalid(
          'This bill reference was already used for different details.',
        );
      }

      for (var index = 0; index < draft.lines.length; index++) {
        final line = draft.lines[index];
        final rows = await tx.query(
          'products',
          where: 'sku = ?',
          whereArgs: [line.sku],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw inventoryInvalid(
            'Product ${line.sku} is no longer in inventory. Refresh the bill.',
          );
        }
        final row = rows.single;
        final product = _productFromRow(row);
        if (product.archived || product.currency != draft.currency) {
          throw inventoryInvalid(
            'Product ${line.sku} is unavailable for this bill. Refresh the bill.',
          );
        }
        if (product.quantity < line.quantity) {
          throw inventoryInvalid(
            'Not enough ${product.name} in stock. Available: ${product.quantity}.',
          );
        }
        final movementId = '${id.substring(0, min(id.length, 28))}_$index';
        final nextQuantity = product.quantity - line.quantity;
        final revision = product.revision + 1;
        await tx.update(
          'products',
          {
            'quantity': nextQuantity,
            'revision': revision,
            'lastMovementId': movementId,
            'updatedAt': now.toIso8601String(),
          },
          where: 'sku = ?',
          whereArgs: [line.sku],
        );
        await tx.insert('movements', {
          'id': movementId,
          'sku': line.sku,
          'type': 'sale',
          'beforeQuantity': product.quantity,
          'afterQuantity': nextQuantity,
          'delta': -line.quantity,
          'reason': 'Sale $id',
          'actorUid': uid,
          'revision': revision,
          'createdAt': now.toIso8601String(),
        });
      }

      await tx.insert('sales', {
        'id': id,
        'currency': draft.currency,
        'lines': jsonEncode([
          for (final line in draft.lines)
            {
              'sku': line.sku,
              'name': line.name,
              'unitPriceMinor': line.unitPriceMinor,
              'unitCostMinor': line.unitCostMinor,
              'quantity': line.quantity,
              'parameters': [
                for (final parameter in line.parameters) parameter.toMap(),
              ],
            },
        ]),
        'customerId': draft.customerId,
        'customerName': draft.customerName,
        'customerPhone': draft.customerPhone,
        'paymentStatus': PaymentStatus.unpaid.name,
        'initialPaymentMinor': draft.firstPaymentMinor,
        'expectedPaymentMinor': draft.firstPaymentMinor,
        'paidMinor': 0,
        'payments': '[]',
        'createdAt': now.toIso8601String(),
        'paidAt': null,
      });
    });
  }

  @override
  Future<void> markPaid(String uid, String id) async {
    final sale = await get(uid, id);
    if (sale.remainingMinor == 0) return;
    await recordPayment(
      uid,
      id,
      sale.expectedPaymentMinor > 0
          ? sale.expectedPaymentMinor
          : sale.remainingMinor,
    );
  }

  @override
  Future<void> recordPayment(String uid, String id, int amountMinor) async {
    _checkOwner(uid);
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      final rows = await tx.query(
        'sales',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw inventoryInvalid('This sale could not be found. Refresh sales.');
      }
      final sale = _saleFromRow(rows.single);
      if (sale.remainingMinor == 0) return;
      if (amountMinor < 1 || amountMinor > sale.remainingMinor) {
        throw inventoryInvalid(
          'Enter a payment amount from 1 to ${moneyDecimal(sale.remainingMinor)}.',
        );
      }
      final now = DateTime.now().toUtc();
      final paid = sale.paidMinor + amountMinor;
      final remaining = sale.draft.totalMinor - paid;
      final payments = [
        ...sale.payments,
        PaymentEntry(amountMinor: amountMinor, createdAt: now),
      ];
      await tx.update(
        'sales',
        {
          'paymentStatus': remaining == 0
              ? PaymentStatus.paid.name
              : PaymentStatus.partial.name,
          'expectedPaymentMinor': remaining,
          'paidMinor': paid,
          'payments': jsonEncode([
            for (final payment in payments) payment.toMap(),
          ]),
          'paidAt': remaining == 0 ? now.toIso8601String() : null,
          'followupAt': remaining == 0 ? null : rows.single['followupAt'],
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}

Sale _saleFromRow(Map<String, Object?> row) {
  final rawLines = jsonDecode(row['lines']! as String);
  if (rawLines is! List) {
    throw inventoryInvalid('This saved bill could not be read.');
  }
  final lines = <SaleLine>[];
  for (final raw in rawLines) {
    if (raw is! Map<String, dynamic> ||
        raw['sku'] is! String ||
        raw['name'] is! String ||
        raw['unitPriceMinor'] is! int ||
        raw['unitCostMinor'] != null && raw['unitCostMinor'] is! int ||
        raw['quantity'] is! int ||
        raw['parameters'] != null &&
            (raw['parameters'] is! List ||
                (raw['parameters'] as List).any(
                  (entry) =>
                      entry is! Map ||
                      entry['name'] is! String ||
                      entry['value'] is! String,
                ))) {
      throw inventoryInvalid('This saved bill could not be read.');
    }
    lines.add(
      SaleLine(
        sku: raw['sku'] as String,
        name: raw['name'] as String,
        unitPriceMinor: raw['unitPriceMinor'] as int,
        unitCostMinor: raw['unitCostMinor'] as int? ?? 0,
        quantity: raw['quantity'] as int,
        parameters: [
          for (final entry in (raw['parameters'] as List? ?? const []))
            ProductParameter.fromMap(entry as Map<dynamic, dynamic>),
        ],
      ),
    );
  }
  final customerId = row['customerId'] as String?;
  final customerName = row['customerName'] as String?;
  final customerPhone = row['customerPhone'] as String?;
  final draft = SaleDraft(
    currency: row['currency']! as String,
    lines: lines,
    customerId: customerId,
    customerName: customerName,
    customerPhone: customerPhone,
    initialPaymentMinor: (row['initialPaymentMinor'] as int? ?? 0) > 0
        ? row['initialPaymentMinor'] as int
        : null,
  )..validate();
  final rawPaymentHistory = jsonDecode(row['payments'] as String? ?? '[]');
  if (rawPaymentHistory is! List ||
      rawPaymentHistory.any(
        (entry) =>
            entry is! Map ||
            entry['amountMinor'] is! int ||
            entry['createdAt'] is! String,
      )) {
    throw inventoryInvalid('This bill’s payment history could not be read.');
  }
  final payments = [
    for (final entry in rawPaymentHistory)
      PaymentEntry(
        amountMinor: (entry as Map)['amountMinor'] as int,
        createdAt: DateTime.parse(entry['createdAt'] as String),
      ),
  ];
  final totalMinor = draft.totalMinor;
  var paidMinor = row['paidMinor'] as int? ?? 0;
  if (row['paymentStatus'] == PaymentStatus.paid.name && paidMinor == 0) {
    paidMinor = totalMinor;
  }
  if (paidMinor < 0 || paidMinor > totalMinor) {
    throw inventoryInvalid('This bill’s payment amount is invalid.');
  }
  final remainingMinor = totalMinor - paidMinor;
  final status = remainingMinor == 0
      ? PaymentStatus.paid
      : paidMinor > 0
      ? PaymentStatus.partial
      : PaymentStatus.unpaid;
  final storedExpected = row['expectedPaymentMinor'] as int? ?? 0;
  final expectedPaymentMinor = remainingMinor == 0
      ? 0
      : storedExpected > 0
      ? (storedExpected > remainingMinor ? remainingMinor : storedExpected)
      : remainingMinor;
  final paidAtValue = row['paidAt'] as String?;
  return Sale(
    id: row['id']! as String,
    draft: draft,
    createdAt: DateTime.parse(row['createdAt']! as String),
    paymentStatus: status,
    paidAt: paidAtValue == null
        ? payments.lastOrNull?.createdAt
        : DateTime.parse(paidAtValue),
    paidMinor: paidMinor,
    expectedPaymentMinor: expectedPaymentMinor,
    payments: payments,
    followupAt: row['followupAt'] == null
        ? null
        : DateTime.parse(row['followupAt']! as String),
  );
}

Product _productFromRow(Map<String, Object?> row) {
  final product = Product(
    sku: row['sku']! as String,
    name: row['name']! as String,
    category: row['category']! as String,
    currency: row['currency']! as String,
    costMinor: row['costMinor']! as int,
    priceMinor: row['priceMinor']! as int,
    quantity: row['quantity']! as int,
    reorderLevel: row['reorderLevel']! as int,
    archived: row['archived'] == 1,
    revision: row['revision']! as int,
    lastMovementId: row['lastMovementId']! as String,
    createdAt: DateTime.parse(row['createdAt']! as String),
    updatedAt: DateTime.parse(row['updatedAt']! as String),
  );
  product.draft.validate();
  return product;
}

void _checkOwner(String uid) {
  if (uid.isEmpty || uid.contains('/')) {
    throw inventoryInvalid('Sign in again before using sales.');
  }
}

String _localId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
