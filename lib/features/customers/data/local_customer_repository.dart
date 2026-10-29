import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class LocalCustomerRepository implements CustomerRepository {
  LocalCustomerRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  Future<List<Customer>> list(String uid) async {
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE, id',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Customer> save(String uid, CustomerDraft draft, {String? id}) async {
    draft.validate();
    final db = await _store.databaseFor(uid);
    final now = DateTime.now().toUtc();
    final customerId = id ?? _newId();
    return db.transaction((tx) async {
      final rows = await tx.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      final createdAt = rows.isEmpty
          ? now
          : DateTime.parse(rows.single['createdAt']! as String);
      final values = {
        'id': customerId,
        'name': draft.name,
        'phone': draft.phone.trim(),
        'notes': draft.notes.trim(),
        'whatsappOptIn': draft.whatsappOptIn ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await tx.insert(
        'customers',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return _fromRow(values);
    });
  }
}

Customer _fromRow(Map<String, Object?> row) => Customer(
  id: row['id']! as String,
  name: row['name']! as String,
  phone: row['phone']! as String,
  notes: row['notes']! as String,
  whatsappOptIn: row['whatsappOptIn'] == 1,
  createdAt: DateTime.parse(row['createdAt']! as String),
  updatedAt: DateTime.parse(row['updatedAt']! as String),
);

String _newId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
