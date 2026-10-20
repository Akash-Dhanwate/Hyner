import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/config/app_config.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';

import 'support/fakes.dart';

void main() {
  test(
    'all workspace routes require an authenticated and synchronized profile',
    () {
      for (final path in [
        '/dashboard',
        '/inventory',
        '/sales',
        '/purchases',
        '/customers',
        '/reports',
        '/settings',
        '/profile',
      ]) {
        expect(
          sessionRedirect(const SessionState(SessionStatus.signedOut), path),
          '/welcome',
        );
        expect(
          sessionRedirect(const SessionState(SessionStatus.loading), path),
          '/splash',
        );
        expect(
          sessionRedirect(const SessionState(SessionStatus.profileError), path),
          '/account-setup',
        );
        expect(
          sessionRedirect(
            SessionState(SessionStatus.signedIn, profile: testProfile()),
            path,
          ),
          isNull,
        );
      }
    },
  );
  test(
    'an invalid authenticated state does not authorize workspace access',
    () {
      expect(
        sessionRedirect(const SessionState(SessionStatus.signedIn), '/profile'),
        '/welcome',
      );
    },
  );
  test('restored sessions leave the sign-in and splash routes', () {
    final state = SessionState(SessionStatus.signedIn, profile: testProfile());
    for (final path in ['/welcome', '/sign-in', '/splash', '/account-setup']) {
      expect(sessionRedirect(state, path), '/dashboard');
    }
  });
  test('missing real Firebase configuration is explicit', () {
    final config = AppConfig.fromEnvironment();
    expect(config.isConfigured, isFalse);
    expect(config.issue, isNotEmpty);
  });
  test('profile timestamps and account identity are preserved', () {
    final profile = testProfile();
    expect(profile.uid, testIdentity.uid);
    expect(profile.email, testIdentity.email);
    expect(profile.createdAt, DateTime.utc(2025, 1, 15));
    expect(profile.firstName, 'Alice');
    expect(profile.initials, 'AT');
  });
  test('missing display name does not fabricate personal information', () {
    final profile = UserProfile(
      uid: 'test',
      email: 'test@example.test',
      createdAt: DateTime.utc(2025),
      lastLoginAt: DateTime.utc(2025),
    );
    expect(profile.displayName, isNull);
    expect(profile.label, 'Your account');
    expect(profile.firstName, 'there');
  });
  test('invalid or insecure profile data is rejected', () {
    expect(
      () => UserProfile(
        uid: '',
        email: 'invalid',
        createdAt: DateTime.utc(2025),
        lastLoginAt: DateTime.utc(2025),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => UserProfile(
        uid: 'test',
        email: 'test@example.test',
        photoUrl: 'http://example.test/avatar.png',
        createdAt: DateTime.utc(2025),
        lastLoginAt: DateTime.utc(2025),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => UserProfile(
        uid: 'test',
        email: 'test@example.test',
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2025),
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}
