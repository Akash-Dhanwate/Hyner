import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import 'inventory_controller.dart';
import 'inventory_feedback.dart';
import 'stock_adjustment_dialog.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.sku});
  final String sku;
  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _busy = false;
  AppFailure? _failure;
  void _refresh() {
    ref.invalidate(inventoryProductProvider(widget.sku));
    unawaited(ref.read(inventoryProvider.notifier).refresh());
  }

  Future<void> _archive(Product product) async {
    if (_busy) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    if (!product.archived && product.quantity != 0) {
      setState(
        () => _failure = inventoryInvalid(
          'Stock must be zero before archiving. Record a stock adjustment first.',
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.archived ? 'Restore product?' : 'Archive product?'),
        content: Text(
          product.archived
              ? 'This product will return to the active catalogue.'
              : 'The product and its stock history will be kept in Archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(product.archived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        ref.read(inventoryUidProvider) != uid) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    final inventory = ref.read(inventoryProvider.notifier);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .setArchived(uid, product, !product.archived);
      inventory.didWrite(uid, product.sku);
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
    } catch (error) {
      if (mounted && ref.read(inventoryUidProvider) == uid) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adjust(Product product) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StockAdjustmentDialog(product: product),
    );
    if (mounted && changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: ref
        .watch(inventoryProductProvider(widget.sku))
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              InventoryFeedback(error: error, retry: _refresh),
          data: (product) => _ProductDetails(
            key: ValueKey(
              '${ref.watch(inventoryUidProvider)}/${product.sku}/${product.revision}',
            ),
            product: product,
            busy: _busy,
            failure: _failure,
            refresh: _refresh,
            archive: () => _archive(product),
            adjust: () => _adjust(product),
          ),
        ),
  );
}

class _ProductDetails extends ConsumerStatefulWidget {
  const _ProductDetails({
    super.key,
    required this.product,
    required this.busy,
    required this.failure,
    required this.refresh,
    required this.archive,
    required this.adjust,
  });
  final Product product;
  final bool busy;
  final AppFailure? failure;
  final VoidCallback refresh, archive, adjust;
  @override
  ConsumerState<_ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends ConsumerState<_ProductDetails> {
  final List<StockMovement> _movements = [];
  MovementCursor? _next;
  bool _loading = true;
  bool _fetching = false;
  AppFailure? _historyFailure;
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => _load());
  }

  Future<void> _load() async {
    if (!mounted || _fetching) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    _fetching = true;
    setState(() {
      _loading = true;
      _historyFailure = null;
    });
    try {
      final page = await ref
          .read(inventoryRepositoryProvider)
          .movements(uid, widget.product.sku, after: _next);
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      setState(() {
        _movements.addAll(page.movements);
        _next = page.next;
        _loading = false;
        _fetching = false;
      });
    } catch (error) {
      if (mounted && ref.read(inventoryUidProvider) == uid) {
        setState(() {
          _loading = false;
          _historyFailure = AppFailure.from(error);
          _fetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: RefreshIndicator(
            onRefresh: () async => widget.refresh(),
            child: ListView.builder(
              key: const Key('product-details-scroll'),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              itemCount: _movements.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Eyebrow('Product details'),
                          IconButton(
                            tooltip: 'Refresh product',
                            onPressed: widget.busy ? null : widget.refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(p.name, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(p.sku, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 24),
                      Text(
                        '${p.quantity} units',
                        style: theme.textTheme.headlineMedium,
                      ),
                      if (p.archived)
                        const Text('Archived')
                      else if (p.isLowStock)
                        Text(
                          p.quantity == 0 ? 'Out of stock' : 'Low stock',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (!p.archived) ...[
                            FilledButton.icon(
                              key: const Key('adjust-stock'),
                              onPressed: widget.busy ? null : widget.adjust,
                              icon: const Icon(Icons.swap_vert_rounded),
                              label: const Text('Adjust stock'),
                            ),
                            OutlinedButton(
                              onPressed: widget.busy
                                  ? null
                                  : () => context.push<void>(
                                      '/inventory/${p.sku}/edit',
                                    ),
                              child: const Text('Edit product'),
                            ),
                          ],
                          OutlinedButton(
                            onPressed: widget.busy ? null : widget.archive,
                            child: Text(
                              p.archived
                                  ? 'Restore product'
                                  : 'Archive product',
                            ),
                          ),
                        ],
                      ),
                      if (widget.busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(),
                        ),
                      if (widget.failure != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: InlineNotice(
                            widget.failure!.displayMessage,
                            isError: true,
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      fact(
                        'Category',
                        p.category.isEmpty ? 'Not set' : p.category,
                      ),
                      for (final parameter in p.parameters)
                        fact(parameter.name, parameter.value),
                      fact(
                        'Cost price / unit',
                        formatMoney(p.costMinor, p.currency),
                      ),
                      fact(
                        'Selling price / unit',
                        formatMoney(p.priceMinor, p.currency),
                      ),
                      fact('Low-stock threshold', '${p.reorderLevel} units'),
                      fact(
                        'Added',
                        localizations.formatFullDate(p.createdAt.toLocal()),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 24),
                      Text('Stock history', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Opening stock, adjustments, purchases, returns and sales.',
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                if (index == _movements.length + 1) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_historyFailure != null) ...[
                        InlineNotice(
                          _historyFailure!.displayMessage,
                          isError: true,
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry history'),
                        ),
                      ],
                      if (_loading)
                        const CircularProgressIndicator()
                      else if (_next != null)
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Load more history'),
                        ),
                      if (!_loading &&
                          _historyFailure == null &&
                          _movements.isEmpty)
                        const Text('No stock movements found.'),
                    ],
                  );
                }
                final m = _movements[index - 1];
                final date = m.createdAt.toLocal();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 14),
                    Text(
                      '${m.delta > 0 ? '+' : ''}${m.delta} units · ${m.beforeQuantity} → ${m.afterQuantity}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(m.reason),
                    const SizedBox(height: 6),
                    Text(
                      '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
