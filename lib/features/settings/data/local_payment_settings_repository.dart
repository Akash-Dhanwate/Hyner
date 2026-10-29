import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../domain/payment_settings.dart';

class LocalPaymentSettingsRepository implements PaymentSettingsRepository {
  LocalPaymentSettingsRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  Future<PaymentSettings> read(String uid) async {
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'settings',
      where: 'key IN (?, ?)',
      whereArgs: ['upiId', 'merchantName'],
    );
    final values = {for (final row in rows) row['key']: row['value'] as String};
    return PaymentSettings(
      upiId: values['upiId'] ?? '',
      merchantName: values['merchantName'] ?? '',
    );
  }

  @override
  Future<void> save(String uid, PaymentSettings settings) async {
    final upiId = settings.upiId.trim();
    final name = settings.merchantName.trim();
    if (upiId.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9.-]{2,64}$')
            .hasMatch(upiId)) {
      throw const FormatException(
        'Enter a valid UPI ID, for example shop@bank.',
      );
    }
    if (name.length > 80) {
      throw const FormatException(
        'Business name must be 80 characters or less.',
      );
    }
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      for (final entry in {'upiId': upiId, 'merchantName': name}.entries) {
        await tx.insert('settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
