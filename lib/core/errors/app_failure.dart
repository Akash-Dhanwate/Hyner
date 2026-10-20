import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum FailureKind {
  cancelled,
  network,
  permission,
  configuration,
  invalidData,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, this.message, {this.reference});

  final FailureKind kind;
  final String message;
  final String? reference;

  String get displayMessage =>
      reference == null ? message : '$message\nReference: $reference';

  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is TimeoutException) {
      return const AppFailure(
        FailureKind.network,
        'The connection took too long. Check your internet connection and try again.',
        reference: 'network/timeout',
      );
    }
    if (error is GoogleSignInException) {
      final failure = switch (error.code) {
        GoogleSignInExceptionCode.canceled => const AppFailure(
          FailureKind.cancelled,
          'Sign-in did not complete. Try again. If this happens after choosing an account, share the reference below with support.',
        ),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          const AppFailure(
            FailureKind.configuration,
            'Google Sign-In is not configured correctly for this installation. Please contact support.',
          ),
        _ => const AppFailure(
          FailureKind.unknown,
          'Google Sign-In could not finish. Check your connection and try again.',
        ),
      };
      // Provider descriptions/details can contain account information. Expose
      // only the SDK's enum code so failures can be reported without USB logs.
      return AppFailure(
        failure.kind,
        failure.message,
        reference: 'google/${error.code.name}',
      );
    }
    if (error is FirebaseException) {
      final failure = switch (error.code) {
        'network-request-failed' ||
        'unavailable' ||
        'deadline-exceeded' => const AppFailure(
          FailureKind.network,
          'We could not connect. Check your internet connection and try again.',
        ),
        'permission-denied' || 'unauthenticated' => const AppFailure(
          FailureKind.permission,
          'Your account could not access its profile. Try signing in again. If this continues, contact support.',
        ),
        'operation-not-allowed' ||
        'invalid-api-key' ||
        'app-not-authorized' => const AppFailure(
          FailureKind.configuration,
          'Account services are not configured correctly for this installation. Please contact support.',
        ),
        'user-disabled' => const AppFailure(
          FailureKind.permission,
          'This account has been disabled. Please contact support.',
        ),
        'too-many-requests' => const AppFailure(
          FailureKind.unknown,
          'There have been too many attempts. Please wait a moment and try again.',
        ),
        _ => const AppFailure(
          FailureKind.unknown,
          'We could not complete the request. Please try again.',
        ),
      };
      final provider = switch (error.plugin) {
        'firebase_auth' || 'cloud_firestore' || 'firebase_core' => error.plugin,
        _ => 'firebase',
      };
      final code = RegExp(r'^[a-z][a-z0-9-]{0,63}$').hasMatch(error.code)
          ? error.code
          : 'unknown';
      return AppFailure(
        failure.kind,
        failure.message,
        reference: '$provider/$code',
      );
    }
    return const AppFailure(
      FailureKind.unknown,
      'Something went wrong. Please try again.',
    );
  }

  @override
  String toString() => message;
}
