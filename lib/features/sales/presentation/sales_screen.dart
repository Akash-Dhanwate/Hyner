import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import 'sales_controller.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salesProvider);
    final controller = ref.read(salesProvider.notifier);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Saved bills'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 20,
                          runSpacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Sales history',
                              style: theme.textTheme.headlineMedium,
                            ),
                            FilledButton.icon(
                              key: const Key('new-sale'),
                              onPressed: () => context.push<void>('/sales'),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('New bill'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push<void>('/sales/remaining'),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Remaining payments'),
                            ),
                            IconButton(
                              tooltip: 'Refresh sales',
                              onPressed: state.loading
                                  ? null
                                  : controller.refresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bills stay on this device. Stock updates when you save a bill; payments are recorded after you verify them.',
                        ),
                        const SizedBox(height: 20),
                        if (state.loading) const LinearProgressIndicator(),
                        if (state.failure != null) ...[
                          InlineNotice(
                            state.failure!.displayMessage,
                            isError: true,
                          ),
                          TextButton(
                            onPressed: state.loadingMore
                                ? null
                                : state.sales.isEmpty
                                ? controller.refresh
                                : controller.loadMore,
                            child: const Text('Try again'),
                          ),
                        ],
                        if (!state.loading &&
                            state.failure == null &&
                            state.sales.isEmpty) ...[
                          const SizedBox(height: 32),
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sales yet',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create a bill using your available inventory products.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: state.sales.length,
                    separatorBuilder: (_, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final sale = state.sales[index];
                      return InkWell(
                        key: ValueKey('sale-${sale.id}'),
                        onTap: () => context.push<void>('/sales/${sale.id}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatMoney(
                                        sale.draft.totalMinor,
                                        sale.draft.currency,
                                      ),
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${sale.draft.units} units · ${saleDate(sale.createdAt)}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sale.paymentStatus == PaymentStatus.paid
                                    ? 'Paid · manually verified'
                                    : sale.paymentStatus ==
                                          PaymentStatus.partial
                                    ? 'Part paid · ${formatMoney(sale.remainingMinor, sale.draft.currency)} due'
                                    : 'Payment pending · not verified',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      sale.paymentStatus == PaymentStatus.paid
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (sale.draft.customerName != null) ...[
                                const SizedBox(height: 4),
                                Text('Customer · ${sale.draft.customerName}'),
                              ],
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: state.loadingMore
                          ? const CircularProgressIndicator()
                          : state.next == null
                          ? const SizedBox.shrink()
                          : OutlinedButton(
                              onPressed: controller.loadMore,
                              child: const Text('Load more sales'),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
