import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';

import 'support/fakes.dart';
import 'support/inventory_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeInventory inventory;
  late ProviderContainer container;

  Future<void> mount(
    WidgetTester tester, {
    Product? product,
    Size size = const Size(390, 844),
    double scale = 1,
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    auth = FakeAuth(user: testIdentity);
    profiles = FakeProfiles();
    inventory = FakeInventory();
    if (product != null) {
      inventory.products(testIdentity.uid)[product.sku] = product;
    }
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(
            auth,
            profiles,
            inventory: inventory,
            appearance: MemoryAppearance()..mode = mode,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HynerApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/inventory');
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> saveProduct(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
  }

  Future<void> openProduct(WidgetTester tester, {String sku = 'TEST-1'}) async {
    final row = find.byKey(ValueKey('product-$sku'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create validates fields and saves exact prices with opening stock',
    (tester) async {
      await mount(tester);
      expect(find.text('No products yet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-product')));
      await tester.pumpAndSettle();
      await saveProduct(tester);
      expect(inventory.writes, 0);
      expect(find.text('Enter the product name.'), findsOneWidget);
      await enter(tester, 'product-code', ' rice_1 ');
      await enter(tester, 'product-name', 'Rice bag');
      await enter(tester, 'product-cost', '100.10');
      await enter(tester, 'product-price', '125.50');
      await enter(tester, 'product-opening', '5');
      await enter(tester, 'product-threshold', '2');
      await saveProduct(tester);
      expect(container.read(routerProvider).state.uri.path, '/inventory');
      final product = inventory.products(testIdentity.uid)['RICE_1']!;
      expect(product.costMinor, 10010);
      expect(product.priceMinor, 12550);
      expect(product.quantity, 5);
      expect(
        inventory.history['${testIdentity.uid}/RICE_1']!.single.reason,
        'Opening stock',
      );
      expect(find.text('Rice bag'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing changes metadata and returns to refreshed product details',
    (tester) async {
      await mount(tester, product: inventoryFixture());
      await openProduct(tester);
      await tester.ensureVisible(find.text('Edit product'));
      await tester.tap(find.text('Edit product'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('product-code')))
            .enabled,
        isFalse,
      );
      expect(find.byKey(const Key('product-opening')), findsNothing);
      await enter(tester, 'product-name', 'Renamed product');
      await enter(tester, 'product-price', '130.05');
      await saveProduct(tester);
      expect(
        container.read(routerProvider).state.uri.path,
        '/inventory/TEST-1',
      );
      expect(find.text('Renamed product'), findsOneWidget);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 10);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.priceMinor, 13005);
    },
  );

  testWidgets(
    'stock adjustment requires a reason and shows its new balance and history',
    (tester) async {
      await mount(tester, product: inventoryFixture(quantity: 1));
      await openProduct(tester);
      await tester.tap(find.byKey(const Key('adjust-stock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-adjustment')));
      await tester.pumpAndSettle();
      expect(inventory.writes, 0);
      expect(find.text('Explain why the stock is changing.'), findsOneWidget);
      await enter(tester, 'adjustment-units', '3');
      await enter(tester, 'adjustment-reason', 'Physical stock count');
      await tester.ensureVisible(find.byKey(const Key('save-adjustment')));
      await tester.tap(find.byKey(const Key('save-adjustment')));
      await tester.pumpAndSettle();
      expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 4);
      expect(find.text('4 units'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Physical stock count'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('product-details-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('+3 units · 1 → 4'), findsOneWidget);
      expect(find.text('Physical stock count'), findsOneWidget);
    },
  );

  testWidgets('removing too much stock fails without writing', (tester) async {
    await mount(tester, product: inventoryFixture(quantity: 1));
    await openProduct(tester);
    await tester.tap(find.byKey(const Key('adjust-stock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove units').last);
    await tester.pumpAndSettle();
    await enter(tester, 'adjustment-units', '2');
    await enter(tester, 'adjustment-reason', 'Damaged stock');
    await tester.tap(find.byKey(const Key('save-adjustment')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('resulting stock must be between'),
      findsOneWidget,
    );
    expect(inventory.writes, 0);
    expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 1);
  });

  testWidgets(
    'archive requires zero stock and restore returns product to active inventory',
    (tester) async {
      await mount(tester, product: inventoryFixture(quantity: 0));
      await openProduct(tester);
      await tester.ensureVisible(find.text('Archive product'));
      await tester.tap(find.text('Archive product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(inventory.products(testIdentity.uid)['TEST-1']!.archived, isTrue);
      expect(find.text('Restore product'), findsOneWidget);
      await tester.tap(find.text('Restore product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore').last);
      await tester.pumpAndSettle();
      expect(inventory.products(testIdentity.uid)['TEST-1']!.archived, isFalse);
      expect(find.text('Adjust stock'), findsOneWidget);
    },
  );

  testWidgets(
    'Back confirms unsaved changes and preserves navigation history',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('add-product')));
      await tester.pumpAndSettle();
      await enter(tester, 'product-name', 'Unsaved product');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/inventory/add');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/inventory');
      expect(inventory.writes, 0);
    },
  );

  testWidgets('a double save is disabled until the first write completes', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('add-product')));
    await tester.pumpAndSettle();
    await enter(tester, 'product-code', 'NEW-1');
    await enter(tester, 'product-name', 'New product');
    final pending = inventory.pendingWrite = Completer<void>();
    await saveProduct(tester);
    expect(inventory.writes, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-product')))
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(inventory.products(testIdentity.uid), hasLength(1));
    expect(container.read(routerProvider).state.uri.path, '/inventory');
  });

  testWidgets(
    'read errors show retry and never show an empty successful catalogue',
    (tester) async {
      await mount(tester);
      inventory.failure = const AppFailure(
        FailureKind.permission,
        'Publish inventory rules',
      );
      await tester.tap(find.byTooltip('Refresh inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Publish inventory rules'), findsOneWidget);
      expect(find.text('No products yet'), findsNothing);
      inventory.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No products yet'), findsOneWidget);
    },
  );

  testWidgets(
    'an in-flight save cannot expose one account product after account switching',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('add-product')));
      await tester.pumpAndSettle();
      await enter(tester, 'product-code', 'PRIVATE');
      await enter(tester, 'product-name', 'Private account product');
      final pending = inventory.pendingWrite = Completer<void>();
      await saveProduct(tester);
      const bob = AccountIdentity(uid: 'bob', email: 'bob@example.test');
      profiles.result = UserProfile(
        uid: bob.uid,
        email: bob.email,
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2026),
      );
      auth.changeAccount(bob);
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/inventory');
      await tester.pumpAndSettle();
      expect(inventory.products('bob'), isEmpty);
      expect(
        find.text('Private account product', skipOffstage: false),
        findsNothing,
      );
      expect(find.text('No products yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a network save error freezes the payload and retries with the same operation ID',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('add-product')));
      await tester.pumpAndSettle();
      await enter(tester, 'product-code', 'RETRY-1');
      await enter(tester, 'product-name', 'Retry product');
      inventory.failure = const AppFailure(
        FailureKind.network,
        'Connection interrupted',
      );
      await saveProduct(tester);
      expect(find.text('Connection interrupted'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('product-name')))
            .enabled,
        isFalse,
      );
      expect(inventory.operationCount, 1);
      inventory.failure = null;
      await saveProduct(tester);
      expect(inventory.operationCount, 1);
      expect(inventory.products(testIdentity.uid), hasLength(1));
      expect(container.read(routerProvider).state.uri.path, '/inventory');
    },
  );

  testWidgets(
    'a stale edit fails visibly and cannot overwrite a newer saved product',
    (tester) async {
      await mount(tester, product: inventoryFixture());
      await openProduct(tester);
      await tester.ensureVisible(find.text('Edit product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit product'));
      await tester.pumpAndSettle();
      await enter(tester, 'product-name', 'Stale edit');
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
        name: 'Newer saved name',
        revision: 2,
      );
      await saveProduct(tester);
      expect(
        find.text('This product changed. Refresh before saving.'),
        findsOneWidget,
      );
      expect(
        inventory.products(testIdentity.uid)['TEST-1']!.name,
        'Newer saved name',
      );
      expect(
        container.read(routerProvider).state.uri.path,
        '/inventory/TEST-1/edit',
      );
    },
  );

  testWidgets(
    'a product with remaining stock cannot be archived from its details',
    (tester) async {
      await mount(tester, product: inventoryFixture(quantity: 5));
      await openProduct(tester);
      await tester.ensureVisible(find.text('Archive product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive product'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Stock must be zero before archiving'),
        findsOneWidget,
      );
      expect(inventory.writes, 0);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.archived, isFalse);
    },
  );

  testWidgets(
    'catalogue prefix search and archived filter show only matching real rows',
    (tester) async {
      await mount(tester, product: inventoryFixture(name: 'Alpha product'));
      inventory.products(testIdentity.uid)['BETA'] = inventoryFixture(
        sku: 'BETA',
        name: 'Beta product',
      );
      inventory.products(testIdentity.uid)['OLD'] = inventoryFixture(
        sku: 'OLD',
        name: 'Old product',
        quantity: 0,
        archived: true,
      );
      await tester.enterText(find.byKey(const Key('inventory-search')), 'beta');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Beta product'), findsOneWidget);
      expect(find.text('Alpha product'), findsNothing);
      await tester.enterText(find.byKey(const Key('inventory-search')), '');
      await tester.tap(find.byTooltip('Search inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      expect(find.text('Old product'), findsOneWidget);
      expect(find.text('Beta product'), findsNothing);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'inventory forms and details fit small screens with large text in ${mode.name}',
      (tester) async {
        await mount(
          tester,
          product: inventoryFixture(
            quantity: 1,
            name: 'A longer product name for layout testing',
          ),
          size: const Size(320, 568),
          scale: 1.6,
          mode: mode,
        );
        expect(tester.takeException(), isNull);
        for (final path in [
          '/inventory/TEST-1',
          '/inventory/add',
          '/inventory/TEST-1/edit',
        ]) {
          container.read(routerProvider).go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
        }
        container.read(routerProvider).go('/inventory/TEST-1');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('adjust-stock')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('adjust-stock')));
        await tester.pumpAndSettle();
        expect(find.text('Adjust stock'), findsWidgets);
        expect(find.byKey(const Key('adjustment-units')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'adjustment dialog');
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'keyboard open');
        tester.view.resetViewInsets();
      },
    );
  }
}
