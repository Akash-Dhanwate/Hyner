import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import 'sales_controller.dart';

class RemainingPaymentsScreen extends ConsumerWidget {
  const RemainingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(remainingPaymentsProvider);
    final theme = Theme.of(context);
    return payments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => PageContent(
        children: [
          const Eyebrow('Sales'),
          const SizedBox(height: 12),
          Text('Remaining payments', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          InlineNotice(AppFailure.from(error).displayMessage, isError: true),
          TextButton(
            onPressed: () => ref.invalidate(remainingPaymentsProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (sales) => SliverPageContent(
        onRefresh: () => ref.refresh(remainingPaymentsProvider.future),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Sales'),
            const SizedBox(height: 10),
            Text('Remaining payments', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Bills with a balance still due. Customer names and phone numbers come from the customer saved on each bill.',
            ),
          ],
        ),
        slivers: [
          if (sales.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('There are no outstanding bill balances.'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.separated(
                itemCount: sales.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return InkWell(
                    onTap: () => context.push<void>('/sales/${sale.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sale.draft.customerName ?? 'Walk-in customer',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sale.draft.customerPhone?.trim().isNotEmpty == true
                                ? 'Phone · ${sale.draft.customerPhone}'
                                : 'No phone number saved on this bill',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${saleDate(sale.createdAt)} · ${sale.draft.units} units',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 18,
                            runSpacing: 6,
                            children: [
                              Text(
                                'Bill ${formatMoney(sale.draft.totalMinor, sale.draft.currency)}',
                              ),
                              Text(
                                'Received ${formatMoney(sale.paidMinor, sale.draft.currency)}',
                              ),
                              Text(
                                'Due ${formatMoney(sale.remainingMinor, sale.draft.currency)}',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sale.paymentStatus == PaymentStatus.partial
                                ? 'Advance received · balance due'
                                : 'Payment not yet received',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ref: ${sale.id}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
