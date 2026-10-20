import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hyner/core/errors/app_failure.dart';

void main() {
  test('Google cancellation keeps a safe reference without native details', () {
    final failure = AppFailure.from(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'private-person@example.test',
        details: {'idToken': 'private-token-fixture'},
      ),
    );
    expect(failure.kind, FailureKind.cancelled);
    expect(failure.displayMessage, contains('Reference: google/canceled'));
    expect(failure.displayMessage, contains('after choosing an account'));
    expect(failure.displayMessage, isNot(contains('private-person')));
    expect(failure.displayMessage, isNot(contains('private-token')));
  });

  test('Google configuration failures retain their provider code', () {
    final failure = AppFailure.from(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'private provider details',
      ),
    );
    expect(failure.kind, FailureKind.configuration);
    expect(failure.reference, 'google/clientConfigurationError');
    expect(failure.displayMessage, isNot(contains('private provider details')));
  });

  test('Firebase authentication failures identify the auth stage safely', () {
    final failure = AppFailure.from(
      FirebaseException(
        plugin: 'firebase_auth',
        code: 'operation-not-allowed',
        message: 'private-person@example.test private-token-fixture',
      ),
    );
    expect(failure.kind, FailureKind.configuration);
    expect(failure.reference, 'firebase_auth/operation-not-allowed');
    expect(failure.displayMessage, isNot(contains('private-person')));
    expect(failure.displayMessage, isNot(contains('private-token')));
  });

  test('Firestore permissions remain distinguishable from Google login', () {
    final failure = AppFailure.from(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    expect(failure.kind, FailureKind.permission);
    expect(failure.reference, 'cloud_firestore/permission-denied');
  });

  test('unexpected plugin names and unsafe error codes are not displayed', () {
    final failure = AppFailure.from(
      FirebaseException(
        plugin: 'private-person@example.test',
        code: 'Bearer private-token-fixture',
        message: 'private provider response',
      ),
    );
    expect(failure.reference, 'firebase/unknown');
    expect(failure.displayMessage, isNot(contains('private')));
  });

  test('timeouts expose a network reference without request details', () {
    final failure = AppFailure.from(
      TimeoutException('private request details'),
    );
    expect(failure.kind, FailureKind.network);
    expect(failure.reference, 'network/timeout');
    expect(failure.displayMessage, isNot(contains('private request details')));
  });
}
