import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/payment_settings.dart';

final paymentSettingsProvider = FutureProvider.autoDispose<PaymentSettings>((
  ref,
) {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) return const PaymentSettings();
  return ref.watch(dependenciesProvider).paymentSettings.read(uid);
});
