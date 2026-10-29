import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sales_controller.dart';

const _whatsAppChannel = MethodChannel('hyner/whatsapp');

final whatsAppProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) return const [];
  final repository = ref.watch(inventoryRepositoryProvider);
  final products = <Product>[];
  InventoryCursor? cursor;
  do {
    final page = await repository.list(
      uid,
      const InventoryQuery(),
      after: cursor,
    );
    products.addAll(page.products.where((product) => !product.archived));
    cursor = page.next;
  } while (cursor != null);
  return products;
});

class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen> {
  final _message = TextEditingController();
  final _videoLink = TextEditingController();
  final _selectedCustomers = <String>{};
  String? _selectedSku;
  List<Customer> _campaignQueue = const [];
  String _campaignMessage = '';
  int _queueIndex = 0;
  bool _customSelection = false;
  bool _opening = false;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void dispose() {
    _message.dispose();
    _videoLink.dispose();
    super.dispose();
  }

  Set<String> _recipientIds(List<Customer> customers) => _customSelection
      ? _selectedCustomers
      : customers
            .where(
              (customer) => customer.whatsappOptIn && customer.phone.isNotEmpty,
            )
            .map((customer) => customer.id)
            .toSet();

  String _makeMessage(Product? product) {
    final body = _message.text.trim();
    final lines = <String>[];
    if (body.isNotEmpty) {
      lines.add(body);
    } else if (product != null) {
      lines.add('Product update: ${product.name}');
      lines.add('Price: ${formatMoney(product.priceMinor, product.currency)}');
      for (final parameter in product.parameters) {
        lines.add('${parameter.name}: ${parameter.value}');
      }
    }
    final link = _videoLink.text.trim();
    if (link.isNotEmpty) lines.add('Details: $link');
    return lines.join('\n');
  }

  Future<bool> _openChat(String phone, String message) async {
    try {
      await _whatsAppChannel.invokeMethod<void>('openChat', {
        'phone': phone,
        'message': message,
      });
      return true;
    } on PlatformException catch (error) {
      setState(() {
        _notice = error.message ?? 'WhatsApp could not be opened.';
        _noticeIsError = true;
      });
      return false;
    }
  }

  Future<void> _startCampaign(
    List<Customer> customers,
    Product? product,
  ) async {
    final recipients = _recipientIds(customers)
        .map(
          (id) => customers.where((customer) => customer.id == id).firstOrNull,
        )
        .whereType<Customer>()
        .where(
          (customer) => customer.whatsappOptIn && customer.phone.isNotEmpty,
        )
        .toList();
    if (recipients.isEmpty) {
      setState(() {
        _notice = 'Select at least one customer with WhatsApp updates enabled and a phone number.';
        _noticeIsError = true;
      });
      return;
    }
    final message = _makeMessage(product);
    if (message.trim().isEmpty) {
      setState(() {
        _notice = 'Enter a message or choose a product to create an update.';
        _noticeIsError = true;
      });
      return;
    }
    setState(() {
      _campaignQueue = recipients;
      _campaignMessage = message;
      _queueIndex = 0;
      _notice = 'WhatsApp opens one customer at a time. Review and send each message in WhatsApp.';
      _noticeIsError = false;
    });
    await _openNextCampaignMessage();
  }

