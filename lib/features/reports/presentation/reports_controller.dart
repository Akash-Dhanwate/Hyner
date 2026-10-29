import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/business_report.dart';

enum ReportPeriod { today, month, last30Days, allTime }

class ReportQuery {
  const ReportQuery({
    required this.currency,
    required this.period,
    required this.start,
    required this.endExclusive,
  });
  final String currency;
  final ReportPeriod period;
  final DateTime start;
  final DateTime endExclusive;

  @override
  bool operator ==(Object other) =>
      other is ReportQuery &&
      other.currency == currency &&
      other.period == period &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(currency, period, start, endExclusive);
}

final businessReportProvider = FutureProvider.autoDispose
    .family<BusinessReport, ReportQuery>((ref, query) {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) throw StateError('Sign in to open reports.');
      return ref
          .watch(dependenciesProvider)
          .reports
          .load(
            uid: uid,
            currency: query.currency,
            start: query.start,
            endExclusive: query.endExclusive,
          );
    });
