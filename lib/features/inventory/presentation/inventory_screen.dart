import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../data/local_inventory_repository.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import 'inventory_controller.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final theme = Theme.of(context);
    final controller = ref.read(inventoryProvider.notifier);
    final repository = ref.watch(inventoryRepositoryProvider);
    final legacyImportFailed =
        repository is LocalInventoryRepository && repository.legacyImportFailed;
    void search() => controller.refresh(
      query: InventoryQuery(
        archived: state.query.archived,
        search: _search.text,
        searchBy: state.query.searchBy,
      ),
    );
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
                        const Eyebrow('Product catalogue'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 20,
                          runSpacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Inventory',
                              style: theme.textTheme.headlineMedium,
                            ),
                            FilledButton.icon(
                              key: const Key('add-product'),
                              onPressed: () =>
                                  context.push<void>('/inventory/add'),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add product'),
                            ),
                            IconButton(
                              tooltip: 'Refresh inventory',
                              onPressed: state.loading
                                  ? null
                                  : controller.refresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Products and stock, saved on this device.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (legacyImportFailed) ...[
                          const SizedBox(height: 12),
                          const InlineNotice(
                            'Some older products could not be copied from Firebase. Check your connection and published inventory read rules, then refresh. New products are still saved on this device.',
                            isError: true,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final archived in [false, true])
                              ChoiceChip(
                                label: Text(archived ? 'Archived' : 'Active'),
                                selected: state.query.archived == archived,
                                onSelected: (_) => controller.refresh(
                                  query: InventoryQuery(
                                    archived: archived,
                                    search: _search.text,
                                    searchBy: state.query.searchBy,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ProductSearch>(
                          isExpanded: true,
                          initialValue: state.query.searchBy,
                          decoration: const InputDecoration(
                            labelText: 'Search by',
                          ),
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
                              controller.refresh(
                                query: InventoryQuery(
                                  archived: state.query.archived,
                                  search: _search.text,
                                  searchBy: value,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('inventory-search'),
                          controller: _search,
                          maxLength: 120,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => search(),
                          decoration: InputDecoration(
                            labelText: 'Starts with…',
                            counterText: '',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Search inventory',
                              onPressed: search,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.loading) const LinearProgressIndicator(),
                        if (state.failure != null) ...[
                          InlineNotice(
                            state.failure!.displayMessage,
                            isError: true,
                          ),
                          TextButton(
                            onPressed: state.loadingMore
                                ? null
                                : state.products.isEmpty
                                ? controller.refresh
                                : controller.loadMore,
                            child: const Text('Try again'),
                          ),
                        ],
                        if (!state.loading &&
                            state.failure == null &&
                            state.products.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  state.query.search.isNotEmpty
                                      ? 'No matching products'
                                      : state.query.archived
                                      ? 'No archived products'
                                      : 'No products yet',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state.query.search.isNotEmpty
                                      ? 'Try a different name or product code.'
                                      : state.query.archived
                                      ? 'Archived products will remain here with their stock history.'
                                      : 'Add your first product and its opening stock.',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: state.products.length,
                    separatorBuilder: (_, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final product = state.products[index];
                      return InkWell(
                        key: ValueKey('product-${product.sku}'),
                        onTap: () =>
                            context.push<void>('/inventory/${product.sku}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${product.sku}${product.category.isEmpty ? '' : ' · ${product.category}'}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    '${product.quantity} units',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  Text(
                                    formatMoney(
                                      product.priceMinor,
                                      product.currency,
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (product.isLowStock)
                                    Text(
                                      product.quantity == 0
                                          ? 'Out of stock'
                                          : 'Low stock',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                    ),
                                ],
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
                              child: const Text('Load more products'),
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
