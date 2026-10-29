import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/customers/data/local_customer_repository.dart';
import '../../features/expenses/data/local_expense_repository.dart';
import '../../features/inventory/data/local_inventory_repository.dart';
import '../../features/inventory/data/firestore_inventory_repository.dart';
import '../../features/profile/data/local_profile_repository.dart';
import '../../features/purchases/data/local_purchase_repository.dart';
import '../../features/reports/data/local_reports_repository.dart';
import '../../features/sales/data/local_sales_repository.dart';
import '../../features/settings/data/local_payment_settings_repository.dart';
import '../../core/storage/local_business_database.dart';
import '../config/app_config.dart';
import '../theme/appearance_repository.dart';
import 'app_dependencies.dart';

Future<AppDependencies> bootstrap() async {
  final appearance = LocalAppearanceRepository();
  var initialTheme = ThemeMode.system;
  String? notice;
  try {
    initialTheme = await appearance.read();
  } catch (_) {
    notice = 'Your saved appearance could not be loaded. The device theme is being used.';
  }
  final config = AppConfig.fromEnvironment();
  final store = LocalBusinessDatabase.instance;
  if (config.isConfigured) {
    try {
      await Firebase.initializeApp(options: config.firebaseOptions)
          .timeout(const Duration(seconds: 20));
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(persistenceEnabled: false);
      return AppDependencies(
        auth: FirebaseAuthRepository(
          FirebaseAuth.instance,
          config.googleServerClientId,
        ),
        profiles: LocalProfileRepository(),
        inventory: LocalInventoryRepository(
          store,
          legacySource: FirestoreInventoryRepository(firestore),
        ),
        sales: LocalSalesRepository(store),
        customers: LocalCustomerRepository(store),
        paymentSettings: LocalPaymentSettingsRepository(store),
        purchases: LocalPurchaseRepository(store),
        expenses: LocalExpenseRepository(store),
        reports: LocalReportsRepository(store),
        appearance: appearance,
        config: config,
        initialTheme: initialTheme,
        startupNotice: notice,
      );
    } catch (_) {
      // Present a setup failure. Never substitute a user or a local session.
      return AppDependencies(
        auth: UnconfiguredAuthRepository(),
        profiles: LocalProfileRepository(),
        inventory: LocalInventoryRepository(store),
        sales: LocalSalesRepository(store),
        customers: LocalCustomerRepository(store),
        paymentSettings: LocalPaymentSettingsRepository(store),
        purchases: LocalPurchaseRepository(store),
        expenses: LocalExpenseRepository(store),
        reports: LocalReportsRepository(store),
        appearance: appearance,
        config: AppConfig(
          environment: config.environment,
          issue: 'Account services could not start. Close and reopen Hyner. If this continues, contact support.',
        ),
        initialTheme: initialTheme,
        startupNotice: notice,
      );
    }
  }
  return AppDependencies(
    auth: UnconfiguredAuthRepository(),
    profiles: LocalProfileRepository(),
    inventory: LocalInventoryRepository(store),
    sales: LocalSalesRepository(store),
    customers: LocalCustomerRepository(store),
    paymentSettings: LocalPaymentSettingsRepository(store),
    purchases: LocalPurchaseRepository(store),
    expenses: LocalExpenseRepository(store),
    reports: LocalReportsRepository(store),
    appearance: appearance,
    config: config,
    initialTheme: initialTheme,
    startupNotice: notice,
  );
}
