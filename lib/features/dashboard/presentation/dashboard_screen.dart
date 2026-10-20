import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';
import '../../workspace/presentation/module_catalog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Your workspace'),
        const SizedBox(height: 12),
        Text(
          'Hello, ${profile?.firstName ?? 'there'}.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Everything starts with a clear workspace.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(height: 20),
              Text('Your account is ready', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Your profile is connected. Business tools will become available in future updates.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    openWorkspacePage(GoRouter.of(context), '/profile'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View profile'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        const Eyebrow('Business tools'),
        const SizedBox(height: 12),
        for (final module in businessModules) ...[
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .6,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(module.icon, size: 24),
            ),
            title: Text(
              module.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Coming in a future update'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => openWorkspacePage(GoRouter.of(context), module.path),
          ),
          const Divider(),
        ],
      ],
    );
  }
}
