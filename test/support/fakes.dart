import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/config/app_config.dart';
import 'package:hyner/app/theme/appearance_repository.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/customers/domain/customer_repository.dart';
import 'package:hyner/features/profile/domain/profile_repository.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';
import 'package:hyner/features/purchases/domain/purchase.dart';
import 'package:hyner/features/purchases/domain/purchase_repository.dart';
import 'package:hyner/features/reports/domain/business_report.dart';
import 'package:hyner/features/reports/domain/reports_repository.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';

import 'inventory_fakes.dart';
import 'sales_fakes.dart';

// Isolated test fixtures. These are never compiled into lib/ or the application.
const testIdentity = AccountIdentity(
  uid: 'test-alice',
  email: 'alice@example.test',
  displayName: 'Alice Test',
);
UserProfile testProfile() => UserProfile(
  uid: testIdentity.uid,
  email: testIdentity.email,
  displayName: testIdentity.displayName,
  createdAt: DateTime.utc(2025, 1, 15),
  lastLoginAt: DateTime.utc(2026, 1, 15),
);

class FakeAuth implements AuthRepository {
  FakeAuth({this.user});
  AccountIdentity? user;
  final _changes = StreamController<AccountIdentity?>.broadcast();
  AppFailure? signInFailure;
  AppFailure? signOutFailure;
  bool cleanupFails = false;
  int signInCalls = 0;

  @override
  AccountIdentity? get currentUser => user;
  @override
  Stream<AccountIdentity?> authStateChanges() async* {
    yield user;
    yield* _changes.stream;
  }

  @override
  Future<AccountIdentity> signInWithGoogle() async {
    signInCalls++;
    if (signInFailure != null) throw signInFailure!;
    user = testIdentity;
    _changes.add(user);
    return user!;
  }

  @override
  Future<void> signOut() async {
    if (signOutFailure != null) throw signOutFailure!;
    user = null;
    _changes.add(null);
    if (cleanupFails) {
      throw const AppFailure(
        FailureKind.unknown,
        'Simulated provider cleanup failure',
      );
    }
  }

  Future<void> close() => _changes.close();
  void changeAccount(AccountIdentity? identity) {
    user = identity;
    _changes.add(identity);
  }
}

class FakeProfiles implements ProfileRepository {
  AppFailure? failure;
  UserProfile? result;
  Completer<UserProfile>? pending;
  int calls = 0;
  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? result ?? testProfile() : pending!.future;
  }
}

class MemoryAppearance implements AppearanceRepository {
  ThemeMode mode = ThemeMode.system;
  bool failWrites = false;
  @override
  Future<ThemeMode> read() async => mode;
  @override
  Future<void> write(ThemeMode value) async {
    if (failWrites) throw StateError('Simulated storage failure');
    mode = value;
  }
}

class FakeCustomers implements CustomerRepository {
  final Map<String, List<Customer>> accounts = {};
  @override
  Future<List<Customer>> list(String uid) async =>
      List.of(accounts.putIfAbsent(uid, () => []));
  @override
  Future<Customer> save(String uid, CustomerDraft draft, {String? id}) async {
    draft.validate();
    final now = DateTime.utc(2026, 1, 1);
    final values = accounts.putIfAbsent(uid, () => []);
    final customer = Customer(
      id: id ?? 'customer-${values.length + 1}',
      name: draft.name,
      phone: draft.phone,
      notes: draft.notes,
      createdAt: now,
      updatedAt: now,
    );
    values.removeWhere((value) => value.id == customer.id);
    values.add(customer);
    return customer;
  }
}

class MemoryPaymentSettings implements PaymentSettingsRepository {
  final Map<String, PaymentSettings> values = {};
  @override
  Future<PaymentSettings> read(String uid) async =>
      values[uid] ?? const PaymentSettings();
  @override
  Future<void> save(String uid, PaymentSettings settings) async =>
      values[uid] = settings;
}

class FakePurchases implements PurchaseRepository {
  int ids = 0;
  @override
  String newId() => 'purchase-${++ids}';
  @override
  Future<List<Supplier>> suppliers(String uid) async => [];
  @override
  Future<Supplier> saveSupplier(
    String uid,
    SupplierDraft draft, {
    String? id,
  }) async => Supplier(
    id: id ?? 'supplier-${++ids}',
    name: draft.name,
    phone: draft.phone,
    notes: draft.notes,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  @override
  Future<PurchasePage> list(String uid, {PurchaseCursor? after}) async =>
      const PurchasePage([], null);
  @override
  Future<Purchase> get(String uid, String id) async =>
      throw StateError('Purchase not found');
  @override
  Future<List<PurchaseReturn>> returns(String uid, String purchaseId) async =>
      [];
  @override
  Future<void> create(String uid, String id, PurchaseDraft draft) async {}
  @override
  Future<void> recordReturn(
    String uid,
    String purchaseId,
    Map<String, int> quantities,
    String reason,
    String returnId,
  ) async {}
  @override
  Future<void> markPaid(String uid, String id) async {}
}

class FakeReports implements ReportsRepository {
  @override
  Future<BusinessReport> load({
    required String uid,
    required String currency,
    required DateTime start,
    required DateTime endExclusive,
  }) async => BusinessReport(
    currency: currency,
    start: start,
    end: endExclusive,
    salesCount: 0,
    soldUnits: 0,
    paidSalesCount: 0,
    unpaidSalesCount: 0,
    revenueMinor: BigInt.zero,
    paidRevenueMinor: BigInt.zero,
    unpaidRevenueMinor: BigInt.zero,
    trackedRevenueMinor: BigInt.zero,
    costOfGoodsMinor: BigInt.zero,
    grossProfitMinor: BigInt.zero,
    uncostedSalesCount: 0,
    purchaseCount: 0,
    purchaseSpendMinor: BigInt.zero,
    returnValueMinor: BigInt.zero,
    inventoryValueMinor: BigInt.zero,
    topProducts: const [],
  );
}

AppDependencies testDependencies(
  FakeAuth auth,
  FakeProfiles profiles, {
  MemoryAppearance? appearance,
  bool configured = true,
}) => AppDependencies(
  auth: auth,
  profiles: profiles,
  inventory: FakeInventory(),
  sales: FakeSales(FakeInventory()),
  customers: FakeCustomers(),
  paymentSettings: MemoryPaymentSettings(),
  purchases: FakePurchases(),
  reports: FakeReports(),
  appearance: appearance ?? MemoryAppearance(),
  config: AppConfig(
    environment: AppEnvironment.development,
    // Explicit test-only SDK options are omitted: the fake config overrides only
    // the UI availability flag through a test subclass below.
    issue: configured
        ? null
        : 'This installation has not been connected to account services.',
  ),
);

class ConfiguredTestConfig extends AppConfig {
  const ConfiguredTestConfig() : super(environment: AppEnvironment.development);
  @override
  bool get isConfigured => true;
}

AppDependencies connectedTestDependencies(
  FakeAuth auth,
  FakeProfiles profiles, {
  MemoryAppearance? appearance,
  FakeInventory? inventory,
  FakeSales? sales,
}) => AppDependencies(
  auth: auth,
  profiles: profiles,
  inventory: inventory ?? FakeInventory(),
  sales: sales ?? FakeSales(inventory ?? FakeInventory()),
  customers: FakeCustomers(),
  paymentSettings: MemoryPaymentSettings(),
  purchases: FakePurchases(),
  reports: FakeReports(),
  appearance: appearance ?? MemoryAppearance(),
  config: const ConfiguredTestConfig(),
);
