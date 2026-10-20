import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/hyner_mark.dart';
import '../../../core/widgets/page_content.dart';
import 'session_controller.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final dependencies = ref.watch(dependenciesProvider);
    final signingIn = session.status == SessionStatus.signingIn;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to welcome',
          onPressed: () => context.go('/welcome'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: HynerMark(size: 64),
                ),
                const SizedBox(height: 32),
                Text('Welcome to Hyner', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Sign in to create your workspace or pick up where you left off.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('google-sign-in'),
                    onPressed:
                        signingIn ||
                            session.busy ||
                            !dependencies.config.isConfigured
                        ? null
                        : () => ref.read(sessionProvider.notifier).signIn(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (signingIn)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Image.asset(
                              'assets/branding/google-g.png',
                              width: 20,
                              height: 20,
                              excludeFromSemantics: true,
                            ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              signingIn
                                  ? 'Connecting…'
                                  : 'Continue with Google',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (dependencies.config.issue != null)
                  InlineNotice(dependencies.config.issue!),
                if (session.failure != null)
                  InlineNotice(
                    session.failure!.displayMessage,
                    isError: session.failure!.kind != FailureKind.cancelled,
                  ),
                if (dependencies.startupNotice != null) ...[
                  const SizedBox(height: 12),
                  InlineNotice(dependencies.startupNotice!),
                ],
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Google handles your sign-in securely. Hyner never receives or stores your password.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountSetupScreen extends ConsumerWidget {
  const AccountSetupScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final failed = state.status == SessionStatus.profileError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const HynerMark(size: 68),
                  const SizedBox(height: 32),
                  Text(
                    failed
                        ? 'Let’s reconnect your account'
                        : 'Getting your workspace ready',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  if (failed)
                    InlineNotice(state.failure!.displayMessage, isError: true)
                  else ...[
                    const Text(
                      'Securely loading your account details.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    const CircularProgressIndicator(
                      semanticsLabel: 'Loading account profile',
                    ),
                  ],
                  if (failed) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.busy
                            ? null
                            : () => ref
                                  .read(sessionProvider.notifier)
                                  .retryProfile(),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => ref.read(sessionProvider.notifier).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
