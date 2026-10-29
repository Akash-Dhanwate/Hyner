import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/domain/sale.dart';
import '../domain/purchase.dart';
import 'purchases_controller.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    Purchase purchase,
  ) async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark supplier invoice paid?'),
        content: const Text(
          'Confirm only after you have paid the supplier outside Hyner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(purchaseRepositoryProvider).markPaid(uid, purchase.id);
      unawaited(
        LocalNotificationService.instance.activity(
          title: 'Supplier payment recorded',
          body: 'Purchase invoice marked as paid.',
        ),
      );
      ref.invalidate(purchaseProvider(purchase.id));
      ref.invalidate(purchasesProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase payment status could not be saved.'),
        ),
      );
    }
  }

  Future<void> _returnItems(
    BuildContext context,
    WidgetRef ref,
    Purchase purchase,
  ) async {
    final draft = await showDialog<_ReturnDraft>(
      context: context,
      builder: (_) => _ReturnDialog(purchase: purchase),
    );
    if (draft == null || !context.mounted) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    try {
      final returnId = ref.read(purchaseRepositoryProvider).newId();
      await ref
          .read(purchaseRepositoryProvider)
          .recordReturn(
            uid,
            purchase.id,
            draft.quantities,
            draft.reason,
            returnId,
          );
      for (final sku in draft.quantities.keys) {
        ref.read(inventoryProvider.notifier).checkStock(uid, sku);
      }
      unawaited(
        LocalNotificationService.instance.activity(
          title: 'Purchase return recorded',
          body:
              '${draft.quantities.values.fold<int>(0, (sum, amount) => sum + amount)} units returned',
        ),
      );
      if (!context.mounted) return;
      ref.invalidate(purchaseProvider(purchase.id));
      ref.invalidate(purchaseReturnsProvider(purchase.id));
      ref.invalidate(purchasesProvider);
      ref.invalidate(inventoryProvider);
      for (final sku in draft.quantities.keys) {
        ref.invalidate(inventoryProductProvider(sku));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase return recorded and stock updated.'),
        ),
      );
    } on AppFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.displayMessage)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase return could not be recorded.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseState = ref.watch(purchaseProvider(id));
    final returnsState = ref.watch(purchaseReturnsProvider(id));
    return purchaseState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => PageContent(
        children: [
          const InlineNotice('Purchase could not be loaded.', isError: true),
          TextButton(
            onPressed: () => ref.invalidate(purchaseProvider(id)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (purchase) => SliverPageContent(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Purchase record'),
            const SizedBox(height: 10),
            Text(
              formatMoney(purchase.draft.totalMinor, purchase.draft.currency),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${purchase.draft.supplierName ?? 'No supplier'} · ${purchaseDate(purchase.createdAt)}',
            ),
            if (purchase.draft.supplierPhone?.isNotEmpty == true)
              Text(purchase.draft.supplierPhone!),
            const SizedBox(height: 16),
            InlineNotice(
              'Stock was added locally. Inventory cost now uses weighted average; selling prices do not change.',
            ),
          ],
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.separated(
              itemCount: purchase.draft.lines.length,
              separatorBuilder: (_, _) => const Divider(height: 28),
              itemBuilder: (context, index) {
                final line = purchase.draft.lines[index];
                final returned = purchase.returnedQuantity(line.sku);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${line.quantity} × ${formatMoney(line.unitCostMinor, purchase.draft.currency)}',
                    ),
                    Text(
                      'Received ${line.quantity - returned} · Returned $returned',
                    ),
                  ],
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Payment status · ${purchase.paymentStatus == PurchasePaymentStatus.paid ? 'Paid' : 'Unpaid'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (purchase.paymentStatus ==
                      PurchasePaymentStatus.unpaid) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _markPaid(context, ref, purchase),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('I paid the supplier · Mark paid'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed:
                        purchase.draft.lines.every(
                          (line) =>
                              purchase.returnedQuantity(line.sku) >=
                              line.quantity,
                        )
                        ? null
                        : () => _returnItems(context, ref, purchase),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Return items to supplier'),
                  ),
                  const SizedBox(height: 24),
                  const Eyebrow('Return history'),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: returnsState.when(
              loading: () =>
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
              error: (_, _) => const SliverToBoxAdapter(
                child: InlineNotice(
                  'Return history could not be loaded.',
                  isError: true,
                ),
              ),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Text('No returns recorded.'),
                    )
                  : SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final record = items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            formatMoney(
                              record.totalMinor,
                              purchase.draft.currency,
                            ),
                          ),
                          subtitle: Text(
                            '${record.reason} · ${purchaseDate(record.createdAt)}',
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

String purchaseDate(DateTime date) => saleDate(date);

class _ReturnDraft {
  const _ReturnDraft(this.quantities, this.reason);
  final Map<String, int> quantities;
  final String reason;
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.purchase});
  final Purchase purchase;
  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _reason = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final line in widget.purchase.draft.lines) {
      _quantities[line.sku] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final quantities = <String, int>{};
    try {
      for (final line in widget.purchase.draft.lines) {
        final quantity = parseUnits(_quantities[line.sku]!.text);
        if (quantity > 0) quantities[line.sku] = quantity;
      }
      if (quantities.isEmpty || _reason.text.trim().isEmpty) {
        setState(
          () => _error = 'Enter at least one quantity and a return reason.',
        );
        return;
      }
      Navigator.pop(context, _ReturnDraft(quantities, _reason.text.trim()));
    } on AppFailure catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Return purchase items'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in widget.purchase.draft.lines)
            TextField(
              controller: _quantities[line.sku],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    '${line.name} · max ${line.quantity - widget.purchase.returnedQuantity(line.sku)}',
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Reason for return'),
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
      FilledButton(onPressed: _submit, child: const Text('Record return')),
    ],
  );
}
