import 'dart:async';

import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/inventory/domain/inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';

Product inventoryFixture({
  String sku = 'TEST-1',
  int quantity = 10,
  int revision = 1,
  bool archived = false,
  String name = 'Test product',
  int priceMinor = 12550,
}) => Product(
  sku: sku,
  name: name,
  category: 'Test category',
  currency: 'INR',
  costMinor: 10000,
  priceMinor: priceMinor,
  quantity: quantity,
  reorderLevel: 2,
  archived: archived,
  revision: revision,
  lastMovementId: 'opening1',
  createdAt: DateTime.utc(2026, 10, 23),
  updatedAt: DateTime.utc(2026, 10, 23),
);

class FakeInventory implements InventoryRepository {
  final Map<String, Map<String, Product>> accounts = {};
  final Map<String, List<StockMovement>> history = {};
  AppFailure? failure;
  Completer<InventoryPage>? pendingList;
  Completer<void>? pendingWrite;
  int listCalls = 0;
  int writes = 0;
  int _operation = 0;
  int get operationCount => _operation;
  int pageSize = 30;
  List<String> requestedUids = [];

  Map<String, Product> products(String uid) =>
      accounts.putIfAbsent(uid, () => {});
  void _check() {
    if (failure != null) throw failure!;
  }

  @override
  String newOperationId() => 'operation${++_operation}';

  @override
  Future<InventoryPage> list(
    String uid,
    InventoryQuery query, {
    InventoryCursor? after,
  }) async {
    listCalls++;
    requestedUids.add(uid);
    _check();
    if (pendingList != null) return pendingList!.future;
    String key(Product p) =>
        query.searchBy == ProductSearch.name ? p.name.toLowerCase() : p.sku;
    final prefix = query.searchBy == ProductSearch.name
        ? query.search.trim().toLowerCase()
        : normalizeSku(query.search);
    final all =
        products(uid).values
            .where(
              (p) => p.archived == query.archived && key(p).startsWith(prefix),
            )
            .toList()
          ..sort((a, b) {
            final result = key(a).compareTo(key(b));
            return result == 0 ? a.sku.compareTo(b.sku) : result;
          });
    final values = all
        .where(
          (p) =>
              after == null ||
              key(p).compareTo(after.sortValue) > 0 ||
              (key(p) == after.sortValue && p.sku.compareTo(after.sku) > 0),
        )
        .toList();
    final page = values.take(pageSize).toList();
    return InventoryPage(
      page,
      values.length > pageSize
          ? InventoryCursor(key(page.last), page.last.sku)
          : null,
    );
  }

  @override
  Future<Product> get(String uid, String sku) async {
    _check();
    return products(uid)[sku] ??
        (throw inventoryInvalid('This product no longer exists.'));
  }

  Product _copy(
    Product p, {
    ProductDraft? draft,
    int? quantity,
    bool? archived,
    String? movement,
  }) => Product(
    sku: p.sku,
    name: draft?.name ?? p.name,
    category: draft?.category ?? p.category,
    currency: p.currency,
    costMinor: draft?.costMinor ?? p.costMinor,
    priceMinor: draft?.priceMinor ?? p.priceMinor,
    quantity: quantity ?? p.quantity,
    reorderLevel: draft?.reorderLevel ?? p.reorderLevel,
    archived: archived ?? p.archived,
    revision: p.revision + 1,
    lastMovementId: movement ?? p.lastMovementId,
    createdAt: p.createdAt,
    updatedAt: p.updatedAt.add(const Duration(seconds: 1)),
  );
  Future<void> _write() async {
    _check();
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
  }

  @override
  Future<void> create(
    String uid,
    ProductDraft draft,
    String operationId,
  ) async {
    draft.validate();
    await _write();
    if (products(uid).containsKey(draft.sku)) {
      throw inventoryInvalid('This product code is already used.');
    }
    products(uid)[draft.sku] = Product(
      sku: draft.sku,
      name: draft.name,
      category: draft.category,
      currency: draft.currency,
      costMinor: draft.costMinor,
      priceMinor: draft.priceMinor,
      quantity: draft.openingStock,
      reorderLevel: draft.reorderLevel,
      archived: false,
      revision: 1,
      lastMovementId: operationId,
      createdAt: DateTime.utc(2026, 10, 23),
      updatedAt: DateTime.utc(2026, 10, 23),
    );
    history['$uid/${draft.sku}'] = [
      StockMovement(
        id: operationId,
        type: 'opening',
        beforeQuantity: 0,
        afterQuantity: draft.openingStock,
        delta: draft.openingStock,
        reason: 'Opening stock',
        actorUid: uid,
        revision: 1,
        createdAt: DateTime.utc(2026, 10, 23),
      ),
    ];
  }

  @override
  Future<void> update(
    String uid,
    ProductDraft draft,
    int expectedRevision,
  ) async {
    await _write();
    final current = await get(uid, draft.sku);
    if (current.revision != expectedRevision) {
      throw inventoryInvalid('This product changed. Refresh before saving.');
    }
    products(uid)[draft.sku] = _copy(current, draft: draft);
  }

  @override
  Future<void> setArchived(String uid, Product product, bool archived) async {
    await _write();
    final current = await get(uid, product.sku);
    if (current.quantity != 0) {
      throw inventoryInvalid('Stock must be zero before archiving.');
    }
    products(uid)[product.sku] = _copy(current, archived: archived);
  }

  @override
  Future<void> adjust(
    String uid,
    Product product,
    int delta,
    String reason,
    String operationId,
  ) async {
    await _write();
    final entries = history.putIfAbsent('$uid/${product.sku}', () => []);
    if (entries.any((m) => m.id == operationId)) return;
    final current = await get(uid, product.sku);
    if (current.revision != product.revision) {
      throw inventoryInvalid('This product changed. Refresh before saving.');
    }
    if (current.quantity + delta < 0 || current.quantity + delta > maxStock) {
      throw inventoryInvalid('Stock cannot be negative or exceed its limit.');
    }
    products(uid)[product.sku] = _copy(
      current,
      quantity: current.quantity + delta,
      movement: operationId,
    );
    entries.insert(
      0,
      StockMovement(
        id: operationId,
        type: 'adjustment',
        beforeQuantity: current.quantity,
        afterQuantity: current.quantity + delta,
        delta: delta,
        reason: reason,
        actorUid: uid,
        revision: current.revision + 1,
        createdAt: current.updatedAt.add(const Duration(seconds: 1)),
      ),
    );
  }

  @override
  Future<MovementPage> movements(
    String uid,
    String sku, {
    MovementCursor? after,
  }) async {
    _check();
    final all = history['$uid/$sku'] ?? [];
    final start = after == null
        ? 0
        : all.indexWhere((entry) => entry.id == after.id) + 1;
    final entries = all.skip(start).take(pageSize).toList();
    return MovementPage(
      entries,
      all.length > start + pageSize
          ? MovementCursor(entries.last.createdAt, entries.last.id)
          : null,
    );
  }
}
