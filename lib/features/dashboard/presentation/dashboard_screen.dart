import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../reports/domain/business_report.dart';
import '../../reports/presentation/report_charts.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../workspace/presentation/module_catalog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final today = DateTime.now();
    final allTimeQuery = ReportQuery(
      currency: 'INR',
      period: ReportPeriod.allTime,
      start: DateTime(1970, 1, 1),
      endExclusive: DateTime(today.year, today.month, today.day + 1),
    );
    final report = ref.watch(businessReportProvider(allTimeQuery));
    final customers = ref.watch(customersProvider);
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Home'),
        const SizedBox(height: 10),
        Text(
          'Hello, ${profile?.firstName ?? 'there'}.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 22),
        Text('Business snapshot', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        report.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              const InlineNotice('Business totals could not be loaded.'),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              customers.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    const _DashboardMetrics(customerCount: 0, report: null),
                data: (items) => _DashboardMetrics(
                  customerCount: items.length,
                  report: data,
                ),
              ),
              const SizedBox(height: 14),
              ActivityBarChart(report: data),
              const SizedBox(height: 14),
              PaymentDonutChart(report: data),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Eyebrow('Business tools'),
        const SizedBox(height: 10),
        for (final module in businessModules) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .6,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(module.icon, size: 24),
            ),
            title: Text(
              module.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              module.available
                  ? module.description
                  : 'Coming in a future update',
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => openWorkspacePage(GoRouter.of(context), module.path),
          ),
          const Divider(),
        ],
      ],
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.customerCount, required this.report});
  final int customerCount;
  final BusinessReport? report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      ('Customers', '$customerCount', Icons.people_outline_rounded),
      ('Sales', '${report?.salesCount ?? 0}', Icons.receipt_long_outlined),
      (
        'Revenue',
        formatBigMoney(
          report?.revenueMinor ?? BigInt.zero,
          report?.currency ?? 'INR',
        ),
        Icons.trending_up_rounded,
      ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in values)
          SizedBox(
            width: 158,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(value.$3, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(value.$1, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(
                    value.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
