import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import 'module_catalog.dart';

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.module});
  final WorkspaceModule module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Business tools'),
        const SizedBox(height: 12),
        Text(module.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          module.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 36),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: .4,
                  ),
                ),
                child: Icon(
                  module.icon,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'A little more is on the way',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                '${module.name} will be available in a future update. There’s nothing to set up here yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Eyebrow('Planned for this space'),
        const SizedBox(height: 12),
        for (final item in module.planned)
          ListTile(
            leading: Icon(
              Icons.circle_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(item),
            trailing: Text(
              'Planned',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to dashboard'),
          ),
        ),
      ],
    );
  }
}
