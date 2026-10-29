import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../domain/customer.dart';
import 'customers_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<CustomerDraft>(
      context: context,
      builder: (_) => const _CustomerDialog(),
    );
    if (draft == null || !context.mounted) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    try {
      await ref.read(customerRepositoryProvider).save(uid, draft);
      await LocalNotificationService.instance.activity(
        title: 'Customer added',
        body: 'A customer profile was saved to your register.',
      );
      if (!context.mounted) return;
      ref.invalidate(customersProvider);
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer details could not be saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final theme = Theme.of(context);
    return SliverPageContent(
      onRefresh: () => ref.refresh(customersProvider.future),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Saved on this device'),
          const SizedBox(height: 12),
          Text('Customers', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text('Customer names and contact details stay on this device.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('add-customer'),
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.person_add_alt_rounded),
            label: const Text('Add customer'),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: customers.when(
            loading: () =>
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (_, _) => const SliverToBoxAdapter(
              child: InlineNotice(
                'Customers could not be loaded.',
                isError: true,
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text('No customers saved yet.'),
                    ),
                  )
                : SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final customer = items[index];
                      final details = [
                        if (customer.phone.isNotEmpty) customer.phone,
                        if (customer.whatsappOptIn) 'WhatsApp updates allowed',
                        if (customer.notes.isNotEmpty) customer.notes,
                      ].join(' · ');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            customer.name.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(customer.name),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push<void>('/customers/${customer.id}'),
                        subtitle: Text(
                          details.isEmpty ? 'No extra details' : details,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();
  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _whatsappOptIn = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = CustomerDraft(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      notes: _notes.text.trim(),
      whatsappOptIn: _whatsappOptIn,
    );
    try {
      draft.validate();
      Navigator.of(context).pop(draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add customer'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Customer name'),
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _whatsappOptIn,
            onChanged: (value) =>
                setState(() => _whatsappOptIn = value == true),
            title: const Text('WhatsApp product updates allowed'),
            subtitle: const Text(
              'Only include customers who agreed to receive updates.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save customer')),
    ],
  );
}
