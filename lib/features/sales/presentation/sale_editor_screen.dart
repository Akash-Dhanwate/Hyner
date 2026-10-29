import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/sale.dart';
import 'sale_product_picker.dart';
import 'sales_controller.dart';

class SaleEditorScreen extends ConsumerWidget {
  const SaleEditorScreen({super.key, this.embedded = false, this.customerId});
  final bool embedded;
  final String? customerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(inventoryUidProvider);
    return uid == null
        ? const SizedBox.shrink()
        : _SaleForm(
            key: ValueKey(uid),
            uid: uid,
            embedded: embedded,
            initialCustomerId: customerId,
          );
  }
}

class _SaleForm extends ConsumerStatefulWidget {
  const _SaleForm({
    super.key,
    required this.uid,
    required this.embedded,
    this.initialCustomerId,
  });
  final String uid;
  final bool embedded;
  final String? initialCustomerId;
  @override
  ConsumerState<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends ConsumerState<_SaleForm> {
  final _form = GlobalKey<FormState>();
  final _products = <Product>[];
  final _quantities = <String, TextEditingController>{};
  final _prices = <String, TextEditingController>{};
  final _parameters = <String, List<_ParameterFields>>{};
  final _advanceAmount = TextEditingController();
  Customer? _customer;
  bool _advancePayment = false;
  bool _saving = false, _uncertain = false, _allowPop = false, _asking = false;
  String? _id;
  SaleDraft? _submitted;
  AppFailure? _failure;
  bool get _current => mounted && ref.read(inventoryUidProvider) == widget.uid;
  @override
  void initState() {
    super.initState();
    final customerId = widget.initialCustomerId;
    if (customerId != null) {
      unawaited(_loadInitialCustomer(customerId));
    }
  }

  Future<void> _loadInitialCustomer(String id) async {
    try {
      final customers = await ref.read(customersProvider.future);
      if (!_current) return;
      final match = customers
          .where((customer) => customer.id == id)
          .firstOrNull;
      if (match != null) setState(() => _customer = match);
    } catch (_) {
      // The customer can still be selected manually if its local record is unavailable.
    }
  }

  @override
  void dispose() {
    for (final c in [
      ..._quantities.values,
      ..._prices.values,
      _advanceAmount,
    ]) {
      c.dispose();
    }
    for (final row in _parameters.values) {
      for (final parameter in row) {
        parameter.dispose();
      }
    }
    super.dispose();
  }

  SaleDraft _draft() {
    final lines = [
      for (final p in _products)
        SaleLine.fromProduct(
          p,
          parseUnits(_quantities[p.sku]!.text, allowZero: false),
          unitPriceMinor: parseMoney(_prices[p.sku]!.text),
          parameters: [
            for (final parameter in _parameters[p.sku] ?? const [])
              ProductParameter(
                name: parameter.name.text.trim(),
                value: parameter.value.text.trim(),
              ),
          ],
        ),
    ];
    final total = lines.fold<int>(0, (sum, line) => sum + line.totalMinor);
    return SaleDraft(
      currency: _products.first.currency,
      customerId: _customer?.id,
      customerName: _customer?.name,
      customerPhone: _customer?.phone,
      initialPaymentMinor: _advancePayment
          ? parseMoney(_advanceAmount.text)
          : total,
      lines: lines,
    )..validate();
  }

  void _addParameter(String sku) {
    setState(() {
      _parameters[sku]!.add(_ParameterFields('', ''));
    });
  }

  Future<void> _add() async {
    if (_saving || _uncertain) return;
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => SaleProductPicker(
        uid: widget.uid,
        selected: _products.map((p) => p.sku).toSet(),
        currency: _products.firstOrNull?.currency,
      ),
    );
    if (!_current || product == null) return;
    setState(() {
      _products.add(product);
      _quantities[product.sku] = TextEditingController(text: '1');
      _prices[product.sku] = TextEditingController(
        text: moneyDecimal(product.priceMinor),
      );
      _parameters[product.sku] = [
        for (final parameter in product.parameters)
          _ParameterFields(parameter.name, parameter.value),
      ];
      _failure = null;
    });
  }

