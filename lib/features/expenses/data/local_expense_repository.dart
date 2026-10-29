import 'dart:math';

import '../../../core/storage/local_business_database.dart';
import '../domain/expense_repository.dart';
import '../domain/operating_expense.dart';

class LocalExpenseRepository implements ExpenseRepository {
  LocalExpenseRepository(this._store);

  final LocalBusinessDatabase _store;

  @override
  String newId() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  @override
  Future<List<OperatingExpense>> list(String uid, {String? currency}) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'operating_expenses',
      where: currency == null ? null : 'currency = ?',
      whereArgs: currency == null ? null : [currency],
      orderBy: 'occurredAt DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<OperatingExpense> create(
    String uid,
    String id,
    OperatingExpenseDraft draft,
  ) async {
    _checkUid(uid);
    draft.validate();
    if (id.length != 32 || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw const FormatException('This expense reference is invalid.');
    }
    final db = await _store.databaseFor(uid);
    final now = DateTime.now().toUtc();
    final values = {
      'id': id,
      'category': draft.category,
      'description': draft.description.trim(),
      'currency': draft.currency,
      'amountMinor': draft.amountMinor,
      'occurredAt': draft.occurredAt.toUtc().toIso8601String(),
      'createdAt': now.toIso8601String(),
    };
    await db.insert('operating_expenses', values);
    return _fromRow(values);
  }

  @override
  Future<void> delete(String uid, String id) async {
    _checkUid(uid);
    final db = await _store.databaseFor(uid);
    await db.delete('operating_expenses', where: 'id = ?', whereArgs: [id]);
  }
}

OperatingExpense _fromRow(Map<String, Object?> row) => OperatingExpense(
  id: row['id']! as String,
  category: row['category']! as String,
  description: row['description']! as String,
  currency: row['currency']! as String,
  amountMinor: row['amountMinor']! as int,
  occurredAt: DateTime.parse(row['occurredAt']! as String),
);

void _checkUid(String uid) {
  if (uid.isEmpty || uid.contains('/')) {
    throw ArgumentError.value(uid, 'uid');
  }
}
