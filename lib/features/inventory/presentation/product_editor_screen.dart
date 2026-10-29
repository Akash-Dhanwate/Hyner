import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../domain/product.dart';
import 'inventory_controller.dart';
import 'inventory_feedback.dart';

class ProductEditorScreen extends ConsumerWidget {
  const ProductEditorScreen({super.key, this.sku});
  final String? sku;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sku == null) return const _ProductForm();
    return ref
        .watch(inventoryProductProvider(sku!))
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (product) => _ProductForm(
            key: ValueKey('${product.sku}/${product.revision}'),
            product: product,
          ),
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Edit product')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppBar(title: const Text('Edit product')),
            body: InventoryFeedback(
              error: error,
              retry: () => ref.invalidate(inventoryProductProvider(sku!)),
            ),
          ),
        );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({super.key, this.product});
  final Product? product;
  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _sku,
      _name,
      _category,
      _cost,
      _price,
      _opening,
      _threshold;
  final List<_ParameterFields> _parameters = [];
  late String _currency;
  String? _operation;
  ProductDraft? _submitted;
  bool _dirty = false,
      _saving = false,
      _allowPop = false,
      _asking = false,
      _uncertain = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _sku = TextEditingController(text: product?.sku ?? '');
    _name = TextEditingController(text: product?.name ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _cost = TextEditingController(text: moneyDecimal(product?.costMinor ?? 0));
    _price = TextEditingController(
      text: moneyDecimal(product?.priceMinor ?? 0),
    );
    _opening = TextEditingController(text: '${product?.quantity ?? 0}');
    _threshold = TextEditingController(text: '${product?.reorderLevel ?? 0}');
    _currency = product?.currency ?? 'INR';
    for (final parameter in product?.parameters ?? const <ProductParameter>[]) {
      _parameters.add(_ParameterFields(parameter.name, parameter.value));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _sku,
      _name,
      _category,
      _cost,
      _price,
      _opening,
      _threshold,
      ..._parameters.expand((parameter) => [parameter.name, parameter.value]),
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pop({String? savedSku}) async {
    setState(() {
      _allowPop = true;
      _dirty = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (savedSku != null) ref.invalidate(inventoryProductProvider(savedSku));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inventory');
    }
  }

  Future<void> _tryLeave() async {
    if (_saving || _asking) return;
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _uncertain ? 'Leave before checking the save?' : 'Discard changes?',
        ),
        content: Text(
          _uncertain
              ? 'The save result is not confirmed. Check inventory and stock history before adding this product again.'
              : 'Your unsaved product changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    _asking = false;
    if (mounted && discard == true) await _pop();
  }

  String? _number(String? value, {bool money = false}) {
    try {
      if (money) {
        parseMoney(value ?? '');
      } else {
        parseUnits(value ?? '');
      }
      return null;
    } on AppFailure catch (error) {
      return error.message;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_uncertain && !_form.currentState!.validate()) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    try {
      final draft = _uncertain
          ? _submitted!
          : ProductDraft(
              sku: normalizeSku(_sku.text),
              name: _name.text.trim(),
              category: _category.text.trim(),
              currency: _currency,
              costMinor: parseMoney(_cost.text),
              priceMinor: parseMoney(_price.text),
              openingStock: parseUnits(_opening.text),
              reorderLevel: parseUnits(_threshold.text),
              parameters: [
                for (final parameter in _parameters)
                  ProductParameter(
                    name: parameter.name.text.trim(),
                    value: parameter.value.text.trim(),
                  ),
              ],
            );
      draft.validate();
      _submitted = draft;
      final repository = ref.read(inventoryRepositoryProvider);
      final inventory = ref.read(inventoryProvider.notifier);
      _operation ??= repository.newOperationId();
      setState(() {
        _saving = true;
        _failure = null;
      });
      if (widget.product == null) {
        await repository.create(uid, draft, _operation!);
      } else {
        await repository.update(uid, draft, widget.product!.revision);
      }
      inventory.didWrite(uid, draft.sku, refreshProduct: false);
      unawaited(
        LocalNotificationService.instance.activity(
          title: widget.product == null ? 'Product added' : 'Product updated',
          body:
              '${draft.name} · stock ${draft.openingStock} · reorder at ${draft.reorderLevel}',
        ),
      );
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      setState(() {
        _saving = false;
        _failure = null;
        _dirty = false;
      });
      await _pop(savedSku: draft.sku);
    } catch (error) {
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      final failure = AppFailure.from(error);
      setState(() {
        _saving = false;
        _failure = failure;
        _uncertain = _uncertain || failure.kind == FailureKind.network;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final enabled = !_saving && !_uncertain && product?.archived != true;
    return PopScope(
      canPop: !_saving && ((!_dirty && !_uncertain) || _allowPop),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_tryLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(product == null ? 'Add product' : 'Edit product'),
        ),
        body: PageContent(
          children: [
            Text(
              product == null ? 'Product details' : product.sku,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Whole units. Prices are per unit in the selected currency.',
            ),
            if (product?.archived == true) ...[
              const SizedBox(height: 16),
              const InlineNotice('Restore this product before editing it.'),
            ],
            const SizedBox(height: 24),
            Form(
              key: _form,
              onChanged: () {
                if (!_dirty && mounted) setState(() => _dirty = true);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('product-code'),
                    controller: _sku,
                    enabled: enabled && product == null,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Product code',
                      helperText: 'Unique code; cannot be changed later.',
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$')
                            .hasMatch(normalizeSku(value ?? ''))
                        ? null
                        : 'Use letters, numbers, hyphens or underscores.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('product-name'),
                    controller: _name,
                    enabled: enabled,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the product name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('product-category'),
                    controller: _category,
                    enabled: enabled,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Custom parameters',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add sizes, materials, ratings or any details. Include units in the value, such as 34 inches or 12 mm.',
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _parameters.length; index++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _parameters[index].name,
                                enabled: enabled,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  labelText: 'Parameter name',
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _parameters[index].value,
                                enabled: enabled,
                                maxLength: 120,
                                decoration: const InputDecoration(
                                  labelText: 'Value',
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove parameter',
                          onPressed: enabled
                              ? () => setState(() {
                                  _parameters.removeAt(index).dispose();
                                  _dirty = true;
                                })
                              : null,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_parameters.length < 20)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: enabled
                            ? () => setState(() {
                                _parameters.add(_ParameterFields('', ''));
                                _dirty = true;
                              })
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add parameter'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: const Key('product-currency'),
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: [
                      for (final currency in inventoryCurrencies)
                        DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ),
                    ],
                    onChanged: enabled && product == null
                        ? (value) {
                            if (value != null) {
                              setState(() {
                                _currency = value;
                                _dirty = true;
                              });
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('product-cost'),
                    controller: _cost,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cost price ($_currency)',
                    ),
                    validator: (value) => _number(value, money: true),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('product-price'),
                    controller: _price,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Selling price ($_currency)',
                    ),
                    validator: (value) => _number(value, money: true),
                  ),
                  if (product == null) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('product-opening'),
                      controller: _opening,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Opening stock (units)',
                      ),
                      validator: _number,
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('product-threshold'),
                    controller: _threshold,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low-stock threshold (units)',
                    ),
                    validator: _number,
                  ),
                  const SizedBox(height: 24),
                  if (_failure != null) ...[
                    InlineNotice(_failure!.displayMessage, isError: true),
                    const SizedBox(height: 12),
                    if (product != null && !_uncertain)
                      TextButton(
                        onPressed: () => ref.invalidate(
                          inventoryProductProvider(product.sku),
                        ),
                        child: const Text(
                          'Reload saved product (discard edits)',
                        ),
                      ),
                  ],
                  if (_uncertain) ...[
                    const InlineNotice(
                      'The result is not confirmed. Retry the same save, or check inventory before making another change.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    key: const Key('save-product'),
                    onPressed: _saving || product?.archived == true
                        ? null
                        : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : _uncertain
                          ? 'Check and retry save'
                          : 'Save product',
                    ),
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

class _ParameterFields {
  _ParameterFields(String name, String value)
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}