  Future<void> _leave() async {
    if (_saving || _asking) return;
    _asking = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _uncertain ? 'Leave before checking the sale?' : 'Discard this bill?',
        ),
        content: Text(
          _uncertain
              ? 'The sale may already be saved. Check Sales for reference $_id before creating another bill. This retry is not kept after leaving.'
              : 'Your unsaved bill will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!_current || leave != true) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _current) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_current || _products.isEmpty) return;
    if (!_uncertain && !_form.currentState!.validate()) return;
    try {
      final draft = _uncertain ? _submitted! : _draft();
      final repository = ref.read(salesRepositoryProvider);
      _id ??= repository.newSaleId();
      _submitted = draft;
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
          title: 'Sale recorded',
          body:
              '${draft.units} units · ${formatMoney(draft.totalMinor, draft.currency)}',
        ),
      );
      ref.invalidate(saleProvider(_id!));
      unawaited(ref.read(salesProvider.notifier).refresh());
      unawaited(ref.read(inventoryProvider.notifier).refresh());
      for (final line in draft.lines) {
        ref.invalidate(inventoryProductProvider(line.sku));
      }
      setState(() {
        _saving = false;
        _allowPop = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _current) context.replace('/sales/$_id');
    } catch (error) {
      if (!_current) return;
      final failure = AppFailure.from(error);
      setState(() {
        _saving = false;
        _failure = failure;
        _uncertain =
            _uncertain ||
            failure.kind == FailureKind.network ||
            failure.kind == FailureKind.unknown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_saving && !_uncertain;
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    SaleDraft? preview;
    if (_products.isNotEmpty) {
      try {
        preview = _draft();
      } catch (_) {
        /* Form shows invalid quantities. */
      }
    }
    return PopScope(
      canPop: !_saving && (_allowPop || _products.isEmpty),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                title: const Text('Build a bill'),
                actions: [
                  IconButton(
                    tooltip: 'Saved bills',
                    onPressed: () => context.push<void>('/sales/history'),
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
              ),
        body: PageContent(
          children: [
            const Eyebrow('Bill details'),
            const SizedBox(height: 12),
            Text(
              'Build a bill',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Add multiple in-stock products to one bill. Set a separate bill price for each; Inventory selling prices stay unchanged.',
            ),
            if (widget.embedded) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push<void>('/sales/history'),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Saved bills'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _customer?.id,
                    decoration: const InputDecoration(
                      labelText: 'Customer (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Walk-in customer'),
                      ),
                      for (final customer in customers)
                        DropdownMenuItem<String?>(
                          value: customer.id,
                          child: Text(
                            customer.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: enabled
                        ? (id) => setState(() {
                            _customer = id == null
                                ? null
                                : customers
                                      .where((c) => c.id == id)
                                      .firstOrNull;
                          })
                        : null,
                  ),
                  if (customers.isEmpty) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.push<void>('/customers'),
                        icon: const Icon(
                          Icons.person_add_alt_rounded,
                          size: 18,
                        ),
                        label: const Text('Add a customer'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                                  _prices.remove(product.sku)?.dispose();
                                  for (final parameter
                                      in _parameters.remove(product.sku) ??
                                          []) {
                                    parameter.dispose();
                                  }
                                  _failure = null;
                                })
                              : null,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      '${product.sku} · Inventory price ${formatMoney(product.priceMinor, product.currency)}',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('sale-price-${product.sku}'),
                      controller: _prices[product.sku],
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Bill price (${product.currency})',
                        helperText: 'This bill only. Inventory selling price stays unchanged.',
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: enabled
                            ? () => setState(() {
                                _prices[product.sku]!.text = moneyDecimal(
                                  product.priceMinor,
                                );
                              })
                            : null,
                        child: const Text('Use inventory price'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('sale-quantity-${product.sku}'),
                      controller: _quantities[product.sku],
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        helperText:
                            '${product.quantity} units available when selected',
                      ),
                      validator: (value) {
                        try {
                          final units = parseUnits(
                            value ?? '',
                            allowZero: false,
                          );
                          if (units > product.quantity) {
                            return 'Only ${product.quantity} units available.';
                          }
                          SaleLine.fromProduct(
                            product,
                            units,
                            unitPriceMinor: parseMoney(
                              _prices[product.sku]!.text,
                            ),
                          ).validate();
                          return null;
                        } on AppFailure catch (error) {
                          return error.message;
                        }
                      },
                    ),
                    if ((_parameters[product.sku] ?? []).isNotEmpty ||
                        product.parameters.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Bill parameters',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                    for (
                      var index = 0;
                      index < (_parameters[product.sku]?.length ?? 0);
                      index++
                    ) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _parameters[product.sku]![index].name,
                              enabled: enabled,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                labelText: 'Parameter',
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller:
                                  _parameters[product.sku]![index].value,
                              enabled: enabled,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                labelText: 'Value',
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove bill parameter',
                            onPressed: enabled
                                ? () => setState(() {
                                    _parameters[product.sku]![index].dispose();
                                    _parameters[product.sku]!.removeAt(index);
                                  })
                                : null,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                    if ((_parameters[product.sku]?.length ?? 0) < 20)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: enabled
                              ? () => _addParameter(product.sku)
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add bill parameter'),
                        ),
                      ),
                    const Divider(height: 32),
                  ],
                  if (_products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text('No products added yet.'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('add-sale-product'),
                    onPressed: enabled ? _add : null,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Add product (${_products.length} added)'),
                  ),
                  const SizedBox(height: 28),
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    preview == null
                        ? (_products.isEmpty
                              ? '—'
                              : 'Check prices and quantities')
                        : formatMoney(preview.totalMinor, preview.currency),
                    key: const Key('sale-total'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Payment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Pay in full'),
                        icon: Icon(Icons.check_circle_outline_rounded),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Advance'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {_advancePayment},
                    onSelectionChanged: enabled
                        ? (selection) =>
                              setState(() => _advancePayment = selection.first)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _advancePayment
                        ? 'Create a QR for the amount collected now.'
                        : 'Create a QR for the full bill total.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_advancePayment) ...[
                    TextFormField(
                      key: const Key('sale-advance-amount'),
                      controller: _advanceAmount,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText:
                            'Advance amount (${_products.first.currency})',
                        helperText: 'The amount can be changed again before each payment is recorded.',
                      ),
                      validator: (value) {
                        try {
                          final amount = parseMoney(value ?? '');
                          final total = preview?.totalMinor;
                          if (total == null || amount < 1 || amount > total) {
                            return 'Enter an amount greater than zero and no more than the bill total.';
                          }
                          return null;
                        } on AppFailure catch (error) {
                          return error.message;
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Saving the bill deducts stock. The next screen shows a QR for your selected full or advance amount. The owner records payment after checking it in the payment app.',
                  ),
                  const SizedBox(height: 20),
                  if (_failure != null) ...[
                    InlineNotice(_failure!.displayMessage, isError: true),
                    const SizedBox(height: 12),
                  ],
                  if (_uncertain) ...[
                    InlineNotice(
                      'The save result is not confirmed. Retry this same bill to avoid a duplicate. Reference: $_id',
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    key: const Key('save-sale'),
                    onPressed: _saving || _products.isEmpty ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : _uncertain
                          ? 'Check and retry sale'
                          : 'Save bill and continue',
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
