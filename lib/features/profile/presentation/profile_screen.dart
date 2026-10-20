import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    if (profile == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final created = MaterialLocalizations.of(context)
        .formatFullDate(profile.createdAt.toLocal());
    return PageContent(
      children: [
        const Eyebrow('Your account'),
        const SizedBox(height: 12),
        Text('Profile', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              AccountAvatar(profile: profile, radius: 48),
              const SizedBox(height: 20),
              Text(
                profile.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              SelectableText(
                profile.email,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        const Divider(),
        const SizedBox(height: 20),
        _DetailRow(
          'Full name',
          profile.displayName?.trim().isNotEmpty == true
              ? profile.displayName!
              : 'Not provided by Google',
        ),
        _DetailRow('Email address', profile.email),
        _DetailRow('Account created', created),
        const _DetailRow('Sign-in method', 'Google'),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        if (session.failure != null) ...[
          InlineNotice(session.failure!.displayMessage, isError: true),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: session.busy
                ? null
                : () => ref.read(sessionProvider.notifier).signOut(),
            icon: session.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: Text(session.busy ? 'Signing out…' : 'Sign out'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Signing out removes access to this workspace on this device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
