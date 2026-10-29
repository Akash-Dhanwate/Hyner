import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sales_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => ref.watch(dependenciesProvider).customers,
);

final customersProvider = FutureProvider.autoDispose<List<Customer>>((ref) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) return const [];
  return ref.watch(customerRepositoryProvider).list(uid);
});

final customerProvider = FutureProvider.autoDispose.family<Customer, String>((
  ref,
  id,
) async {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) throw StateError('Sign in before opening customer history.');
  final customers = await ref.watch(customerRepositoryProvider).list(uid);
  return customers.firstWhere((customer) => customer.id == id);
});

final customerSalesProvider = FutureProvider.autoDispose
    .family<List<Sale>, String>((ref, id) {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) return const [];
      return ref.watch(salesRepositoryProvider).forCustomer(uid, id);
    });
