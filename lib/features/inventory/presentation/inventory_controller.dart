import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';

final inventoryUidProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  return session.isAuthenticated ? session.profile!.uid : null;
});
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => ref.watch(dependenciesProvider).inventory,
);

final inventoryProvider = NotifierProvider<InventoryController, InventoryState>(
  InventoryController.new,
);

class InventoryState {
  const InventoryState({
    this.products = const [],
    this.query = const InventoryQuery(),
    this.next,
    this.loading = false,
    this.loadingMore = false,
    this.failure,
  });
  final List<Product> products;
  final InventoryQuery query;
  final InventoryCursor? next;
  final bool loading;
  final bool loadingMore;
  final AppFailure? failure;
}

class InventoryController extends Notifier<InventoryState> {
  String? _uid;
  int _generation = 0;

  @override
  InventoryState build() {
    _uid = ref.watch(inventoryUidProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (_uid != null) {
      scheduleMicrotask(() {
        if (ref.mounted && generation == _generation) unawaited(refresh());
      });
    }
    return InventoryState(loading: _uid != null);
  }

  bool _current(String uid, int generation) =>
      ref.mounted && _uid == uid && generation == _generation;

  void didWrite(String uid, String sku, {bool refreshProduct = true}) {
    if (!ref.mounted || _uid != uid) return;
    if (refreshProduct) ref.invalidate(inventoryProductProvider(sku));
    unawaited(refresh());
    checkStock(uid, sku);
  }

  void checkStock(String uid, String sku) {
    if (!ref.mounted || _uid != uid) return;
    unawaited(_syncStockAlert(uid, sku));
  }

  Future<void> checkAllLowStock() async {
    final uid = _uid;
    if (uid == null || !ref.mounted) return;
    final repository = ref.read(inventoryRepositoryProvider);
    InventoryCursor? cursor;
    do {
      final page = await repository.list(
        uid,
        const InventoryQuery(),
        after: cursor,
      );
      if (!ref.mounted || _uid != uid) return;
      for (final product in page.products) {
        if (product.isLowStock) {
          await LocalNotificationService.instance.lowStock(
            sku: product.sku,
            productName: product.name,
            quantity: product.quantity,
            reorderLevel: product.reorderLevel,
          );
        }
      }
      cursor = page.next;
    } while (cursor != null);
  }

  Future<void> _syncStockAlert(String uid, String sku) async {
    try {
      final product = await ref.read(inventoryRepositoryProvider).get(uid, sku);
      if (!ref.mounted || _uid != uid) return;
      if (product.isLowStock) {
        await LocalNotificationService.instance.lowStock(
          sku: product.sku,
          productName: product.name,
          quantity: product.quantity,
          reorderLevel: product.reorderLevel,
        );
      } else {
        await LocalNotificationService.instance.clearLowStock(sku);
      }
    } catch (_) {
      // A notification check must never interrupt a stock save or sign-out.
    }
  }

  Future<void> refresh({InventoryQuery? query}) async {
    final uid = _uid;
    if (uid == null) return;
    final generation = ++_generation;
    final filter = query ?? state.query;
    state = InventoryState(query: filter, loading: true);
    try {
      final page = await ref
          .read(inventoryRepositoryProvider)
          .list(uid, filter);
      if (!_current(uid, generation)) return;
      state = InventoryState(
        products: page.products,
        query: filter,
        next: page.next,
      );
    } catch (error) {
      if (_current(uid, generation)) {
        state = InventoryState(query: filter, failure: AppFailure.from(error));
      }
    }
  }

  Future<void> loadMore() async {
    final uid = _uid;
    final cursor = state.next;
    if (uid == null || cursor == null || state.loading || state.loadingMore) {
      return;
    }
    final generation = _generation;
    final previous = state;
    state = InventoryState(
      products: previous.products,
      query: previous.query,
      next: cursor,
      loadingMore: true,
    );
    try {
      final page = await ref
          .read(inventoryRepositoryProvider)
          .list(uid, previous.query, after: cursor);
      if (!_current(uid, generation)) return;
      final combined = {
        for (final product in previous.products) product.sku: product,
        for (final product in page.products) product.sku: product,
      };
      state = InventoryState(
        products: combined.values.toList(),
        query: previous.query,
        next: page.next,
      );
    } catch (error) {
      if (_current(uid, generation)) {
        state = InventoryState(
          products: previous.products,
          query: previous.query,
          next: cursor,
          failure: AppFailure.from(error),
        );
      }
    }
  }
}

final inventoryProductProvider = FutureProvider.autoDispose
    .family<Product, String>((ref, sku) {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) {
        throw const AppFailure(
          FailureKind.permission,
          'Sign in before opening inventory.',
        );
      }
      return ref.watch(inventoryRepositoryProvider).get(uid, sku);
    });
