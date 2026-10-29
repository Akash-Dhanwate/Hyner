import 'dart:async';

import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sales_repository.dart';

import 'inventory_fakes.dart';

class FakeSales implements SalesRepository {
  FakeSales(this.inventory);
  final FakeInventory inventory;
  final Map<String, Map<String, Sale>> accounts = {};
  Map<String, Sale> sales(String uid) => accounts.putIfAbsent(uid, () => {});
  AppFailure? failure;
  bool failAfterCommit = false;
  Completer<SalesPage>? pendingList;
  Completer<void>? pendingWrite;
  int ids = 0, writes = 0, pageSize = 30;
  final requestedUids = <String>[];
  @override
  String newSaleId() => 'sale${++ids}';
  @override
  Future<SalesPage> list(String uid, {SalesCursor? after}) async {
    requestedUids.add(uid);
    if (pendingList != null) return pendingList!.future;
    if (failure != null) throw failure!;
    final values = sales(uid).values.toList()
      ..sort((a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    final remaining = values
        .where(
          (s) =>
              after == null ||
              s.createdAt.isBefore(after.time) ||
              (s.createdAt == after.time && s.id.compareTo(after.id) < 0),
        )
        .toList();
    final page = remaining.take(pageSize).toList();
    return SalesPage(
      page,
      remaining.length > pageSize
          ? SalesCursor(page.last.createdAt, page.last.id)
          : null,
    );
  }

  @override
  Future<List<Sale>> forCustomer(String uid, String customerId) async =>
      sales(uid).values
          .where((sale) => sale.draft.customerId == customerId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Sale> get(String uid, String id) async {
    if (failure != null) throw failure!;
    return sales(uid)[id] ?? (throw inventoryInvalid('Sale not found'));
  }

  @override
  Future<void> create(String uid, String id, SaleDraft draft) async {
    if (pendingWrite != null) await pendingWrite!.future;
    if (failure != null) throw failure!;
    draft.validate();
    final existing = sales(uid)[id];
    if (existing != null) {
      if (!existing.draft.matches(draft)) {
        throw inventoryInvalid('Sale reference already used');
      }
      return;
    }
    for (final line in draft.lines) {
      final p = inventory.products(uid)[line.sku];
      if (p == null || p.archived || p.quantity < line.quantity) {
        throw inventoryInvalid('Insufficient available stock.');
      }
      if (p.name != line.name || p.currency != draft.currency) {
        throw inventoryInvalid('Product changed. Remove it and add it again.');
      }
    }
    for (final line in draft.lines) {
      final p = inventory.products(uid)[line.sku]!;
      inventory.products(uid)[line.sku] = Product(
        sku: p.sku,
        name: p.name,
        category: p.category,
        currency: p.currency,
        costMinor: p.costMinor,
        priceMinor: p.priceMinor,
        quantity: p.quantity - line.quantity,
        reorderLevel: p.reorderLevel,
        archived: false,
        revision: p.revision + 1,
        lastMovementId: id,
        createdAt: p.createdAt,
        updatedAt: DateTime.utc(2026, 10, 25, 12),
      );
    }
    sales(uid)[id] = Sale(
      id: id,
      draft: draft,
      createdAt: DateTime.utc(2026, 10, 25, 12),
    );
    writes++;
    if (failAfterCommit) {
      throw const AppFailure(FailureKind.network, 'Connection interrupted');
    }
  }

  @override
  Future<void> markPaid(String uid, String id) async {
    final sale = sales(uid)[id];
    if (sale == null) throw inventoryInvalid('Sale not found');
    sales(uid)[id] = Sale(
      id: sale.id,
      draft: sale.draft,
      createdAt: sale.createdAt,
      paymentStatus: PaymentStatus.paid,
      paidAt: DateTime.utc(2026, 10, 25, 12),
    );
  }
}
