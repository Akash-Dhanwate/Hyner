import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/config/app_config.dart';
import 'package:hyner/app/theme/appearance_repository.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/profile/domain/profile_repository.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';

// Isolated test fixtures. These are never compiled into lib/ or the application.
const testIdentity = AccountIdentity(
  uid: 'test-alice',
  email: 'alice@example.test',
  displayName: 'Alice Test',
);
UserProfile testProfile() => UserProfile(
  uid: testIdentity.uid,
  email: testIdentity.email,
  displayName: testIdentity.displayName,
  createdAt: DateTime.utc(2025, 1, 15),
  lastLoginAt: DateTime.utc(2026, 1, 15),
);

class FakeAuth implements AuthRepository {
  FakeAuth({this.user});
  AccountIdentity? user;
  final _changes = StreamController<AccountIdentity?>.broadcast();
  AppFailure? signInFailure;
  AppFailure? signOutFailure;
  bool cleanupFails = false;
  int signInCalls = 0;

  @override
  AccountIdentity? get currentUser => user;
  @override
  Stream<AccountIdentity?> authStateChanges() async* {
    yield user;
    yield* _changes.stream;
  }

  @override
  Future<AccountIdentity> signInWithGoogle() async {
    signInCalls++;
    if (signInFailure != null) throw signInFailure!;
    user = testIdentity;
    _changes.add(user);
    return user!;
  }

  @override
  Future<void> signOut() async {
    if (signOutFailure != null) throw signOutFailure!;
    user = null;
    _changes.add(null);
    if (cleanupFails) {
      throw const AppFailure(
        FailureKind.unknown,
        'Simulated provider cleanup failure',
      );
    }
  }

  Future<void> close() => _changes.close();
}

class FakeProfiles implements ProfileRepository {
  AppFailure? failure;
  UserProfile? result;
  Completer<UserProfile>? pending;
  int calls = 0;
  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? result ?? testProfile() : pending!.future;
  }
}

class MemoryAppearance implements AppearanceRepository {
  ThemeMode mode = ThemeMode.system;
  bool failWrites = false;
  @override
  Future<ThemeMode> read() async => mode;
  @override
  Future<void> write(ThemeMode value) async {
    if (failWrites) throw StateError('Simulated storage failure');
    mode = value;
  }
}

AppDependencies testDependencies(
  FakeAuth auth,
  FakeProfiles profiles, {
  MemoryAppearance? appearance,
  bool configured = true,
}) => AppDependencies(
  auth: auth,
  profiles: profiles,
  appearance: appearance ?? MemoryAppearance(),
  config: AppConfig(
    environment: AppEnvironment.development,
    // Explicit test-only SDK options are omitted: the fake config overrides only
    // the UI availability flag through a test subclass below.
    issue: configured
        ? null
        : 'This installation has not been connected to account services.',
  ),
);

class ConfiguredTestConfig extends AppConfig {
  const ConfiguredTestConfig() : super(environment: AppEnvironment.development);
  @override
  bool get isConfigured => true;
}

AppDependencies connectedTestDependencies(
  FakeAuth auth,
  FakeProfiles profiles, {
  MemoryAppearance? appearance,
}) => AppDependencies(
  auth: auth,
  profiles: profiles,
  appearance: appearance ?? MemoryAppearance(),
  config: const ConfiguredTestConfig(),
);
