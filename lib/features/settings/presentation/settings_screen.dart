import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/widgets/page_content.dart';

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
        const SizedBox(height: 32),
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
