import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../../inventory/data/inventory_codec.dart';
import '../../inventory/domain/product.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';

const _pageSize = 30;

class LocalPurchaseRepository implements PurchaseRepository {
  LocalPurchaseRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  String newId() => _randomId();

  @override
  Future<List<Supplier>> suppliers(String uid) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'suppliers',
      orderBy: 'name COLLATE NOCASE, id',
    );
    return rows.map(_supplierFromRow).toList();
  }

  @override
  Future<Supplier> saveSupplier(
    String uid,
    SupplierDraft draft, {
    String? id,
  }) async {
    _checkUid(uid);
    draft.validate();
    final db = await _store.databaseFor(uid);
    final supplierId = id ?? newId();
    final now = DateTime.now().toUtc();
    return db.transaction((tx) async {
      final existing = await tx.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
        limit: 1,
      );
      final createdAt = existing.isEmpty
          ? now
          : DateTime.parse(existing.single['createdAt']! as String);
      final row = {
        'id': supplierId,
        'name': draft.name,
        'phone': draft.phone.trim(),
        'notes': draft.notes.trim(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await tx.insert(
        'suppliers',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return _supplierFromRow(row);
    });
  }

  @override
  Future<PurchasePage> list(String uid, {PurchaseCursor? after}) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'purchases',
      where: after == null
          ? null
          : 'createdAt < ? OR (createdAt = ? AND id < ?)',
      whereArgs: after == null
          ? null
          : [
              after.time.toUtc().toIso8601String(),
              after.time.toUtc().toIso8601String(),
              after.id,
            ],
      orderBy: 'createdAt DESC, id DESC',
      limit: _pageSize + 1,
    );
    final hasNext = rows.length > _pageSize;
    final page = rows.take(_pageSize).map(_purchaseFromRow).toList();
    final last = page.lastOrNull;
    return PurchasePage(
      page,
      hasNext && last != null ? PurchaseCursor(last.createdAt, last.id) : null,
    );
  }

  @override
  Future<Purchase> get(String uid, String id) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw inventoryInvalid('This purchase could not be found.');
    }
    return _purchaseFromRow(rows.single);
  }

  @override
  Future<List<PurchaseReturn>> returns(String uid, String purchaseId) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'purchase_returns',
      where: 'purchaseId = ?',
      whereArgs: [purchaseId],
      orderBy: 'createdAt DESC, id DESC',
    );
    return rows.map(_returnFromRow).toList();
  }

  @override
  Future<void> create(String uid, String id, PurchaseDraft draft) async {
    _checkUid(uid);
    if (!InventoryCodec.validOperationId(id)) {
      throw inventoryInvalid('Invalid purchase reference.');
    }
    draft.validate();
    final db = await _store.databaseFor(uid);
    final now = DateTime.now().toUtc();
    await db.transaction((tx) async {
      final existing = await tx.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        if (_purchaseFromRow(existing.single).draft.matches(draft)) return;
        throw inventoryInvalid(
          'This purchase reference was already used for different details.',
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
            'Product ${line.sku} is not in inventory. Add the product before recording a purchase.',
          );
        }
        final product = _productFromRow(rows.single);
        if (product.archived || product.currency != draft.currency) {
          throw inventoryInvalid(
            'Product ${line.sku} is unavailable or uses a different currency.',
          );
        }
        final nextQuantity = product.quantity + line.quantity;
        if (nextQuantity > maxStock) {
          throw inventoryInvalid(
            'This purchase would exceed supported stock for ${line.name}.',
          );
        }
        final revision = product.revision + 1;
        final movementId = '${id.substring(0, min(id.length, 27))}_p$index';
        final weightedCost = _weightedAverageCost(
          existingQuantity: product.quantity,
          existingCost: product.costMinor,
          addedQuantity: line.quantity,
          addedCost: line.unitCostMinor,
        );
        await tx.update(
          'products',
          {
            'quantity': nextQuantity,
            'costMinor': weightedCost,
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
          'type': 'purchase',
          'beforeQuantity': product.quantity,
          'afterQuantity': nextQuantity,
          'delta': line.quantity,
          'reason': 'Purchase $id',
          'actorUid': uid,
          'revision': revision,
          'createdAt': now.toIso8601String(),
        });
      }
      await tx.insert('purchases', {
        'id': id,
        'supplierId': draft.supplierId,
        'supplierName': draft.supplierName,
        'supplierPhone': draft.supplierPhone,
        'currency': draft.currency,
        'items': jsonEncode([
          for (final line in draft.lines)
            {
              'sku': line.sku,
              'name': line.name,
              'quantity': line.quantity,
              'unitCostMinor': line.unitCostMinor,
            },
        ]),
        'returnedItems': '{}',
        'paymentStatus': PurchasePaymentStatus.unpaid.name,
        'createdAt': now.toIso8601String(),
        'paidAt': null,
      });
    });
  }

  @override
  Future<void> recordReturn(
    String uid,
    String purchaseId,
    Map<String, int> quantities,
    String reason,
    String returnId,
  ) async {
    _checkUid(uid);
    if (!InventoryCodec.validOperationId(returnId) ||
        reason.trim().isEmpty ||
        reason.length > 200 ||
        quantities.isEmpty ||
        quantities.values.any(
          (quantity) => quantity < 1 || quantity > maxStock,
        )) {
      throw inventoryInvalid(
        'Enter at least one return quantity and a reason.',
      );
    }
    final db = await _store.databaseFor(uid);
    final now = DateTime.now().toUtc();
    await db.transaction((tx) async {
      final oldReturn = await tx.query(
        'purchase_returns',
        where: 'id = ?',
        whereArgs: [returnId],
        limit: 1,
      );
      if (oldReturn.isNotEmpty) {
        final recorded = _returnFromRow(oldReturn.single);
        final recordedQuantities = {
          for (final line in recorded.lines) line.sku: line.quantity,
        };
        if (recorded.purchaseId == purchaseId &&
            recorded.reason == reason &&
            _sameQuantities(recordedQuantities, quantities)) {
          return;
        }
        throw inventoryInvalid(
          'This return reference was already used for different details.',
        );
      }
      final purchaseRows = await tx.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [purchaseId],
        limit: 1,
      );
      if (purchaseRows.isEmpty) {
        throw inventoryInvalid('This purchase could not be found.');
      }
      final purchase = _purchaseFromRow(purchaseRows.single);
      final lines = <PurchaseReturnLine>[];
      for (final entry in quantities.entries) {
        final line = purchase.draft.lines
            .where((item) => item.sku == entry.key)
            .firstOrNull;
        if (line == null ||
            entry.value > line.quantity - purchase.returnedQuantity(line.sku)) {
          throw inventoryInvalid(
            'Return quantity for ${entry.key} exceeds the remaining purchase quantity.',
          );
        }
        final productRows = await tx.query(
          'products',
          where: 'sku = ?',
          whereArgs: [line.sku],
          limit: 1,
        );
        if (productRows.isEmpty) {
          throw inventoryInvalid('Product ${line.sku} is not in inventory.');
        }
        final product = _productFromRow(productRows.single);
        if (product.quantity < entry.value) {
          throw inventoryInvalid(
            'Only ${product.quantity} ${product.name} remain in stock; this return needs ${entry.value}.',
          );
        }
        lines.add(
          PurchaseReturnLine(
            sku: line.sku,
            name: line.name,
            quantity: entry.value,
            unitCostMinor: line.unitCostMinor,
          ),
        );
      }
      final returnRecord = PurchaseReturn(
        id: returnId,
        purchaseId: purchaseId,
        lines: lines,
        reason: reason.trim(),
        createdAt: now,
      );
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final rows = await tx.query(
          'products',
          where: 'sku = ?',
          whereArgs: [line.sku],
          limit: 1,
        );
        final product = _productFromRow(rows.single);
        final nextQuantity = product.quantity - line.quantity;
        final revision = product.revision + 1;
        final movementId =
            '${returnId.substring(0, min(returnId.length, 25))}_r$index';
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
          'type': 'purchase_return',
          'beforeQuantity': product.quantity,
          'afterQuantity': nextQuantity,
          'delta': -line.quantity,
          'reason': 'Return $returnId',
          'actorUid': uid,
          'revision': revision,
          'createdAt': now.toIso8601String(),
        });
      }
      final updatedReturned = {...purchase.returnedQuantities};
      for (final line in lines) {
        updatedReturned.update(
          line.sku,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
      await tx.update(
        'purchases',
        {'returnedItems': jsonEncode(updatedReturned)},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
      await tx.insert('purchase_returns', {
        'id': returnRecord.id,
        'purchaseId': returnRecord.purchaseId,
        'items': jsonEncode([
          for (final line in returnRecord.lines)
            {
              'sku': line.sku,
              'name': line.name,
              'quantity': line.quantity,
              'unitCostMinor': line.unitCostMinor,
            },
        ]),
        'totalMinor': returnRecord.totalMinor,
        'reason': returnRecord.reason,
        'createdAt': now.toIso8601String(),
      });
    });
  }

  @override
  Future<void> markPaid(String uid, String id) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      final rows = await tx.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw inventoryInvalid('This purchase could not be found.');
      }
      if (rows.single['paymentStatus'] == PurchasePaymentStatus.paid.name) {
        return;
      }
      await tx.update(
        'purchases',
        {
          'paymentStatus': PurchasePaymentStatus.paid.name,
          'paidAt': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}

Supplier _supplierFromRow(Map<String, Object?> row) => Supplier(
  id: row['id']! as String,
  name: row['name']! as String,
  phone: row['phone']! as String,
  notes: row['notes']! as String,
  createdAt: DateTime.parse(row['createdAt']! as String),
  updatedAt: DateTime.parse(row['updatedAt']! as String),
);

Purchase _purchaseFromRow(Map<String, Object?> row) {
  final rawItems = jsonDecode(row['items']! as String);
  final returnedRaw = jsonDecode(row['returnedItems'] as String? ?? '{}');
  if (rawItems is! List || returnedRaw is! Map<String, dynamic>) {
    throw inventoryInvalid('This purchase could not be read safely.');
  }
  final lines = <PurchaseLine>[];
  for (final item in rawItems) {
    if (item is! Map<String, dynamic> ||
        item['sku'] is! String ||
        item['name'] is! String ||
        item['quantity'] is! int ||
        item['unitCostMinor'] is! int) {
      throw inventoryInvalid('This purchase could not be read safely.');
    }
    lines.add(
      PurchaseLine(
        sku: item['sku'] as String,
        name: item['name'] as String,
        quantity: item['quantity'] as int,
        unitCostMinor: item['unitCostMinor'] as int,
      ),
    );
  }
  final returned = <String, int>{};
  for (final entry in returnedRaw.entries) {
    if (entry.value is! int) {
      throw inventoryInvalid(
        'This purchase return history could not be read safely.',
      );
    }
    returned[entry.key] = entry.value as int;
  }
  final draft = PurchaseDraft(
    currency: row['currency']! as String,
    lines: lines,
    supplierId: row['supplierId'] as String?,
    supplierName: row['supplierName'] as String?,
    supplierPhone: row['supplierPhone'] as String?,
  )..validate();
  return Purchase(
    id: row['id']! as String,
    draft: draft,
    createdAt: DateTime.parse(row['createdAt']! as String),
    returnedQuantities: returned,
    paymentStatus: row['paymentStatus'] == PurchasePaymentStatus.paid.name
        ? PurchasePaymentStatus.paid
        : PurchasePaymentStatus.unpaid,
    paidAt: row['paidAt'] == null
        ? null
        : DateTime.parse(row['paidAt']! as String),
  );
}

PurchaseReturn _returnFromRow(Map<String, Object?> row) {
  final rawItems = jsonDecode(row['items']! as String);
  if (rawItems is! List) {
    throw inventoryInvalid('This purchase return could not be read.');
  }
  final lines = <PurchaseReturnLine>[];
  for (final item in rawItems) {
    if (item is! Map<String, dynamic> ||
        item['sku'] is! String ||
        item['name'] is! String ||
        item['quantity'] is! int ||
        item['unitCostMinor'] is! int) {
      throw inventoryInvalid('This purchase return could not be read.');
    }
    lines.add(
      PurchaseReturnLine(
        sku: item['sku'] as String,
        name: item['name'] as String,
        quantity: item['quantity'] as int,
        unitCostMinor: item['unitCostMinor'] as int,
      ),
    );
  }
  return PurchaseReturn(
    id: row['id']! as String,
    purchaseId: row['purchaseId']! as String,
    lines: lines,
    reason: row['reason']! as String,
    createdAt: DateTime.parse(row['createdAt']! as String),
  );
}

Product _productFromRow(Map<String, Object?> row) => Product(
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

int _weightedAverageCost({
  required int existingQuantity,
  required int existingCost,
  required int addedQuantity,
  required int addedCost,
}) {
  final totalQuantity = existingQuantity + addedQuantity;
  if (totalQuantity == 0) return addedCost;
  final totalValue =
      BigInt.from(existingQuantity) * BigInt.from(existingCost) +
      BigInt.from(addedQuantity) * BigInt.from(addedCost);
  return ((totalValue + BigInt.from(totalQuantity ~/ 2)) ~/
          BigInt.from(totalQuantity))
      .toInt();
}

bool _sameQuantities(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length &&
    a.entries.every((entry) => b[entry.key] == entry.value);

void _checkUid(String uid) {
  if (uid.isEmpty || uid.contains('/')) {
    throw inventoryInvalid('Sign in again before using purchases.');
  }
}

String _randomId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
