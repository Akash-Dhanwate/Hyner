import 'purchase.dart';

class PurchaseCursor {
  const PurchaseCursor(this.time, this.id);
  final DateTime time;
  final String id;
}

class PurchasePage {
  const PurchasePage(this.purchases, this.next);
  final List<Purchase> purchases;
  final PurchaseCursor? next;
}

abstract interface class PurchaseRepository {
  String newId();
  Future<List<Supplier>> suppliers(String uid);
  Future<Supplier> saveSupplier(String uid, SupplierDraft draft, {String? id});
  Future<PurchasePage> list(String uid, {PurchaseCursor? after});
  Future<Purchase> get(String uid, String id);
  Future<List<PurchaseReturn>> returns(String uid, String purchaseId);
  Future<void> create(String uid, String id, PurchaseDraft draft);
  Future<void> recordReturn(
    String uid,
    String purchaseId,
    Map<String, int> quantities,
    String reason,
    String returnId,
  );
  Future<void> markPaid(String uid, String id);
}
