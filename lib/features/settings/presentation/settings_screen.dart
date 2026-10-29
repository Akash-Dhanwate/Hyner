import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import '../../../app/routing/workspace_navigation.dart';
import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/payment_settings.dart';
import 'payment_settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Make it yours'),
        const SizedBox(height: 12),
        Text('Settings', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const InlineNotice(
          'Products, customers and bills are stored only on this device. They do not sync or have a cloud backup yet. Clearing app data or uninstalling Hyner can remove them.',
        ),
        const SizedBox(height: 32),
        const Eyebrow('Notifications'),
        const SizedBox(height: 8),
        const _NotificationSettings(),
        const SizedBox(height: 24),
        const Eyebrow('Appearance'),
        const SizedBox(height: 12),
        for (final entry in [
          (
            ThemeMode.system,
            'Use device setting',
            Icons.brightness_auto_outlined,
          ),
          (ThemeMode.light, 'Light', Icons.light_mode_outlined),
          (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
        ])
          ListTile(
            leading: Icon(entry.$3, size: 22),
            title: Text(entry.$2),
            trailing: Icon(
              mode == entry.$1
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: mode == entry.$1
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            selected: mode == entry.$1,
            onTap: () async {
              try {
                await ref
                    .read(themeControllerProvider.notifier)
                    .select(entry.$1);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Your appearance setting could not be saved. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        const SizedBox(height: 24),
        const _UpiSettingsForm(),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 28),
        const Eyebrow('Account'),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Your profile'),
          subtitle: const Text('Account information and sign-out'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openWorkspacePage(GoRouter.of(context), '/profile'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 28),
        const Eyebrow('About'),
        const SizedBox(height: 16),
        Text('Hyner', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Version 1.0.0 · Application foundation',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Business tools will arrive in future updates.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NotificationSettings extends ConsumerStatefulWidget {
  const _NotificationSettings();

  @override
  ConsumerState<_NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<_NotificationSettings>
    with WidgetsBindingObserver {
  bool? _enabled;
  bool _busy = false;
  bool _permissionAsked = false;
  bool _scannedLowStock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await LocalNotificationService.instance.isEnabled();
    if (mounted) setState(() => _enabled = enabled);
    if (enabled && !_scannedLowStock && mounted) {
      _scannedLowStock = true;
      await ref.read(inventoryProvider.notifier).checkAllLowStock();
    }
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (_permissionAsked) {
      await LocalNotificationService.instance.openSettings();
    } else {
      final enabled = await LocalNotificationService.instance
          .requestPermission();
      _permissionAsked = true;
      if (enabled && mounted) {
        await ref.read(inventoryProvider.notifier).checkAllLowStock();
      }
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.notifications_active_outlined),
    title: const Text('Low stock and activity alerts'),
    subtitle: Text(
      _enabled == true
          ? 'Enabled. Alerts appear when you leave Hyner.'
          : 'Allow alerts for low stock, sales, purchases, and payments.',
    ),
    trailing: _enabled == null || _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : _enabled == true
        ? const Icon(Icons.check_circle_outline_rounded)
        : TextButton(
            onPressed: _enable,
            child: Text(_permissionAsked ? 'Open settings' : 'Enable'),
          ),
  );
}

class _UpiSettingsForm extends ConsumerStatefulWidget {
  const _UpiSettingsForm();
  @override
  ConsumerState<_UpiSettingsForm> createState() => _UpiSettingsFormState();
}

class _UpiSettingsFormState extends ConsumerState<_UpiSettingsForm> {
  final _upi = TextEditingController();
  final _name = TextEditingController();
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(paymentSettingsProvider.future);
      if (!mounted) return;
      _upi.text = settings.upiId;
      _name.text = settings.merchantName;
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'UPI settings could not be loaded.';
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = ref.read(inventoryUidProvider);
      if (uid == null) {
        throw const FormatException('Sign in to save UPI details.');
      }
      await ref
          .read(dependenciesProvider)
          .paymentSettings
          .save(
            uid,
            PaymentSettings(upiId: _upi.text, merchantName: _name.text),
          );
      ref.invalidate(paymentSettingsProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI QR details saved on this device.')),
      );
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'UPI details could not be saved.';
        });
      }
    }
  }

  @override
  void dispose() {
    _upi.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Eyebrow('UPI payment QR'),
      const SizedBox(height: 8),
      const Text(
        'Hyner creates a QR with the bill’s exact INR amount. The customer pays through their own UPI app; you check the payment and mark the bill paid. Hyner does not process or verify payments.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _upi,
        enabled: !_loading && !_saving,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Your UPI ID',
          hintText: 'shop@bank',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        enabled: !_loading && !_saving,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Business name shown in UPI app',
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        InlineNotice(_error!, isError: true),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _loading || _saving ? null : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _loading
              ? 'Loading…'
              : _saving
              ? 'Saving…'
              : 'Save UPI details',
        ),
      ),
    ],
  );
}
