import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../domain/product.dart';
import 'inventory_controller.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  const StockAdjustmentDialog({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _form = GlobalKey<FormState>();
  final _units = TextEditingController();
  final _reason = TextEditingController();
  bool _add = true, _saving = false, _uncertain = false;
  String? _operation;
  int? _submittedDelta;
  String? _submittedReason;
  AppFailure? _failure;
  @override
  void dispose() {
    _units.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || (!_uncertain && !_form.currentState!.validate())) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final delta = _uncertain
        ? _submittedDelta!
        : parseUnits(_units.text, allowZero: false) * (_add ? 1 : -1);
    final reason = _uncertain ? _submittedReason! : _reason.text.trim();
    if (widget.product.quantity + delta < 0 ||
        widget.product.quantity + delta > maxStock) {
      setState(
        () => _failure = inventoryInvalid(
          'The resulting stock must be between 0 and 1,000,000,000 units.',
        ),
      );
      return;
    }
    _submittedDelta = delta;
    _submittedReason = reason;
    final repository = ref.read(inventoryRepositoryProvider);
    final inventory = ref.read(inventoryProvider.notifier);
    _operation ??= repository.newOperationId();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await repository.adjust(uid, widget.product, delta, reason, _operation!);
      inventory.didWrite(uid, widget.product.sku, refreshProduct: false);
      await LocalNotificationService.instance.activity(
        title: 'Stock adjusted',
        body: '${widget.product.name} · ${delta > 0 ? '+' : ''}$delta units',
      );
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_uncertain,
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      title: const Text('Adjust stock'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.product.name}\nCurrent stock: ${widget.product.quantity} units',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<bool>(
                  isExpanded: true,
                  initialValue: _add,
                  decoration: const InputDecoration(labelText: 'Adjustment'),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Add units')),
                    DropdownMenuItem(value: false, child: Text('Remove units')),
                  ],
                  onChanged: _saving || _uncertain
                      ? null
                      : (value) => setState(() => _add = value ?? true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('adjustment-units'),
                  controller: _units,
                  enabled: !_saving && !_uncertain,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Units'),
                  validator: (value) {
                    try {
                      parseUnits(value ?? '', allowZero: false);
                      return null;
                    } on AppFailure catch (error) {
                      return error.message;
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('adjustment-reason'),
                  controller: _reason,
                  enabled: !_saving && !_uncertain,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLength: 200,
                  minLines: 2,
                  maxLines: 4,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Explain why the stock is changing.'
                      : null,
                ),
                if (_failure != null)
                  InlineNotice(_failure!.displayMessage, isError: true),
                if (_uncertain)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: InlineNotice(
                      'The result is not confirmed. Retry this same change. If you leave, check stock history before another adjustment.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(_uncertain),
          child: Text(_uncertain ? 'Close and check history' : 'Cancel'),
        ),
        FilledButton(
          key: const Key('save-adjustment'),
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Saving…'
                : _uncertain
                ? 'Check and retry'
                : 'Save adjustment',
          ),
        ),
      ],
    ),
  );
}
