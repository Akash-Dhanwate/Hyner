import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/presentation/sale_product_picker.dart';
import '../domain/purchase.dart';
import 'purchases_controller.dart';

class PurchaseEditorScreen extends ConsumerWidget {
  const PurchaseEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(inventoryUidProvider);
    return uid == null
        ? const SizedBox.shrink()
        : _PurchaseForm(key: ValueKey(uid), uid: uid);
  }
}

class _PurchaseForm extends ConsumerStatefulWidget {
  const _PurchaseForm({super.key, required this.uid});
  final String uid;
  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  final _form = GlobalKey<FormState>();
  final _products = <Product>[];
  final _quantities = <String, TextEditingController>{};
  final _costs = <String, TextEditingController>{};
  Supplier? _supplier;
  bool _saving = false;
  String? _id;
  AppFailure? _failure;

  @override
  void dispose() {
    for (final controller in [..._quantities.values, ..._costs.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _current => mounted && ref.read(inventoryUidProvider) == widget.uid;

  PurchaseDraft _draft() => PurchaseDraft(
    currency: _products.first.currency,
    supplierId: _supplier?.id,
    supplierName: _supplier?.name,
    supplierPhone: _supplier?.phone,
    lines: [
      for (final product in _products)
        PurchaseLine(
          sku: product.sku,
          name: product.name,
          quantity: parseUnits(
            _quantities[product.sku]!.text,
            allowZero: false,
          ),
          unitCostMinor: parseMoney(_costs[product.sku]!.text),
        ),
    ],
  )..validate();

  Future<void> _add() async {
    if (_saving) return;
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => SaleProductPicker(
        uid: widget.uid,
        selected: _products.map((product) => product.sku).toSet(),
        currency: _products.firstOrNull?.currency,
        allowOutOfStock: true,
      ),
    );
    if (!_current || product == null) return;
    setState(() {
      _products.add(product);
      _quantities[product.sku] = TextEditingController(text: '1');
      _costs[product.sku] = TextEditingController(
        text: moneyDecimal(product.costMinor),
      );
      _failure = null;
    });
  }

  Future<void> _save() async {
    if (_saving ||
        !_current ||
        _products.isEmpty ||
        !_form.currentState!.validate()) {
      return;
    }
    try {
      final draft = _draft();
      final repository = ref.read(purchaseRepositoryProvider);
      _id ??= repository.newId();
      setState(() {
        _saving = true;
        _failure = null;
      });
      await repository.create(widget.uid, _id!, draft);
      if (!_current) return;
      for (final line in draft.lines) {
        ref.read(inventoryProvider.notifier).checkStock(widget.uid, line.sku);
      }
      unawaited(
        LocalNotificationService.instance.activity(
          title: 'Purchase recorded',
          body: '${draft.lines.length} products · stock updated',
        ),
      );
      ref.invalidate(purchasesProvider);
      ref.invalidate(inventoryProvider);
      for (final line in draft.lines) {
        ref.invalidate(inventoryProductProvider(line.sku));
      }
      if (mounted) context.replace('/purchases/$_id');
    } catch (error) {
      if (!_current) return;
      setState(() {
        _saving = false;
        _failure = AppFailure.from(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    PurchaseDraft? preview;
    if (_products.isNotEmpty) {
      try {
        preview = _draft();
      } catch (_) {}
    }
    final enabled = !_saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Record purchase')),
      body: PageContent(
        children: [
          const Eyebrow('Incoming stock'),
          const SizedBox(height: 12),
          Text(
            'Record purchase',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Save supplier quantities and unit costs. Stock and weighted-average cost update together; selling prices stay unchanged.',
          ),
          const SizedBox(height: 20),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _supplier?.id,
                  decoration: const InputDecoration(
                    labelText: 'Supplier (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No supplier'),
                    ),
                    for (final supplier in suppliers)
                      DropdownMenuItem<String?>(
                        value: supplier.id,
                        child: Text(
                          supplier.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: enabled
                      ? (id) => setState(
                          () => _supplier = id == null
                              ? null
                              : suppliers
                                    .where((item) => item.id == id)
                                    .firstOrNull,
                        )
                      : null,
                ),
                if (suppliers.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push<void>('/purchases'),
                      icon: const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 18,
                      ),
                      label: const Text('Manage suppliers'),
                    ),
                  ),
                const SizedBox(height: 16),
                for (final product in _products) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove ${product.sku}',
                        onPressed: enabled
                            ? () => setState(() {
                                _products.remove(product);
                                _quantities.remove(product.sku)?.dispose();
                                _costs.remove(product.sku)?.dispose();
                              })
                            : null,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    '${product.sku} · Current stock ${product.quantity} · Current cost ${formatMoney(product.costMinor, product.currency)}',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _costs[product.sku],
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Purchase unit cost',
                    ),
                    validator: (value) {
                      try {
                        parseMoney(value ?? '');
                        return null;
                      } on AppFailure catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  TextFormField(
                    controller: _quantities[product.sku],
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Units received',
                    ),
                    validator: (value) {
                      try {
                        parseUnits(value ?? '', allowZero: false);
                        return null;
                      } on AppFailure catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  const Divider(height: 32),
                ],
                if (_products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('No products added yet.'),
                  ),
                OutlinedButton.icon(
                  key: const Key('add-purchase-product'),
                  onPressed: enabled ? _add : null,
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Add product (${_products.length} added)'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Purchase total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  preview == null
                      ? '—'
                      : formatMoney(preview.totalMinor, preview.currency),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (_failure != null) ...[
                  const SizedBox(height: 16),
                  InlineNotice(_failure!.displayMessage, isError: true),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('save-purchase'),
                  onPressed: enabled && _products.isNotEmpty ? _save : null,
                  child: Text(
                    _saving ? 'Saving…' : 'Save purchase and update stock',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
