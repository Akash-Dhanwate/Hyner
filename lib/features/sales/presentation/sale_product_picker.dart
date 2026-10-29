import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/data/local_inventory_repository.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';

class SaleProductPicker extends ConsumerStatefulWidget {
  const SaleProductPicker({
    super.key,
    required this.uid,
    required this.selected,
    this.currency,
    this.allowOutOfStock = false,
  });
  final String uid;
  final Set<String> selected;
  final String? currency;
  final bool allowOutOfStock;
  @override
  ConsumerState<SaleProductPicker> createState() => _SaleProductPickerState();
}

class _SaleProductPickerState extends ConsumerState<SaleProductPicker> {
  final _search = TextEditingController();
  ProductSearch _searchBy = ProductSearch.name;
  InventoryQuery _query = const InventoryQuery();
  List<Product> _products = [];
  InventoryCursor? _next;
  AppFailure? _failure;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!mounted || ref.read(inventoryUidProvider) != widget.uid) return;
    if (more && (_loading || _next == null)) return;
    final generation = ++_generation;
    final cursor = more ? _next : null;
    if (!more) {
      _query = InventoryQuery(search: _search.text, searchBy: _searchBy);
    }
    setState(() {
      _loading = true;
      _failure = null;
      if (!more) {
        _products = [];
        _next = null;
      }
    });
    try {
      final page = await ref
          .read(inventoryRepositoryProvider)
          .list(widget.uid, _query, after: cursor);
      if (!mounted ||
          generation != _generation ||
          ref.read(inventoryUidProvider) != widget.uid) {
        return;
      }
      setState(() {
        _products = {
          for (final p in _products) p.sku: p,
          for (final p in page.products) p.sku: p,
        }.values.toList();
        _next = page.next;
        _loading = false;
      });
    } catch (error) {
      if (mounted &&
          generation == _generation &&
          ref.read(inventoryUidProvider) == widget.uid) {
        setState(() {
          _failure = AppFailure.from(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(inventoryUidProvider) != widget.uid) {
      return const SizedBox.shrink();
    }
    final repository = ref.watch(inventoryRepositoryProvider);
    final legacyImportFailed =
        repository is LocalInventoryRepository && repository.legacyImportFailed;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose product'),
          leading: IconButton(
            tooltip: 'Close product picker',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                children: [
                  DropdownButtonFormField<ProductSearch>(
                    initialValue: _searchBy,
                    decoration: const InputDecoration(labelText: 'Search by'),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: ProductSearch.name,
                        child: Text('Product name'),
                      ),
                      DropdownMenuItem(
                        value: ProductSearch.code,
                        child: Text('Product code'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _searchBy = value;
                        unawaited(_load());
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('sale-product-search'),
                    controller: _search,
                    maxLength: 120,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      labelText: 'Starts with…',
                      counterText: '',
                      suffixIcon: IconButton(
                        tooltip: 'Search products',
                        icon: const Icon(Icons.search_rounded),
                        onPressed: _load,
                      ),
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  if (legacyImportFailed) ...[
                    const InlineNotice(
                      'Older Firebase products could not be copied. Check your connection and inventory read rules, then retry.',
                      isError: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_failure != null) ...[
                    InlineNotice(_failure!.displayMessage, isError: true),
                    TextButton(
                      onPressed: () =>
                          _load(more: _products.isNotEmpty && _next != null),
                      child: const Text('Try again'),
                    ),
                  ],
                  if (!_loading && _failure == null && _products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No products found. Add products and stock in Inventory, or change your search.',
                      ),
                    ),
                  for (final product in _products) ...[
                    Builder(
                      builder: (context) {
                        final reason = widget.selected.contains(product.sku)
                            ? 'Already added'
                            : product.quantity == 0 && !widget.allowOutOfStock
                            ? 'Out of stock'
                            : widget.currency != null &&
                                  product.currency != widget.currency
                            ? 'Different currency'
                            : null;
                        return ListTile(
                          key: ValueKey('pick-${product.sku}'),
                          contentPadding: EdgeInsets.zero,
                          enabled: reason == null,
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.sku} · ${formatMoney(product.priceMinor, product.currency)}\n${reason ?? '${product.quantity} units available'}',
                          ),
                          isThreeLine: true,
                          trailing: reason == null
                              ? const Icon(Icons.add_rounded)
                              : null,
                          onTap: reason == null
                              ? () => Navigator.pop(context, product)
                              : null,
                        );
                      },
                    ),
                    const Divider(),
                  ],
                  if (_next != null && !_loading)
                    OutlinedButton(
                      onPressed: () => _load(more: true),
                      child: const Text('Load more products'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
