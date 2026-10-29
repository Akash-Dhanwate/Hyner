import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import 'inventory_codec.dart';

const _pageSize = 30;
const _stale = AppFailure(
  FailureKind.invalidData,
  'This product changed on another screen or device. Refresh it before saving again.',
);

class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _products(String uid) {
    if (uid.isEmpty || uid.contains('/')) {
      throw inventoryInvalid('Sign in again before using inventory.');
    }
    return _db.collection('users').doc(uid).collection('products');
  }

  DocumentReference<Map<String, dynamic>> _product(String uid, String sku) {
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$').hasMatch(sku)) {
      throw inventoryInvalid('Invalid product code.');
    }
    return _products(uid).doc(sku);
  }

  @override
  String newOperationId() => _db.collection('users').doc().id;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      final failure = AppFailure.from(error);
      if (error is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(error.code)) {
        throw AppFailure(
          FailureKind.permission,
          'Inventory access is not available. Confirm the updated inventory rules are published for this account, then retry.',
          reference: failure.reference,
        );
      }
      if (error is FirebaseException && error.code == 'failed-precondition') {
        throw AppFailure(
          FailureKind.configuration,
          'Inventory setup is incomplete. The required database index may still be building. Contact support.',
          reference: failure.reference,
        );
      }
      throw failure;
    }
  }

  @override
  Future<InventoryPage> list(
    String uid,
    InventoryQuery filter, {
    InventoryCursor? after,
  }) => _guard(() async {
    final field = filter.searchBy == ProductSearch.name ? 'nameKey' : 'sku';
    final prefix = filter.searchBy == ProductSearch.name
        ? filter.search.trim().toLowerCase()
        : normalizeSku(filter.search);
    if (prefix.length > 120) {
      throw inventoryInvalid('Search must be at most 120 characters.');
    }
    Query<Map<String, dynamic>> query = _products(uid)
        .where('archived', isEqualTo: filter.archived)
        .orderBy(field)
        .orderBy(FieldPath.documentId);
    if (prefix.isNotEmpty) {
      query = query.startAt([prefix]).endAt(['$prefix\u{10ffff}']);
    }
    if (after != null) query = query.startAfter([after.sortValue, after.sku]);
    final snapshot = await query
        .limit(_pageSize + 1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final products = snapshot.docs
        .take(_pageSize)
        .map((doc) => InventoryCodec.product(doc.id, doc.data()))
        .toList();
    final last = products.lastOrNull;
    return InventoryPage(
      products,
      snapshot.docs.length > _pageSize && last != null
          ? InventoryCursor(
              field == 'nameKey' ? last.name.toLowerCase() : last.sku,
              last.sku,
            )
          : null,
    );
  });

  @override
  Future<Product> get(String uid, String sku) => _guard(() async {
    final doc = await _product(uid, sku)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (!doc.exists) {
      throw inventoryInvalid(
        'This product no longer exists. Refresh inventory.',
      );
    }
    return InventoryCodec.product(doc.id, doc.data());
  });

  Map<String, dynamic> _metadata(ProductDraft draft) => {
    'name': draft.name,
    'nameKey': draft.name.toLowerCase(),
    'category': draft.category,
    'costMinor': draft.costMinor,
    'priceMinor': draft.priceMinor,
    'reorderLevel': draft.reorderLevel,
  };

  @override
  Future<void> create(String uid, ProductDraft draft, String operationId) =>
      _guard(() async {
        draft.validate();
        if (!InventoryCodec.validOperationId(operationId)) {
          throw inventoryInvalid('Invalid stock operation.');
        }
        final product = _product(uid, draft.sku);
        final movement = product.collection('movements').doc(operationId);
        await _db.runTransaction((tx) async {
          final existing = await tx.get(product);
          final priorMovement = await tx.get(movement);
          if (existing.exists) {
            if (priorMovement.exists) {
              final prior = InventoryCodec.movement(
                priorMovement.id,
                uid,
                priorMovement.data(),
              );
              final current = InventoryCodec.product(
                draft.sku,
                existing.data(),
              );
              if (prior.type == 'opening' &&
                  prior.afterQuantity == draft.openingStock &&
                  current.name == draft.name &&
                  current.category == draft.category &&
                  current.currency == draft.currency &&
                  current.costMinor == draft.costMinor &&
                  current.priceMinor == draft.priceMinor &&
                  current.reorderLevel == draft.reorderLevel) {
                return;
              }
            }
            throw inventoryInvalid(
              'This product code is already used, including archived products. Choose another code.',
            );
          }
          tx.set(product, {
            ..._metadata(draft),
            'sku': draft.sku,
            'currency': draft.currency,
            'quantity': draft.openingStock,
            'archived': false,
            'revision': 1,
            'lastMovementId': operationId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(movement, {
            'type': 'opening',
            'beforeQuantity': 0,
            'afterQuantity': draft.openingStock,
            'delta': draft.openingStock,
            'reason': 'Opening stock',
            'actorUid': uid,
            'revision': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      });

  @override
  Future<void> update(String uid, ProductDraft draft, int expectedRevision) =>
      _guard(() async {
        draft.validate();
        final reference = _product(uid, draft.sku);
        await _db.runTransaction((tx) async {
          final current = InventoryCodec.product(
            draft.sku,
            (await tx.get(reference)).data(),
          );
          if (current.revision != expectedRevision) throw _stale;
          if (current.archived) {
            throw inventoryInvalid('Restore this product before editing it.');
          }
          if (current.currency != draft.currency) {
            throw inventoryInvalid(
              'A saved product’s currency cannot be changed.',
            );
          }
          tx.update(reference, {
            ..._metadata(draft),
            'revision': current.revision + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      });

  @override
  Future<void> setArchived(String uid, Product product, bool archived) =>
      _guard(() async {
        final reference = _product(uid, product.sku);
        await _db.runTransaction((tx) async {
          final current = InventoryCodec.product(
            product.sku,
            (await tx.get(reference)).data(),
          );
          if (current.archived == archived) return;
          if (current.revision != product.revision) throw _stale;
          if (current.quantity != 0) {
            throw inventoryInvalid(
              'Stock must be zero before archiving. Record a stock adjustment first.',
            );
          }
          tx.update(reference, {
            'archived': archived,
            'revision': current.revision + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      });

  @override
  Future<void> adjust(
    String uid,
    Product product,
    int delta,
    String reason,
    String operationId,
  ) => _guard(() async {
    if (delta == 0 ||
        delta.abs() > maxStock ||
        reason.trim().isEmpty ||
        reason.length > 200 ||
        !InventoryCodec.validOperationId(operationId)) {
      throw inventoryInvalid(
        'Enter valid units and a reason for this adjustment.',
      );
    }
    final reference = _product(uid, product.sku);
    final movement = reference.collection('movements').doc(operationId);
    await _db.runTransaction((tx) async {
      final previous = await tx.get(movement);
      if (previous.exists) {
        final recorded = InventoryCodec.movement(
          previous.id,
          uid,
          previous.data(),
        );
        if (recorded.type != 'adjustment' ||
            recorded.delta != delta ||
            recorded.reason != reason) {
          throw inventoryInvalid(
            'This change was already recorded with different details. Refresh before another adjustment.',
          );
        }
        return;
      }
      final current = InventoryCodec.product(
        product.sku,
        (await tx.get(reference)).data(),
      );
      if (current.archived) {
        throw inventoryInvalid(
          'Restore this product before changing its stock.',
        );
      }
      if (current.revision != product.revision) throw _stale;
      final after = current.quantity + delta;
      if (after < 0 || after > maxStock) {
        throw inventoryInvalid(
          'This adjustment would put stock outside the allowed range.',
        );
      }
      tx.update(reference, {
        'quantity': after,
        'lastMovementId': operationId,
        'revision': current.revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(movement, {
        'type': 'adjustment',
        'beforeQuantity': current.quantity,
        'afterQuantity': after,
        'delta': delta,
        'reason': reason,
        'actorUid': uid,
        'revision': current.revision + 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<MovementPage> movements(
    String uid,
    String sku, {
    MovementCursor? after,
  }) => _guard(() async {
    Query<Map<String, dynamic>> query = _product(uid, sku)
        .collection('movements')
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter([Timestamp.fromDate(after.time), after.id]);
    }
    final result = await query
        .limit(_pageSize + 1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final entries = result.docs
        .take(_pageSize)
        .map((doc) => InventoryCodec.movement(doc.id, uid, doc.data()))
        .toList();
    final last = entries.lastOrNull;
    return MovementPage(
      entries,
      result.docs.length > _pageSize && last != null
          ? MovementCursor(last.createdAt, last.id)
          : null,
    );
  });
}

class UnconfiguredInventoryRepository implements InventoryRepository {
  Never _unavailable() => throw const AppFailure(
    FailureKind.configuration,
    'Inventory services are not connected.',
  );
  @override
  String newOperationId() => _unavailable();
  @override
  Future<InventoryPage> list(
    String uid,
    InventoryQuery query, {
    InventoryCursor? after,
  }) async => _unavailable();
  @override
  Future<Product> get(String uid, String sku) async => _unavailable();
  @override
  Future<void> create(
    String uid,
    ProductDraft draft,
    String operationId,
  ) async => _unavailable();
  @override
  Future<void> update(
    String uid,
    ProductDraft draft,
    int expectedRevision,
  ) async => _unavailable();
  @override
  Future<void> setArchived(String uid, Product product, bool archived) async =>
      _unavailable();
  @override
  Future<void> adjust(
    String uid,
    Product product,
    int delta,
    String reason,
    String operationId,
  ) async => _unavailable();
  @override
  Future<MovementPage> movements(
    String uid,
    String sku, {
    MovementCursor? after,
  }) async => _unavailable();
}
