import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => ref.watch(dependenciesProvider).sales,
);
final salesProvider = NotifierProvider<SalesController, SalesState>(
  SalesController.new,
);

class SalesState {
  const SalesState({
    this.sales = const [],
    this.next,
    this.loading = false,
    this.loadingMore = false,
    this.failure,
  });
  final List<Sale> sales;
  final SalesCursor? next;
  final bool loading, loadingMore;
  final AppFailure? failure;
}

class SalesController extends Notifier<SalesState> {
  String? _uid;
  int _generation = 0;
  @override
  SalesState build() {
    _uid = ref.watch(inventoryUidProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (_uid != null) {
      scheduleMicrotask(() {
        if (ref.mounted && generation == _generation) unawaited(refresh());
      });
    }
    return SalesState(loading: _uid != null);
  }

  bool _current(String uid, int generation) =>
      ref.mounted && _uid == uid && generation == _generation;
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    final generation = ++_generation;
    state = const SalesState(loading: true);
    try {
      final page = await ref.read(salesRepositoryProvider).list(uid);
      if (_current(uid, generation)) {
        state = SalesState(sales: page.sales, next: page.next);
      }
    } catch (error) {
      if (_current(uid, generation)) {
        state = SalesState(failure: AppFailure.from(error));
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
    state = SalesState(
      sales: previous.sales,
      next: previous.next,
      loadingMore: true,
    );
    try {
      final page = await ref
          .read(salesRepositoryProvider)
          .list(uid, after: previous.next);
      if (!_current(uid, generation)) return;
      state = SalesState(
        sales: {
          for (final sale in previous.sales) sale.id: sale,
          for (final sale in page.sales) sale.id: sale,
        }.values.toList(),
        next: page.next,
      );
    } catch (error) {
      if (_current(uid, generation)) {
        state = SalesState(
          sales: previous.sales,
          next: previous.next,
          failure: AppFailure.from(error),
        );
      }
    }
  }
}

final saleProvider = FutureProvider.autoDispose.family<Sale, String>((ref, id) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) {
    throw const AppFailure(
      FailureKind.permission,
      'Sign in before opening sales.',
    );
  }
  return ref.watch(salesRepositoryProvider).get(uid, id);
});

final remainingPaymentsProvider = FutureProvider.autoDispose<List<Sale>>((ref) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) {
    throw const AppFailure(
      FailureKind.permission,
      'Sign in before opening remaining payments.',
    );
  }
  return ref.watch(salesRepositoryProvider).remainingPayments(uid);
});

final scheduledFollowUpsProvider = FutureProvider.autoDispose<List<Sale>>((
  ref,
) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) {
    throw const AppFailure(
      FailureKind.permission,
      'Sign in before opening WhatsApp follow-ups.',
    );
  }
  return ref.watch(salesRepositoryProvider).scheduledFollowUps(uid);
});
