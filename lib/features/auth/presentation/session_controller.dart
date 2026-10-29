import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/auth_repository.dart';

enum SessionStatus {
  loading,
  signedOut,
  signingIn,
  synchronizing,
  signedIn,
  profileError,
}

class SessionState {
  const SessionState(
    this.status, {
    this.profile,
    this.failure,
    this.busy = false,
  });
  final SessionStatus status;
  final UserProfile? profile;
  final AppFailure? failure;
  final bool busy;
  bool get isAuthenticated =>
      status == SessionStatus.signedIn && profile != null;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  StreamSubscription<AccountIdentity?>? _subscription;
  int _generation = 0;
  bool _disposed = false;
  bool _signingOut = false;
  AppFailure? _logoutFailure;

  @override
  SessionState build() {
    final auth = ref.read(dependenciesProvider).auth;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      unawaited(_subscription?.cancel());
    });
    scheduleMicrotask(() {
      if (_disposed) return;
      _subscription = auth.authStateChanges().listen(
        _onAccount,
        onError: (Object error) {
          if (_disposed) return;
          _generation++;
          state = SessionState(
            SessionStatus.signedOut,
            failure: AppFailure.from(error),
          );
        },
      );
    });
    return const SessionState(SessionStatus.loading);
  }

  Future<void> _onAccount(AccountIdentity? identity) async {
    final generation = ++_generation;
    if (identity == null) {
      state = SessionState(
        SessionStatus.signedOut,
        failure: _logoutFailure,
        busy: _signingOut,
      );
      return;
    }
    if (_signingOut) return;
    state = const SessionState(SessionStatus.synchronizing);
    try {
      final profile = await ref
          .read(dependenciesProvider)
          .profiles
          .synchronize(identity);
      if (_disposed || generation != _generation) return;
      if (ref.read(dependenciesProvider).auth.currentUser?.uid !=
          identity.uid) {
        return;
      }
      if (profile.uid != identity.uid || profile.email != identity.email) {
        throw const AppFailure(
          FailureKind.invalidData,
          'The saved profile does not match your signed-in account. Please contact support.',
        );
      }
      state = SessionState(SessionStatus.signedIn, profile: profile);
    } catch (error) {
      if (_disposed || generation != _generation) return;
      state = SessionState(
        SessionStatus.profileError,
        failure: AppFailure.from(error),
      );
    }
  }

  Future<void> signIn() async {
    if (state.status == SessionStatus.signingIn || state.busy || _signingOut) {
      return;
    }
    _logoutFailure = null;
    state = const SessionState(SessionStatus.signingIn);
    try {
      await ref.read(dependenciesProvider).auth.signInWithGoogle();
      // The authentication stream owns synchronization and routing.
    } catch (error) {
      if (_disposed) return;
      final failure = AppFailure.from(error);
      state = SessionState(
        SessionStatus.signedOut,
        // Android can report a configuration failure after account selection
        // as "canceled". Keep feedback instead of silently returning to login.
        failure: failure,
      );
    }
  }

  Future<void> retryProfile() async {
    final user = ref.read(dependenciesProvider).auth.currentUser;
    await _onAccount(user);
  }

  Future<void> updateProfile(ProfileDraft draft) async {
    final current = state.profile;
    if (current == null || !state.isAuthenticated) {
      throw const AppFailure(
        FailureKind.permission,
        'Sign in again before editing your profile.',
      );
    }
    final updated = await ref
        .read(dependenciesProvider)
        .profiles
        .update(current, draft);
    if (_disposed || state.profile?.uid != current.uid) return;
    state = SessionState(SessionStatus.signedIn, profile: updated);
  }

  Future<void> signOut() async {
    if (state.busy || _signingOut) return;
    _signingOut = true;
    _logoutFailure = null;
    final previous = state;
    ++_generation;
    state = SessionState(
      previous.status,
      profile: previous.profile,
      busy: true,
    );
    try {
      await ref.read(dependenciesProvider).auth.signOut();
      _signingOut = false;
      if (!_disposed) state = const SessionState(SessionStatus.signedOut);
    } catch (error) {
      _signingOut = false;
      if (_disposed) return;
      final stillSignedIn =
          ref.read(dependenciesProvider).auth.currentUser != null;
      if (!stillSignedIn) {
        _logoutFailure = const AppFailure(
          FailureKind.unknown,
          'You are signed out of Hyner, but Google account cleanup did not finish. Try again before sharing this device.',
        );
      }
      state = stillSignedIn
          ? SessionState(
              previous.profile == null
                  ? SessionStatus.profileError
                  : SessionStatus.signedIn,
              profile: previous.profile,
              failure: AppFailure.from(error),
            )
          : SessionState(SessionStatus.signedOut, failure: _logoutFailure);
    }
  }
}
