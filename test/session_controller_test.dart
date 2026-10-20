import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';

import 'support/fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late ProviderContainer container;

  Future<void> start({bool restored = false}) async {
    auth = FakeAuth(user: restored ? testIdentity : null);
    profiles = FakeProfiles();
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, profiles),
        ),
      ],
    );
    container.read(sessionProvider);
    await pumpEventQueue();
  }

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test('a fresh installation is signed out', () async {
    await start();
    expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    expect(profiles.calls, 0);
  });
  test('first sign-in synchronizes the authenticated user profile', () async {
    await start();
    await container.read(sessionProvider.notifier).signIn();
    await pumpEventQueue();
    expect(container.read(sessionProvider).profile?.uid, testIdentity.uid);
    expect(profiles.calls, 1);
  });
  test('a restored auth identity reloads its profile', () async {
    await start(restored: true);
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).profile?.email, testIdentity.email);
    expect(profiles.calls, 1);
  });
  test('logout clears profile state', () async {
    await start(restored: true);
    await container.read(sessionProvider.notifier).signOut();
    await pumpEventQueue();
    expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    expect(container.read(sessionProvider).profile, isNull);
  });
  test(
    'cancelled Google sign-in stays signed out with visible feedback',
    () async {
      await start();
      auth.signInFailure = const AppFailure(FailureKind.cancelled, 'Cancelled');
      await container.read(sessionProvider.notifier).signIn();
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(
        container.read(sessionProvider).failure?.kind,
        FailureKind.cancelled,
      );
    },
  );
  test('network failure is visible and does not authenticate', () async {
    await start();
    auth.signInFailure = const AppFailure(
      FailureKind.network,
      'Connection unavailable',
    );
    await container.read(sessionProvider.notifier).signIn();
    expect(container.read(sessionProvider).isAuthenticated, isFalse);
    expect(container.read(sessionProvider).failure?.kind, FailureKind.network);
  });
  test('Firestore failure blocks the workspace and can be retried', () async {
    await start();
    profiles.failure = const AppFailure(
      FailureKind.permission,
      'Permission denied',
    );
    await container.read(sessionProvider.notifier).signIn();
    await pumpEventQueue();
    expect(container.read(sessionProvider).status, SessionStatus.profileError);
    expect(container.read(sessionProvider).isAuthenticated, isFalse);
    profiles.failure = null;
    await container.read(sessionProvider.notifier).retryProfile();
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });
  test(
    'an in-flight profile response cannot restore a logged-out session',
    () async {
      await start();
      final pending = Completer<UserProfile>();
      profiles.pending = pending;
      await container.read(sessionProvider.notifier).signIn();
      await pumpEventQueue();
      expect(
        container.read(sessionProvider).status,
        SessionStatus.synchronizing,
      );
      await container.read(sessionProvider.notifier).signOut();
      pending.complete(testProfile());
      await pumpEventQueue();
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(container.read(sessionProvider).profile, isNull);
    },
  );
  test('logout failure is visible and retains the current session', () async {
    await start(restored: true);
    auth.signOutFailure = const AppFailure(
      FailureKind.network,
      'Cannot sign out',
    );
    await container.read(sessionProvider.notifier).signOut();
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).failure?.kind, FailureKind.network);
  });

  test(
    'a profile for a different account is rejected without exposing it',
    () async {
      await start();
      profiles.result = UserProfile(
        uid: 'test-bob',
        email: 'bob@example.test',
        createdAt: DateTime.utc(2025),
        lastLoginAt: DateTime.utc(2026),
      );
      await container.read(sessionProvider.notifier).signIn();
      await pumpEventQueue();
      expect(
        container.read(sessionProvider).status,
        SessionStatus.profileError,
      );
      expect(container.read(sessionProvider).profile, isNull);
      expect(
        container.read(sessionProvider).failure?.kind,
        FailureKind.invalidData,
      );
    },
  );

  test('failed logout during synchronization remains recoverable', () async {
    await start();
    final pending = Completer<UserProfile>();
    profiles.pending = pending;
    await container.read(sessionProvider.notifier).signIn();
    await pumpEventQueue();
    auth.signOutFailure = const AppFailure(
      FailureKind.network,
      'Cannot sign out',
    );
    await container.read(sessionProvider.notifier).signOut();
    expect(container.read(sessionProvider).status, SessionStatus.profileError);
    pending.complete(testProfile());
    await pumpEventQueue();
    expect(container.read(sessionProvider).profile, isNull);
    profiles.pending = null;
    await container.read(sessionProvider.notifier).retryProfile();
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });

  test('a late signed-out event preserves provider cleanup feedback', () async {
    await start(restored: true);
    auth.cleanupFails = true;
    await container.read(sessionProvider.notifier).signOut();
    await pumpEventQueue();
    expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    expect(container.read(sessionProvider).profile, isNull);
    expect(
      container.read(sessionProvider).failure?.message,
      contains('cleanup did not finish'),
    );
  });
}
