import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => ref.watch(dependenciesProvider).purchases,
);

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) return const [];
  return ref.watch(purchaseRepositoryProvider).suppliers(uid);
});

final purchasesProvider =
    NotifierProvider.autoDispose<PurchasesController, PurchasesState>(
      PurchasesController.new,
    );

class PurchasesState {
  const PurchasesState({
    this.purchases = const [],
    this.next,
    this.loading = false,
    this.loadingMore = false,
    this.failure,
  });

  final List<Purchase> purchases;
  final PurchaseCursor? next;
  final bool loading;
  final bool loadingMore;
  final AppFailure? failure;
}

class PurchasesController extends Notifier<PurchasesState> {
  String? _uid;
  int _generation = 0;

  @override
  PurchasesState build() {
    _uid = ref.watch(inventoryUidProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (_uid != null) {
      scheduleMicrotask(() {
        if (ref.mounted && generation == _generation) unawaited(refresh());
      });
    }
    return PurchasesState(loading: _uid != null);
  }

  bool _current(String uid, int generation) =>
      ref.mounted && _uid == uid && generation == _generation;

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    final generation = ++_generation;
    state = const PurchasesState(loading: true);
    try {
      final page = await ref.read(purchaseRepositoryProvider).list(uid);
      if (_current(uid, generation)) {
        state = PurchasesState(purchases: page.purchases, next: page.next);
      }
    } catch (error) {
      if (_current(uid, generation)) {
        state = PurchasesState(failure: AppFailure.from(error));
      }
    }
  }

  Future<void> loadMore() async {
    final uid = _uid;
    final previous = state;
    if (uid == null ||
        previous.next == null ||
        previous.loading ||
        previous.loadingMore) {
      return;
    }
    final generation = _generation;
    state = PurchasesState(
      purchases: previous.purchases,
      next: previous.next,
      loadingMore: true,
    );
    try {
      final page = await ref
          .read(purchaseRepositoryProvider)
          .list(uid, after: previous.next);
      if (!_current(uid, generation)) return;
      state = PurchasesState(
        purchases: {
          for (final purchase in previous.purchases) purchase.id: purchase,
          for (final purchase in page.purchases) purchase.id: purchase,
        }.values.toList(),
        next: page.next,
      );
    } catch (error) {
      if (_current(uid, generation)) {
        state = PurchasesState(
          purchases: previous.purchases,
          next: previous.next,
          failure: AppFailure.from(error),
        );
      }
    }
  }
}

final purchaseProvider = FutureProvider.autoDispose.family<Purchase, String>((
  ref,
  id,
) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) throw StateError('Sign in before opening a purchase.');
  return ref.watch(purchaseRepositoryProvider).get(uid, id);
});

final purchaseReturnsProvider = FutureProvider.autoDispose
    .family<List<PurchaseReturn>, String>((ref, id) {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) return const [];
      return ref.watch(purchaseRepositoryProvider).returns(uid, id);
    });
