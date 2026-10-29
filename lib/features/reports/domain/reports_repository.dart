import 'business_report.dart';

abstract interface class ReportsRepository {
  Future<BusinessReport> load({
    required String uid,
    required String currency,
    required DateTime start,
    required DateTime endExclusive,
  });
}
