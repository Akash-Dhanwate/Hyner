import '../../inventory/domain/product.dart';
import '../../sales/domain/sale.dart';

class PaymentSettings {
  const PaymentSettings({this.upiId = '', this.merchantName = ''});

  final String upiId;
  final String merchantName;

  bool get isReady =>
      RegExp(r'^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9.-]{2,64}$')
          .hasMatch(upiId.trim()) &&
      merchantName.trim().isNotEmpty;

  Uri? upiUri(Sale sale, {int? amountMinor}) {
    final amount = amountMinor ?? sale.draft.totalMinor;
    if (!isReady ||
        sale.draft.currency != 'INR' ||
        amount <= 0 ||
        amount > sale.remainingMinor ||
        amount > sale.draft.totalMinor) {
      return null;
    }
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId.trim(),
        'pn': merchantName.trim(),
        'am': moneyDecimal(amount),
        'cu': 'INR',
        'tn': 'Hyner bill ${sale.id}',
        'tr': '${sale.id}-${sale.payments.length + 1}',
      },
    );
  }
}

abstract interface class PaymentSettingsRepository {
  Future<PaymentSettings> read(String uid);
  Future<void> save(String uid, PaymentSettings settings);
}
