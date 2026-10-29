import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sales_repository.dart';
import 'package:hyner/features/sales/presentation/sales_controller.dart';

import 'support/fakes.dart';
import 'support/inventory_fakes.dart';
import 'support/sales_fakes.dart';

Future<void> flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeSales sales;
  late ProviderContainer container;
  Sale fixture(String id) => Sale(
    id: id,
    createdAt: DateTime.utc(2026),
    draft: SaleDraft(
      currency: 'INR',
      lines: [SaleLine.fromProduct(inventoryFixture(), 1)],
    ),
  );
  setUp(() async {
    auth = FakeAuth(user: testIdentity);
    profiles = FakeProfiles();
    sales = FakeSales(FakeInventory());
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, profiles, sales: sales),
        ),
      ],
    );
    container.listen(salesProvider, (_, next) {});
    await flush();
  });
  tearDown(() async {
    container.dispose();
    await auth.close();
  });
  test('empty sales list uses the signed-in account with no sample data', () {
    expect(container.read(salesProvider).sales, isEmpty);
    expect(sales.requestedUids, [testIdentity.uid]);
  });
  test('newest refresh wins over a late response', () async {
    final old = Completer<SalesPage>();
    sales.pendingList = old;
    final first = container.read(salesProvider.notifier).refresh();
    sales.pendingList = null;
    sales.sales(testIdentity.uid)['new'] = fixture('new');
    await container.read(salesProvider.notifier).refresh();
    old.complete(SalesPage([fixture('old')], null));
    await first;
    expect(container.read(salesProvider).sales.single.id, 'new');
  });
  test('sign-out clears records and ignores in-flight responses', () async {
    final pending = Completer<SalesPage>();
    sales.pendingList = pending;
    final read = container.read(salesProvider.notifier).refresh();
    await container.read(sessionProvider.notifier).signOut();
    await flush();
    pending.complete(SalesPage([fixture('private')], null));
    await read;
    expect(container.read(salesProvider).sales, isEmpty);
  });
  test('account switch never exposes previous account bills', () async {
    sales.sales(testIdentity.uid)['private'] = fixture('private');
    await container.read(salesProvider.notifier).refresh();
    profiles.result = UserProfile(
      uid: 'bob',
      email: 'bob@example.test',
      createdAt: DateTime.utc(2026),
      lastLoginAt: DateTime.utc(2026),
    );
    auth.changeAccount(
      const AccountIdentity(uid: 'bob', email: 'bob@example.test'),
    );
    await flush();
    expect(container.read(salesProvider).sales, isEmpty);
    expect(sales.requestedUids.last, 'bob');
  });
  test(
    'pagination retains records on failure and retries the next page',
    () async {
      sales.pageSize = 1;
      sales.sales(testIdentity.uid).addAll({
        'a': fixture('a'),
        'b': fixture('b'),
      });
      final controller = container.read(salesProvider.notifier);
      await controller.refresh();
      expect(container.read(salesProvider).sales.single.id, 'b');
      sales.failure = const AppFailure(FailureKind.network, 'Offline');
      await controller.loadMore();
      expect(container.read(salesProvider).sales.single.id, 'b');
      expect(container.read(salesProvider).failure, isNotNull);
      sales.failure = null;
      await controller.loadMore();
      expect(container.read(salesProvider).sales.map((s) => s.id), ['b', 'a']);
      expect(container.read(salesProvider).next, isNull);
    },
  );
}
