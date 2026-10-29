import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/sales/data/sales_checkout.dart';

void main() {
  test(
    'missing backend has a setup message instead of reporting a saved sale',
    () {
      final failure = checkoutFailure('not-found', null);
      expect(failure.kind, FailureKind.configuration);
      expect(failure.message, contains('server update must be deployed'));
    },
  );
  test('validation failures allow corrections and show server feedback', () {
    final failure = checkoutFailure(
      'failed-precondition',
      'Only 2 units available.',
    );
    expect(failure.kind, FailureKind.invalidData);
    expect(failure.message, 'Only 2 units available.');
  });
  test('ambiguous checkout errors require retrying the identical bill', () {
    for (final code in [
      'unavailable',
      'deadline-exceeded',
      'internal',
      'resource-exhausted',
      'unknown',
    ]) {
      final failure = checkoutFailure(code, 'Provider diagnostic');
      expect(failure.kind, FailureKind.network);
      expect(failure.message, contains('retry this same bill'));
      expect(failure.message, isNot(contains('Provider diagnostic')));
    }
  });
}
