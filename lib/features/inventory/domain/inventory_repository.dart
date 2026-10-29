import 'product.dart';

enum ProductSearch { name, code }

class InventoryQuery {
  const InventoryQuery({
    this.archived = false,
    this.search = '',
    this.searchBy = ProductSearch.name,
  });
  final bool archived;
  final String search;
  final ProductSearch searchBy;
}

class InventoryCursor {
  const InventoryCursor(this.sortValue, this.sku);
  final String sortValue;
  final String sku;
}

class InventoryPage {
  const InventoryPage(this.products, this.next);
  final List<Product> products;
  final InventoryCursor? next;
}

class MovementCursor {
  const MovementCursor(this.time, this.id);
  final DateTime time;
  final String id;
}

class MovementPage {
  const MovementPage(this.movements, this.next);
  final List<StockMovement> movements;
  final MovementCursor? next;
}

abstract interface class InventoryRepository {
  String newOperationId();
  Future<InventoryPage> list(
    String uid,
    InventoryQuery query, {
    InventoryCursor? after,
  });
  Future<Product> get(String uid, String sku);
  Future<void> create(String uid, ProductDraft draft, String operationId);
  Future<void> update(String uid, ProductDraft draft, int expectedRevision);
  Future<void> setArchived(String uid, Product product, bool archived);
  Future<void> adjust(
    String uid,
    Product product,
    int delta,
    String reason,
    String operationId,
  );
  Future<MovementPage> movements(
    String uid,
    String sku, {
    MovementCursor? after,
  });
}
