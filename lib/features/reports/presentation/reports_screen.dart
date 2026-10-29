import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/domain/product.dart';
import '../data/report_pdf_service.dart';
import '../domain/business_report.dart';
import 'report_charts.dart';
import 'reports_controller.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _currency = 'INR';
  ReportPeriod _period = ReportPeriod.month;

  ReportQuery _query() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime start = switch (_period) {
      ReportPeriod.today => today,
      ReportPeriod.month => DateTime(now.year, now.month, 1),
      ReportPeriod.last30Days => today.subtract(const Duration(days: 29)),
      ReportPeriod.allTime => DateTime(1970, 1, 1),
    };
    return ReportQuery(
      currency: _currency,
      period: _period,
      start: start,
      endExclusive: today.add(const Duration(days: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query();
    final report = ref.watch(businessReportProvider(query));
    final profile = ref.watch(sessionProvider).profile;
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Business overview'),
        const SizedBox(height: 12),
        Text('Reports', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('View sales, purchases, balances, and product performance.'),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: [
            for (final currency in inventoryCurrencies)
              DropdownMenuItem(value: currency, child: Text(currency)),
          ],
          onChanged: (value) => setState(() => _currency = value ?? _currency),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ReportPeriod>(
          initialValue: _period,
          decoration: const InputDecoration(labelText: 'Period'),
          items: const [
            DropdownMenuItem(value: ReportPeriod.today, child: Text('Today')),
            DropdownMenuItem(
              value: ReportPeriod.month,
              child: Text('This month'),
            ),
            DropdownMenuItem(
              value: ReportPeriod.last30Days,
              child: Text('Last 30 days'),
            ),
            DropdownMenuItem(
              value: ReportPeriod.allTime,
              child: Text('All time'),
            ),
          ],
          onChanged: (value) => setState(() => _period = value ?? _period),
        ),
        const SizedBox(height: 24),
        report.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const InlineNotice(
            'Reports could not be loaded from local records.',
            isError: true,
          ),
          data: (data) => _ReportContent(
            report: data,
            preparedFor: profile?.label ?? 'Business owner',
          ),
        ),
      ],
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report, required this.preparedFor});
  final BusinessReport report;
  final String preparedFor;

  Future<void> _downloadPdf(BuildContext context) async {
    final now = DateTime.now();
    try {
      await Printing.layoutPdf(
        name:
            'hyner-activity-${now.year}-${now.month.toString().padLeft(2, '0')}.pdf',
        onLayout: (_) => ReportPdfService.build(
          report,
          preparedFor: preparedFor,
          generatedAt: now,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The PDF report could not be created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Sales'),
        const SizedBox(height: 8),
        _Metric(
          'Sales revenue',
          formatBigMoney(report.revenueMinor, report.currency),
          '${report.salesCount} bills · ${report.soldUnits} units',
        ),
        _Metric(
          'Payment received',
          formatBigMoney(report.paidRevenueMinor, report.currency),
          '${report.paidSalesCount} bills fully paid',
        ),
        _Metric(
          'Balance due',
          formatBigMoney(report.unpaidRevenueMinor, report.currency),
          '${report.unpaidSalesCount} open bills',
        ),
        const SizedBox(height: 12),
        ActivityBarChart(report: report),
        const SizedBox(height: 14),
        PaymentDonutChart(report: report),
        const SizedBox(height: 18),
        Text('Monthly highlights', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final highlight in _reportHighlights(report))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(highlight),
          ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('download-report-pdf'),
            onPressed: () => _downloadPdf(context),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download monthly PDF'),
          ),
        ),
        const SizedBox(height: 22),
        const Eyebrow('Profit and stock'),
        const SizedBox(height: 8),
        _Metric(
          'Gross profit before expenses',
          formatBigMoney(report.grossProfitMinor, report.currency),
          'From bills with saved product costs',
        ),
        _Metric(
          'Cost of goods sold',
          formatBigMoney(report.costOfGoodsMinor, report.currency),
          'From cost captured when each bill was saved',
        ),
        _Metric(
          'Current inventory value',
          formatBigMoney(report.inventoryValueMinor, report.currency),
          'Current stock × weighted-average cost',
        ),
        if (report.uncostedSalesCount > 0) ...[
          const SizedBox(height: 8),
          InlineNotice(
            '${report.uncostedSalesCount} older bills have no saved cost snapshot. Gross profit excludes those bills.',
          ),
        ],
        const SizedBox(height: 22),
        const Eyebrow('Purchases'),
        const SizedBox(height: 8),
        _Metric(
          'Purchases recorded',
          formatBigMoney(report.purchaseSpendMinor, report.currency),
          '${report.purchaseCount} purchase records',
        ),
        _Metric(
          'Returns to suppliers',
          formatBigMoney(report.returnValueMinor, report.currency),
          'Returns recorded in this period',
        ),
        _Metric(
          'Net purchase spend',
          formatBigMoney(report.netPurchasesMinor, report.currency),
          'Purchase records less supplier returns',
        ),
        _Metric(
          'Operating expenses',
          formatBigMoney(report.operatingExpensesMinor, report.currency),
          '${report.otherExpenseCount} manually entered expenses',
        ),
        _Metric(
          'Total recorded expenses',
          formatBigMoney(report.totalExpenseMinor, report.currency),
          'Net purchases plus operating expenses',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push<void>('/expenses'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Record an expense'),
          ),
        ),
        const SizedBox(height: 22),
        const Eyebrow('Top five products by revenue'),
        const SizedBox(height: 8),
        if (report.topProducts.isEmpty)
          const Text('No sales in this period.')
        else
          for (final product in report.topProducts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text('${product.units} units'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatBigMoney(product.revenueMinor, report.currency),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        const SizedBox(height: 12),
        const Text(
          'Operational summary only - not an accounting statement or tax filing.',
        ),
      ],
    );
  }
}

List<String> _reportHighlights(BusinessReport report) {
  final top = report.topProducts.firstOrNull;
  final customerCount = report.salesRecords
      .map((sale) => sale.customer)
      .where((name) => name != 'Walk-in customer')
      .toSet()
      .length;
  return [
    'Sales revenue was ${formatBigMoney(report.revenueMinor, report.currency)} from ${report.salesCount} bills and ${report.soldUnits} units.',
    '${formatBigMoney(report.paidRevenueMinor, report.currency)} was recorded as received; ${formatBigMoney(report.unpaidRevenueMinor, report.currency)} remains due.',
    'Recorded expenses total ${formatBigMoney(report.totalExpenseMinor, report.currency)}: purchases after returns plus ${formatBigMoney(report.operatingExpensesMinor, report.currency)} in operating expenses.',
    top == null
        ? 'No product sales were recorded in this period.'
        : 'The top product was ${top.name}, generating ${formatBigMoney(top.revenueMinor, report.currency)} across ${top.units} units.',
    '$customerCount named customers appear on bills. This is an operational summary from records entered in Hyner, not an accounting statement.',
  ];
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label, value, detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}
