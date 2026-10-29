import 'operating_expense.dart';

abstract interface class ExpenseRepository {
  String newId();
  Future<List<OperatingExpense>> list(String uid, {String? currency});
  Future<OperatingExpense> create(
    String uid,
    String id,
    OperatingExpenseDraft draft,
  );
  Future<void> delete(String uid, String id);
}

class UnconfiguredExpenseRepository implements ExpenseRepository {
  const UnconfiguredExpenseRepository();

  Never _unavailable() =>
      throw StateError('Expenses are unavailable in this build.');

  @override
  String newId() => _unavailable();

  @override
  Future<List<OperatingExpense>> list(String uid, {String? currency}) async =>
      _unavailable();

  @override
  Future<OperatingExpense> create(
    String uid,
    String id,
    OperatingExpenseDraft draft,
  ) async => _unavailable();

  @override
  Future<void> delete(String uid, String id) async => _unavailable();
}
