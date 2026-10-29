import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/app_failure.dart';
import '../../inventory/data/inventory_codec.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import 'sale_codec.dart';
import 'sales_checkout.dart';

class FirestoreSalesRepository implements SalesRepository {
  FirestoreSalesRepository(this._db, {SalesCheckout? checkout})
    : _checkout =
          checkout ??
          FirebaseSalesCheckout(
            FirebaseFunctions.instanceFor(region: 'asia-south1'),
          );
  final SalesCheckout _checkout;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> _sales(String uid) {
    if (uid.isEmpty || uid.contains('/')) {
      throw inventoryInvalid('Sign in again before using sales.');
    }
    return _db.collection('users').doc(uid).collection('sales');
  }

  DocumentReference<Map<String, dynamic>> _sale(String uid, String id) {
    if (!InventoryCodec.validOperationId(id)) {
      throw inventoryInvalid('Invalid sale reference.');
    }
    return _sales(uid).doc(id);
  }

  @override
  String newSaleId() => _db.collection('users').doc().id;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      final failure = AppFailure.from(error);
      if (error is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(error.code)) {
        throw AppFailure(
          FailureKind.permission,
          'Firestore denied Sales access for this account. Publish the owner get/list rules for users/{uid}/sales to the same Firebase project and confirm this account owns the record.',
          reference: failure.reference,
        );
      }
      if (error is FirebaseException && error.code == 'failed-precondition') {
        throw AppFailure(
          FailureKind.configuration,
          'Sales setup is incomplete. Check the database indexes, then retry.',
          reference: failure.reference,
        );
      }
      throw failure;
    }
  }

  @override
  Future<SalesPage> list(String uid, {SalesCursor? after}) => _guard(() async {
    Query<Map<String, dynamic>> query = _sales(uid)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter([Timestamp.fromDate(after.time), after.id]);
    }
    final result = await query
        .limit(31)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final sales = result.docs
        .take(30)
        .map((doc) => SaleCodec.decode(doc.id, uid, doc.data()))
        .toList();
    return SalesPage(
      sales,
      result.docs.length > 30
          ? SalesCursor(sales.last.createdAt, sales.last.id)
          : null,
    );
  });

  @override
  Future<List<Sale>> forCustomer(String uid, String customerId) =>
      _guard(() async {
        final result = await _sales(uid)
            .where('customerId', isEqualTo: customerId)
            .orderBy('createdAt', descending: true)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 20));
        return result.docs
            .map((doc) => SaleCodec.decode(doc.id, uid, doc.data()))
            .toList();
      });

  @override
  Future<List<Sale>> remainingPayments(String uid) async {
    final result = <Sale>[];
    SalesCursor? cursor;
    do {
      final page = await list(uid, after: cursor);
      result.addAll(page.sales.where((sale) => sale.remainingMinor > 0));
      cursor = page.next;
    } while (cursor != null);
    return result;
  }

  @override
  Future<Sale> get(String uid, String id) => _guard(() async {
    final doc = await _sale(uid, id)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (!doc.exists) {
      throw inventoryInvalid('This sale could not be found. Refresh sales.');
    }
    return SaleCodec.decode(id, uid, doc.data());
  });

  @override
  Future<void> create(String uid, String id, SaleDraft draft) => _guard(
    () async {
      draft.validate();
      _sale(uid, id); // Validate account and reference before calling checkout.
      await _checkout.create(uid, id, draft);
    },
  );

  @override
  Future<void> markPaid(String uid, String id) async => throw const AppFailure(
    FailureKind.configuration,
    'Payment status is stored on this device in local register mode.',
  );

  @override
  Future<void> recordPayment(String uid, String id, int amountMinor) async =>
      throw const AppFailure(
        FailureKind.configuration,
        'Payment status is stored on this device in local register mode.',
      );

  @override
  Future<void> setFollowUp(String uid, String id, DateTime? followupAt) async =>
      throw const AppFailure(
        FailureKind.configuration,
        'Follow-ups are stored on this device in local register mode.',
      );

  @override
  Future<List<Sale>> scheduledFollowUps(String uid) async =>
      throw const AppFailure(
        FailureKind.configuration,
        'Follow-ups are stored on this device in local register mode.',
      );
}

class UnconfiguredSalesRepository implements SalesRepository {
  const UnconfiguredSalesRepository();
  Never _unavailable() => throw const AppFailure(
    FailureKind.configuration,
    'Sales services are not connected.',
  );
  @override
  String newSaleId() => _unavailable();
  @override
  Future<SalesPage> list(String uid, {SalesCursor? after}) async =>
      _unavailable();
  @override
  Future<List<Sale>> forCustomer(String uid, String customerId) async =>
      _unavailable();
  @override
  Future<Sale> get(String uid, String id) async => _unavailable();
  @override
  Future<void> create(String uid, String id, SaleDraft draft) async =>
      _unavailable();
  @override
  Future<void> markPaid(String uid, String id) async => _unavailable();
  @override
  Future<void> recordPayment(String uid, String id, int amountMinor) async =>
      _unavailable();
  @override
  Future<List<Sale>> remainingPayments(String uid) async => _unavailable();
  @override
  Future<void> setFollowUp(String uid, String id, DateTime? followupAt) async =>
      _unavailable();
  @override
  Future<List<Sale>> scheduledFollowUps(String uid) async => _unavailable();
}
