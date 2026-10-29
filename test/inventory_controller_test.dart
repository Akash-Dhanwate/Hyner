import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/inventory/domain/inventory_repository.dart';
import 'package:hyner/features/inventory/presentation/inventory_controller.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';

import 'support/fakes.dart';
import 'support/inventory_fakes.dart';

Future<void> flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeInventory inventory;
  late ProviderContainer container;
  setUp(() async {
    auth = FakeAuth(user: testIdentity);
    profiles = FakeProfiles();
    inventory = FakeInventory();
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, profiles, inventory: inventory),
        ),
      ],
    );
    container.listen(inventoryProvider, (previous, next) {});
    await flush();
  });
  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test('empty inventory contains no sample products and is scoped to the authenticated UID', () {
    expect(container.read(inventoryProvider).products, isEmpty);
    expect(container.read(inventoryProvider).loading, isFalse);
    expect(inventory.requestedUids, [testIdentity.uid]);
  });
  test('search and archive filters are sent to the repository', () async {
    inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture();
    await container
        .read(inventoryProvider.notifier)
        .refresh(query: const InventoryQuery(search: 'no-match'));
    expect(container.read(inventoryProvider).products, isEmpty);
    await container
        .read(inventoryProvider.notifier)
        .refresh(
          query: const InventoryQuery(
            search: 'test',
            searchBy: ProductSearch.code,
          ),
        );
    expect(container.read(inventoryProvider).products.single.sku, 'TEST-1');
    await container
        .read(inventoryProvider.notifier)
        .refresh(query: const InventoryQuery(archived: true));
    expect(container.read(inventoryProvider).products, isEmpty);
  });
  test('older search results cannot replace a newer query', () async {
    final old = Completer<InventoryPage>();
    inventory.pendingList = old;
    final first = container
        .read(inventoryProvider.notifier)
        .refresh(query: const InventoryQuery(search: 'old'));
    final newer = Completer<InventoryPage>();
    inventory.pendingList = newer;
    final second = container
        .read(inventoryProvider.notifier)
        .refresh(query: const InventoryQuery(search: 'new'));
    newer.complete(
      InventoryPage([inventoryFixture(sku: 'NEW', name: 'New')], null),
    );
    await second;
    old.complete(
      InventoryPage([inventoryFixture(sku: 'OLD', name: 'Old')], null),
    );
    await first;
    expect(container.read(inventoryProvider).query.search, 'new');
    expect(container.read(inventoryProvider).products.single.sku, 'NEW');
  });
  test(
    'logout clears inventory and discards a late account response',
    () async {
      final pending = Completer<InventoryPage>();
      inventory.pendingList = pending;
      final read = container.read(inventoryProvider.notifier).refresh();
      await container.read(sessionProvider.notifier).signOut();
      await flush();
      pending.complete(InventoryPage([inventoryFixture()], null));
      await read;
      expect(container.read(inventoryProvider).products, isEmpty);
      expect(container.read(inventoryUidProvider), isNull);
    },
  );
  test(
    'switching accounts never exposes the previous account catalogue',
    () async {
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture();
      await container.read(inventoryProvider.notifier).refresh();
      expect(container.read(inventoryProvider).products, hasLength(1));
      const bob = AccountIdentity(uid: 'bob', email: 'bob@example.test');
      profiles.result = UserProfile(
        uid: bob.uid,
        email: bob.email,
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2026),
      );
      auth.changeAccount(bob);
      await flush();
      expect(container.read(inventoryUidProvider), 'bob');
      expect(container.read(inventoryProvider).products, isEmpty);
      expect(inventory.requestedUids.last, 'bob');
    },
  );
  test('pagination appends without duplicates and retains rows after a failed next page', () async {
    inventory.pageSize = 1;
    inventory.products(testIdentity.uid).addAll({
      'A': inventoryFixture(sku: 'A'),
      'B': inventoryFixture(sku: 'B'),
    });
    await container.read(inventoryProvider.notifier).refresh();
    expect(container.read(inventoryProvider).products.single.sku, 'A');
    inventory.failure = const AppFailure(FailureKind.network, 'Offline');
    await container.read(inventoryProvider.notifier).loadMore();
    expect(container.read(inventoryProvider).products.single.sku, 'A');
    expect(container.read(inventoryProvider).failure?.message, 'Offline');
    inventory.failure = null;
    await container.read(inventoryProvider.notifier).loadMore();
    expect(container.read(inventoryProvider).products.map((p) => p.sku), [
      'A',
      'B',
    ]);
    expect(container.read(inventoryProvider).next, isNull);
  });
  test('a failed initial read is visible and retry can recover', () async {
    inventory.failure = const AppFailure(
      FailureKind.permission,
      'Publish inventory rules',
    );
    await container.read(inventoryProvider.notifier).refresh();
    expect(
      container.read(inventoryProvider).failure?.kind,
      FailureKind.permission,
    );
    inventory.failure = null;
    await container.read(inventoryProvider.notifier).refresh();
    expect(container.read(inventoryProvider).failure, isNull);
  });
}
