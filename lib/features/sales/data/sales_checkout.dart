import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/sale.dart';

abstract interface class SalesCheckout {
  Future<void> create(String uid, String id, SaleDraft draft);
}

class FirebaseSalesCheckout implements SalesCheckout {
  FirebaseSalesCheckout(this._functions);
  final FirebaseFunctions _functions;
  @override
  Future<void> create(String uid, String id, SaleDraft draft) async {
    try {
      final result = await _functions
          .httpsCallable(
            'createSale',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Map<String, dynamic>>({
            'accountUid': uid,
            'id': id,
            'currency': draft.currency,
            'lines': [
              for (final line in draft.lines)
                {
                  'sku': line.sku,
                  'name': line.name,
                  'unitPriceMinor': line.unitPriceMinor,
                  'quantity': line.quantity,
                },
            ],
          });
      if (result.data['id'] != id) {
        throw const AppFailure(
          FailureKind.unknown,
          'The sale could not be confirmed. Retry this same bill.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw checkoutFailure(error.code, error.message);
    }
  }
}

AppFailure checkoutFailure(String code, String? message) {
  final reference = 'checkout/$code';
  return switch (code) {
    'unauthenticated' || 'permission-denied' => AppFailure(
      FailureKind.permission,
      'Your account could not save this sale. Sign in again and retry.',
      reference: reference,
    ),
    'not-found' || 'unimplemented' => AppFailure(
      FailureKind.configuration,
      'Sales checkout is not enabled yet. The server update must be deployed before saving sales.',
      reference: reference,
    ),
    'invalid-argument' ||
    'failed-precondition' ||
    'already-exists' => AppFailure(
      FailureKind.invalidData,
      message ?? 'Review the products, quantities and prices before saving.',
      reference: reference,
    ),
    _ => AppFailure(
      FailureKind.network,
      'The sale could not be confirmed. Check your connection and retry this same bill.',
      reference: reference,
    ),
  };
}
