import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/domain/sale.dart';
import '../domain/purchase.dart';
import 'purchases_controller.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  Future<void> _addSupplier(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<SupplierDraft>(
      context: context,
      builder: (_) => const _SupplierDialog(),
    );
    if (draft == null || !context.mounted) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    try {
      await ref.read(purchaseRepositoryProvider).saveSupplier(uid, draft);
      if (!context.mounted) return;
      ref.invalidate(suppliersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier saved on this device.')),
      );
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchasesProvider);
    final controller = ref.read(purchasesProvider.notifier);
    final theme = Theme.of(context);
    return SliverPageContent(
      onRefresh: controller.refresh,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Supplier invoices'),
          const SizedBox(height: 12),
          Text('Purchases', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Record incoming stock and supplier costs. Stock updates with each saved purchase.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('new-purchase'),
                onPressed: () => context.push<void>('/purchases/new'),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Record purchase'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addSupplier(context, ref),
                icon: const Icon(Icons.store_mall_directory_outlined),
                label: const Text('Add supplier'),
              ),
            ],
          ),
        ],
      ),
      slivers: [
        if (state.loading)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(child: LinearProgressIndicator()),
          ),
        if (state.failure != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InlineNotice(state.failure!.displayMessage, isError: true),
                  TextButton(
                    onPressed: state.loadingMore
                        ? null
                        : state.purchases.isEmpty
                        ? controller.refresh
                        : controller.loadMore,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        if (!state.loading && state.failure == null && state.purchases.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Text('No purchases recorded yet.'),
            ),
          ),
        if (state.purchases.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.separated(
              itemCount: state.purchases.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final purchase = state.purchases[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.push<void>('/purchases/${purchase.id}'),
                  title: Text(
                    formatMoney(
                      purchase.draft.totalMinor,
                      purchase.draft.currency,
                    ),
                  ),
                  subtitle: Text(
                    '${purchase.draft.supplierName ?? 'No supplier'} · ${purchaseDate(purchase.createdAt)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        purchase.paymentStatus == PurchasePaymentStatus.paid
                            ? 'Paid'
                            : 'Unpaid',
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        if (state.purchases.isNotEmpty && state.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (state.purchases.isNotEmpty && state.next != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: OutlinedButton(
                onPressed: controller.loadMore,
                child: const Text('Load more purchases'),
              ),
            ),
          ),
      ],
    );
  }
}

String purchaseDate(DateTime date) => saleDate(date);

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog();
  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = SupplierDraft(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      notes: _notes.text.trim(),
    );
    try {
      draft.validate();
      Navigator.pop(context, draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add supplier'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Supplier name'),
          ),
          TextField(
            controller: _phone,
            maxLength: 40,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          TextField(
            controller: _notes,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save supplier')),
    ],
  );
}
