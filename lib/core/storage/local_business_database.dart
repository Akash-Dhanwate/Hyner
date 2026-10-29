import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Local register database. Inventory, customer and bill data stay on this
/// device; Firebase is not used to create or settle a sale.
class LocalBusinessDatabase {
  LocalBusinessDatabase._();

  static final LocalBusinessDatabase instance = LocalBusinessDatabase._();

  final Map<String, Future<Database>> _databases = {};

  Future<Database> databaseFor(String uid) {
    if (uid.isEmpty || uid.contains('/')) {
      throw ArgumentError.value(
        uid,
        'uid',
        'A valid signed-in account is required.',
      );
    }
    return _databases.putIfAbsent(uid, () => _open(uid));
  }

  Future<Database> _open(String uid) async {
    final directory = await getDatabasesPath();
    final fileKey = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return openDatabase(
      '$directory/hyner_register_$fileKey.db',
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            sku TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            parameters TEXT NOT NULL DEFAULT '[]',
            currency TEXT NOT NULL,
            costMinor INTEGER NOT NULL,
            priceMinor INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            reorderLevel INTEGER NOT NULL,
            archived INTEGER NOT NULL,
            revision INTEGER NOT NULL,
            lastMovementId TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX products_name ON products(name COLLATE NOCASE, sku)',
        );
        await db.execute('''
          CREATE TABLE movements (
            id TEXT PRIMARY KEY,
            sku TEXT NOT NULL,
            type TEXT NOT NULL,
            beforeQuantity INTEGER NOT NULL,
            afterQuantity INTEGER NOT NULL,
            delta INTEGER NOT NULL,
            reason TEXT NOT NULL,
            actorUid TEXT NOT NULL,
            revision INTEGER NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX movements_product_date ON movements(sku, createdAt DESC, id DESC)',
        );
        await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            notes TEXT NOT NULL,
            whatsappOptIn INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX customers_name ON customers(name COLLATE NOCASE)',
        );
        await db.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            currency TEXT NOT NULL,
            lines TEXT NOT NULL,
            customerId TEXT,
            customerName TEXT,
            customerPhone TEXT,
            paymentStatus TEXT NOT NULL,
            initialPaymentMinor INTEGER NOT NULL DEFAULT 0,
            expectedPaymentMinor INTEGER NOT NULL DEFAULT 0,
            paidMinor INTEGER NOT NULL DEFAULT 0,
            payments TEXT NOT NULL DEFAULT '[]',
            followupAt TEXT,
            createdAt TEXT NOT NULL,
            paidAt TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX sales_created ON sales(createdAt DESC, id DESC)',
        );
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await _createPurchaseTables(db);
        await _createExpenseTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createPurchaseTables(db);
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE products ADD COLUMN parameters TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            'ALTER TABLE sales ADD COLUMN initialPaymentMinor INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE sales ADD COLUMN expectedPaymentMinor INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE sales ADD COLUMN paidMinor INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "ALTER TABLE sales ADD COLUMN payments TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE customers ADD COLUMN whatsappOptIn INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE sales ADD COLUMN followupAt TEXT');
        }
        if (oldVersion < 5) await _createExpenseTable(db);
      },
    );
  }
}

Future<void> _createExpenseTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE operating_expenses (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      currency TEXT NOT NULL,
      amountMinor INTEGER NOT NULL,
      occurredAt TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX operating_expenses_date ON operating_expenses(currency, occurredAt DESC, id)',
  );
}

Future<void> _createPurchaseTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      notes TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX suppliers_name ON suppliers(name COLLATE NOCASE)',
  );
  await db.execute('''
    CREATE TABLE purchases (
      id TEXT PRIMARY KEY,
      supplierId TEXT,
      supplierName TEXT,
      supplierPhone TEXT,
      currency TEXT NOT NULL,
      items TEXT NOT NULL,
      returnedItems TEXT NOT NULL DEFAULT '{}',
      paymentStatus TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      paidAt TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX purchases_created ON purchases(createdAt DESC, id DESC)',
  );
  await db.execute('''
    CREATE TABLE purchase_returns (
      id TEXT PRIMARY KEY,
      purchaseId TEXT NOT NULL,
      items TEXT NOT NULL,
      totalMinor INTEGER NOT NULL,
      reason TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX purchase_returns_purchase ON purchase_returns(purchaseId, createdAt DESC)',
  );
}