  Future<void> _openNextCampaignMessage() async {
    if (_opening || _queueIndex >= _campaignQueue.length) return;
    final customer = _campaignQueue[_queueIndex];
    setState(() => _opening = true);
    final opened = await _openChat(customer.phone, _campaignMessage);
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (opened) _queueIndex++;
    });
  }

  Future<void> _sendFollowUp(Sale sale) async {
    final phone = sale.draft.customerPhone ?? '';
    final customerName = sale.draft.customerName ?? 'there';
    if (phone.trim().isEmpty || sale.remainingMinor <= 0) return;
    final reference = sale.id.substring(
      0,
      sale.id.length < 8 ? sale.id.length : 8,
    );
    final message =
        'Hi $customerName, a balance of ${formatMoney(sale.remainingMinor, sale.draft.currency)} remains on bill $reference. Please contact us when you are ready to complete payment.';
    await _openChat(phone, message);
  }

  Future<void> _markFollowUpDone(Sale sale) async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    try {
      await ref.read(salesRepositoryProvider).setFollowUp(uid, sale.id, null);
      ref.invalidate(scheduledFollowUpsProvider);
      ref.invalidate(saleProvider(sale.id));
      if (!mounted) return;
      setState(() {
        _notice = 'Follow-up removed from the queue.';
        _noticeIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notice = AppFailure.from(error).displayMessage;
        _noticeIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(whatsAppProductsProvider);
    final followupsAsync = ref.watch(scheduledFollowUpsProvider);
    final theme = Theme.of(context);
    final customers = customersAsync.value ?? const <Customer>[];
    final products = productsAsync.value ?? const <Product>[];
    final selectedIds = _recipientIds(customers);
    final optedInCustomerIds = customers
        .where(
          (customer) => customer.whatsappOptIn && customer.phone.isNotEmpty,
        )
        .map((customer) => customer.id)
        .toSet();
    final product = products
        .where((item) => item.sku == _selectedSku)
        .firstOrNull;
    final dueNow = DateTime.now();
    return SliverPageContent(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Customer communication'),
          const SizedBox(height: 10),
          Text('WhatsApp updates', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Prepare product messages and payment follow-ups for customers who have a saved phone number.',
          ),
          if (_notice != null) ...[
            const SizedBox(height: 14),
            InlineNotice(_notice!, isError: _noticeIsError),
          ],
          const SizedBox(height: 24),
          Text('Product update', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          productsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const InlineNotice(
              'Inventory products could not be loaded.',
              isError: true,
            ),
            data: (items) => DropdownButtonFormField<String?>(
              initialValue: _selectedSku,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Product (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Write a general update'),
                ),
                for (final item in items)
                  DropdownMenuItem<String?>(
                    value: item.sku,
                    child: Text(
                      '${item.name} · ${formatMoney(item.priceMinor, item.currency)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedSku = value),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            maxLength: 800,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message (optional with a product selected)',
              hintText: 'Add an offer, stock note, or a personal message.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _videoLink,
            keyboardType: TextInputType.url,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Video or product link (optional)',
            ),
          ),
          const SizedBox(height: 8),
          Text('Recipients', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Only opted-in customers can receive product updates.'),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: customersAsync.when(
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
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Add customers before sending updates.'),
                    ),
                  )
                : SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final customer = items[index];
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selectedIds.contains(customer.id),
                        onChanged:
                            !customer.whatsappOptIn || customer.phone.isEmpty
                            ? null
                            : (checked) => setState(() {
                                if (!_customSelection) {
                                  _selectedCustomers
                                    ..clear()
                                    ..addAll(_recipientIds(items));
                                }
                                _customSelection = true;
                                if (checked == true) {
                                  _selectedCustomers.add(customer.id);
                                } else {
                                  _selectedCustomers.remove(customer.id);
                                }
                              }),
                        title: Text(customer.name),
                        subtitle: Text(
                          customer.phone.isEmpty
                              ? 'Add a phone number to enable WhatsApp'
                              : customer.whatsappOptIn
                              ? customer.phone
                              : 'Not opted in for product updates',
                        ),
                      );
                    },
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _opening
                      ? null
                      : () => _startCampaign(customers, product),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    'Open WhatsApp for ${selectedIds.length} selected',
                  ),
                ),
                if (_queueIndex < _campaignQueue.length) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Message ${_queueIndex + 1} of ${_campaignQueue.length} is ready. Send it in WhatsApp, return here, then continue.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _opening ? null : _openNextCampaignMessage,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(
                      'Open next: ${_campaignQueue[_queueIndex].name}',
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 22),
                Text('Payment follow-ups', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Scheduled reminders appear here. Open the WhatsApp draft and send it yourself; Hyner does not send messages in the background.',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        followupsAsync.when(
          loading: () => const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(child: LinearProgressIndicator()),
          ),
          error: (_, _) => const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: InlineNotice(
                'Follow-ups could not be loaded.',
                isError: true,
              ),
            ),
          ),
          data: (sales) {
            final eligibleSales = sales
                .where(
                  (sale) => optedInCustomerIds.contains(sale.draft.customerId),
                )
                .toList();
            if (eligibleSales.isEmpty) {
              return const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Text('No payment follow-ups are scheduled.'),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.separated(
                itemCount: eligibleSales.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final sale = eligibleSales[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sale.draft.customerName ?? 'Customer'),
                    subtitle: Text(
                      '${sale.followupAt == null ? 'No date' : saleDate(sale.followupAt!)} · ${sale.followupAt != null && !sale.followupAt!.isAfter(dueNow) ? 'Due now' : 'Upcoming'} · ${formatMoney(sale.remainingMinor, sale.draft.currency)} due',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'open') _sendFollowUp(sale);
                        if (action == 'done') _markFollowUpDone(sale);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'open',
                          child: Text('Open WhatsApp draft'),
                        ),
                        PopupMenuItem(
                          value: 'done',
                          child: Text('Remove reminder'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          sliver: SliverToBoxAdapter(
            child: InlineNotice(
              'Bulk campaigns and automatic WhatsApp sending require the WhatsApp Business Platform. This screen opens one customer chat at a time and requires you to tap Send.',
            ),
          ),
        ),
      ],
    );
  }
}
