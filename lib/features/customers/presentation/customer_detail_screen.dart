import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../domain/customer.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/domain/sale.dart';
import 'customers_controller.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _setWhatsAppConsent(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final consent = !customer.whatsappOptIn;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          consent ? 'Allow product updates?' : 'Stop product updates?',
        ),
        content: Text(
          consent
              ? 'This customer will be available in the WhatsApp product update list.'
              : 'This customer will be excluded from WhatsApp product updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(consent ? 'Allow updates' : 'Stop updates'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    try {
      await ref
          .read(customerRepositoryProvider)
          .save(
            uid,
            CustomerDraft(
              name: customer.name,
              phone: customer.phone,
              notes: customer.notes,
              whatsappOptIn: consent,
            ),
            id: customer.id,
          );
      ref.invalidate(customerProvider(id));
      ref.invalidate(customersProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp preferences could not be saved.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(id));
    final sales = ref.watch(customerSalesProvider(id));
    return customer.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => PageContent(
        children: [
          const InlineNotice('Customer could not be loaded.', isError: true),
          TextButton(
            onPressed: () => ref.invalidate(customerProvider(id)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (value) => SliverPageContent(
        onRefresh: () => ref.refresh(customerSalesProvider(id).future),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Customer account'),
            const SizedBox(height: 12),
            Text(value.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            if (value.phone.isNotEmpty) SelectableText(value.phone),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _setWhatsAppConsent(context, ref, value),
              icon: Icon(
                value.whatsappOptIn
                    ? Icons.notifications_off_outlined
                    : Icons.chat_outlined,
              ),
              label: Text(
                value.whatsappOptIn
                    ? 'Exclude from WhatsApp product updates'
                    : 'Allow WhatsApp product updates',
              ),
            ),
            if (value.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(value.notes),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push<void>(
                '/sales/new?customerId=${Uri.encodeComponent(value.id)}',
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Build bill for this customer'),
            ),
            const SizedBox(height: 28),
            const Eyebrow('Account history'),
            const SizedBox(height: 12),
          ],
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: sales.when(
              loading: () =>
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
              error: (_, _) => const SliverToBoxAdapter(
                child: InlineNotice(
                  'Customer bills could not be loaded.',
                  isError: true,
                ),
              ),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Text('No bills are linked to this customer yet.'),
                    )
                  : SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final sale = items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => context.push<void>('/sales/${sale.id}'),
                          title: Text(
                            formatMoney(
                              sale.draft.totalMinor,
                              sale.draft.currency,
                            ),
                          ),
                          subtitle: Text(
                            '${saleDate(sale.createdAt)} · ${sale.draft.units} units',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                sale.paymentStatus == PaymentStatus.paid
                                    ? 'Paid'
                                    : sale.paymentStatus ==
                                          PaymentStatus.partial
                                    ? '${formatMoney(sale.remainingMinor, sale.draft.currency)} due'
                                    : 'Pending',
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Payment status is recorded locally after you check your UPI app.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
