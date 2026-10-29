import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/product.dart';

abstract final class InventoryCodec {
  static Product product(String sku, Map<String, dynamic>? data) {
    const fields = {
      'sku',
      'name',
      'nameKey',
      'category',
      'currency',
      'costMinor',
      'priceMinor',
      'quantity',
      'reorderLevel',
      'archived',
      'revision',
      'lastMovementId',
      'createdAt',
      'updatedAt',
    };
    if (data == null ||
        !data.keys.toSet().containsAll(fields) ||
        data.keys.toSet().difference(fields).difference({
          'parameters',
        }).isNotEmpty ||
        data['sku'] != sku ||
        data['name'] is! String ||
        data['nameKey'] is! String ||
        data['category'] is! String ||
        data['currency'] is! String ||
        data['costMinor'] is! int ||
        data['priceMinor'] is! int ||
        data['quantity'] is! int ||
        data['reorderLevel'] is! int ||
        data['archived'] is! bool ||
        data['revision'] is! int ||
        data['lastMovementId'] is! String ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp ||
        data['parameters'] != null &&
            (data['parameters'] is! List ||
                (data['parameters'] as List).any(
                  (entry) =>
                      entry is! Map ||
                      entry['name'] is! String ||
                      entry['value'] is! String,
                ))) {
      throw inventoryInvalid(
        'This product could not be read safely. Refresh inventory or contact support.',
      );
    }
    final product = Product(
      sku: sku,
      name: data['name'],
      category: data['category'],
      currency: data['currency'],
      costMinor: data['costMinor'],
      priceMinor: data['priceMinor'],
      quantity: data['quantity'],
      reorderLevel: data['reorderLevel'],
      archived: data['archived'],
      revision: data['revision'],
      lastMovementId: data['lastMovementId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      parameters: [
        for (final entry in (data['parameters'] as List? ?? const []))
          ProductParameter.fromMap(entry as Map<dynamic, dynamic>),
      ],
    );
    product.draft.validate();
    if (data['nameKey'] != product.name.toLowerCase() ||
        product.revision < 1 ||
        product.revision > maxStock ||
        !validOperationId(product.lastMovementId) ||
        product.updatedAt.isBefore(product.createdAt) ||
        (product.archived && product.quantity != 0)) {
      throw inventoryInvalid(
        'This product contains inconsistent saved data. Contact support.',
      );
    }
    return product;
  }

  static bool validOperationId(String id) =>
      RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id);

  static StockMovement movement(
    String id,
    String uid,
    Map<String, dynamic>? data,
  ) {
    const fields = {
      'type',
      'beforeQuantity',
      'afterQuantity',
      'delta',
      'reason',
      'actorUid',
      'revision',
      'createdAt',
    };
    if (data == null ||
        data.length != fields.length ||
        !data.keys.toSet().containsAll(fields) ||
        !validOperationId(id) ||
        data['type'] is! String ||
        data['beforeQuantity'] is! int ||
        data['afterQuantity'] is! int ||
        data['delta'] is! int ||
        data['reason'] is! String ||
        data['actorUid'] != uid ||
        data['revision'] is! int ||
        data['createdAt'] is! Timestamp) {
      throw inventoryInvalid(
        'Stock history could not be read safely. Refresh or contact support.',
      );
    }
    final movement = StockMovement(
      id: id,
      type: data['type'],
      beforeQuantity: data['beforeQuantity'],
      afterQuantity: data['afterQuantity'],
      delta: data['delta'],
      reason: data['reason'],
      actorUid: uid,
      revision: data['revision'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
    if (!['opening', 'adjustment', 'sale'].contains(movement.type) ||
        movement.beforeQuantity < 0 ||
        movement.beforeQuantity > maxStock ||
        movement.afterQuantity < 0 ||
        movement.afterQuantity > maxStock ||
        movement.afterQuantity - movement.beforeQuantity != movement.delta ||
        movement.reason.trim().isEmpty ||
        movement.reason.length > 200 ||
        movement.revision < 1 ||
        movement.revision > maxStock ||
        (movement.type == 'opening' &&
            (movement.beforeQuantity != 0 || movement.revision != 1)) ||
        (movement.type == 'adjustment' &&
            (movement.delta == 0 || movement.revision < 2)) ||
        (movement.type == 'sale' &&
            (movement.delta >= 0 ||
                movement.revision < 2 ||
                movement.reason != 'Sale $id'))) {
      throw inventoryInvalid(
        'Stock history contains inconsistent saved data. Contact support.',
      );
    }
    return movement;
  }
}
