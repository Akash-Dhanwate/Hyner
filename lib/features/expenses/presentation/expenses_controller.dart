import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/expense_repository.dart';
import '../domain/operating_expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ref.watch(dependenciesProvider).expenses,
);

final expensesProvider = FutureProvider.autoDispose<List<OperatingExpense>>((
  ref,
) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) return const [];
  return ref.watch(expenseRepositoryProvider).list(uid);
});
