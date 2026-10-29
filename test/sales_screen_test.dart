import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';
import 'package:hyner/features/sales/domain/sale.dart';

import 'support/fakes.dart';
import 'support/inventory_fakes.dart';
import 'support/sales_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeInventory inventory;
  late FakeSales sales;
  late ProviderContainer container;
  Future<void> mount(
    WidgetTester tester, {
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
    sales = FakeSales(inventory);
    inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
      quantity: 5,
      priceMinor: 1550,
    );
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(
            auth,
            profiles,
            inventory: inventory,
            sales: sales,
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
    await container.read(themeControllerProvider.notifier).select(mode);
    container.read(routerProvider).go('/sales/history');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> startBill(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('new-sale')));
    await tap(tester, find.byKey(const Key('add-sale-product')));
    await tap(tester, find.byKey(const Key('pick-TEST-1')));
  }

  Future<void> quantity(WidgetTester tester, String text) async {
    final field = find.byKey(const Key('sale-quantity-TEST-1'));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  testWidgets('Sales opens the bill builder without querying saved history', (
    tester,
  ) async {
    await mount(tester);
    sales.requestedUids.clear();
    container.read(routerProvider).go('/sales');
    await tester.pumpAndSettle();
    expect(find.text('Build a bill'), findsOneWidget);
    expect(find.text('No products added yet.'), findsOneWidget);
    expect(sales.requestedUids, isEmpty);
  });

  testWidgets(
    'creates a sale, calculates total, deducts stock and opens its saved bill',
    (tester) async {
      await mount(tester);
      expect(find.text('No sales yet'), findsOneWidget);
      await startBill(tester);
      await quantity(tester, '2');
      expect(find.text('INR 31.00'), findsOneWidget);
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(container.read(routerProvider).state.uri.path, '/sales/sale1');
      expect(find.text('SAVED SALE'), findsOneWidget);
      expect(find.text('2 × INR 15.50'), findsOneWidget);
      expect(sales.writes, 1);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 3);
      container.read(routerProvider).go('/sales/history');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sale-sale1')), findsOneWidget);
    },
  );
  testWidgets(
    'bill price defaults to inventory, can reset, and saves a discount only on the bill',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      final price = find.byKey(const Key('sale-price-TEST-1'));
      expect(tester.widget<TextFormField>(price).controller!.text, '15.50');
      await tester.ensureVisible(price);
      await tester.enterText(price, '12.00');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Use inventory price'));
      expect(tester.widget<TextFormField>(price).controller!.text, '15.50');
      await tester.ensureVisible(price);
      await tester.enterText(price, '12.00');
      await tester.pumpAndSettle();
      await quantity(tester, '2');
      expect(find.text('INR 24.00'), findsOneWidget);
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(find.text('2 × INR 12.00'), findsOneWidget);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.priceMinor, 1550);
      expect(sales.sales(testIdentity.uid)['sale1']!.draft.totalMinor, 2400);
    },
  );
  testWidgets('negative and fractional-cent prices cannot save a bill', (
    tester,
  ) async {
    await mount(tester);
    await startBill(tester);
    final price = find.byKey(const Key('sale-price-TEST-1'));
    for (final invalid in ['-1', '1.234', '']) {
      await tester.ensureVisible(price);
      await tester.enterText(price, invalid);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(sales.writes, 0);
    }
  });

  testWidgets('a bill can add and save more than five different products', (
    tester,
  ) async {
    await mount(tester);
    for (var i = 2; i <= 6; i++) {
      inventory.products(testIdentity.uid)['TEST-$i'] = inventoryFixture(
        sku: 'TEST-$i',
        quantity: 5,
        priceMinor: 1550,
      );
    }
    await startBill(tester);
    for (var i = 2; i <= 6; i++) {
      await tap(tester, find.byKey(const Key('add-sale-product')));
      await tap(tester, find.byKey(Key('pick-TEST-$i')));
    }
    expect(find.text('Add product (6 added)'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('add-sale-product')))
          .onPressed,
      isNotNull,
    );
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.sales(testIdentity.uid)['sale1']!.draft.lines.length, 6);
    expect(sales.sales(testIdentity.uid)['sale1']!.draft.totalMinor, 9300);
    expect(sales.writes, 1);
  });

  testWidgets('rejects overselling before calling the repository', (
    tester,
  ) async {
    await mount(tester);
    await startBill(tester);
    await quantity(tester, '6');
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(find.text('Only 5 units available.'), findsOneWidget);
    expect(sales.writes, 0);
  });
  testWidgets(
    'server stock and product identity changes fail visibly without creating a sale',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
        quantity: 0,
        priceMinor: 1550,
      );
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(find.text('Insufficient available stock.'), findsOneWidget);
      expect(sales.writes, 0);
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
        quantity: 5,
        priceMinor: 2000,
        name: 'Renamed product',
      );
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(
        find.text('Product changed. Remove it and add it again.'),
        findsOneWidget,
      );
      expect(sales.writes, 0);
    },
  );
  testWidgets(
    'lost response freezes bill and retry uses same ID without a second deduction',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      await quantity(tester, '2');
      sales.failAfterCommit = true;
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(find.text('Connection interrupted'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('sale-quantity-TEST-1')),
            )
            .enabled,
        isFalse,
      );
      expect(sales.writes, 1);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 3);
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(sales.ids, 1);
      expect(sales.writes, 1);
      expect(container.read(routerProvider).state.uri.path, '/sales/sale1');
    },
  );
  testWidgets('save stays disabled while a write is pending', (tester) async {
    await mount(tester);
    await startBill(tester);
    sales.pendingWrite = Completer<void>();
    final save = find.byKey(const Key('save-sale'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(sales.ids, 1);
    sales.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(sales.writes, 1);
  });
  testWidgets('back asks before discarding and empty bill cannot be saved', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byKey(const Key('new-sale')));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('save-sale'))).onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const Key('add-sale-product')));
    await tap(tester, find.byKey(const Key('pick-TEST-1')));
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Discard this bill?'), findsOneWidget);
    await tap(tester, find.text('Stay'));
    expect(container.read(routerProvider).state.uri.path, '/sales');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Leave'));
    expect(container.read(routerProvider).state.uri.path, '/sales/history');
  });
  testWidgets(
    'product picker prevents duplicate and out-of-stock selection and supports search',
    (tester) async {
      await mount(tester);
      inventory.products(testIdentity.uid)['ZERO'] = inventoryFixture(
        sku: 'ZERO',
        name: 'Zero stock',
        quantity: 0,
      );
      await startBill(tester);
      await tap(tester, find.byKey(const Key('add-sale-product')));
      expect(
        tester.widget<ListTile>(find.byKey(const Key('pick-TEST-1'))).enabled,
        isFalse,
      );
      expect(
        tester.widget<ListTile>(find.byKey(const Key('pick-ZERO'))).enabled,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const Key('sale-product-search')),
        'zero',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pick-TEST-1')), findsNothing);
      expect(find.text('Zero stock'), findsOneWidget);
    },
  );
  testWidgets('switching accounts clears an unsaved bill', (tester) async {
    await mount(tester);
    await startBill(tester);
    profiles.result = UserProfile(
      uid: 'bob',
      email: 'bob@example.test',
      createdAt: DateTime.utc(2026),
      lastLoginAt: DateTime.utc(2026),
    );
    auth.changeAccount(
      const AccountIdentity(uid: 'bob', email: 'bob@example.test'),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/sales/new');
    await tester.pumpAndSettle();
    expect(find.text('Test product'), findsNothing);
    expect(find.text('No products added yet.'), findsOneWidget);
    expect(sales.writes, 0);
  });
  testWidgets(
    'sales errors offer retry and never show a successful empty list',
    (tester) async {
      await mount(tester);
      sales.failure = const AppFailure(
        FailureKind.permission,
        'Publish sales rules',
      );
      await tap(tester, find.byTooltip('Refresh sales'));
      expect(find.text('Publish sales rules'), findsOneWidget);
      expect(find.text('No sales yet'), findsNothing);
      sales.failure = null;
      await tap(tester, find.text('Try again'));
      expect(find.text('No sales yet'), findsOneWidget);
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'sales list, picker, bill and detail fit 320px with large text in ${mode.name}',
      (tester) async {
        await mount(tester, size: const Size(320, 568), scale: 1.6, mode: mode);
        expect(tester.takeException(), isNull);
        await startBill(tester);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        sales.sales(testIdentity.uid)['saved'] = Sale(
          id: 'saved',
          createdAt: DateTime.utc(2026),
          draft: SaleDraft(
            currency: 'INR',
            lines: [SaleLine.fromProduct(inventoryFixture(), 2)],
          ),
        );
        container.read(routerProvider).go('/sales/saved');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
