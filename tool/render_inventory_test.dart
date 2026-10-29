// Local visual review only. Fixtures are never part of the Android application.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/inventory/domain/product.dart';

import '../test/support/fakes.dart';
import '../test/support/inventory_fakes.dart';

void main() {
  testWidgets('render Inventory review images with test-only products', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final auth = FakeAuth(user: testIdentity);
    final inventory = FakeInventory();
    inventory.products(testIdentity.uid).addAll({
      'NB-001': inventoryFixture(
        sku: 'NB-001',
        name: 'Stationery notebook',
        quantity: 8,
        revision: 2,
        priceMinor: 6500,
      ),
      'PN-002': inventoryFixture(
        sku: 'PN-002',
        name: 'Blue ballpoint pen',
        quantity: 2,
        priceMinor: 1500,
      ),
      'TP-003': inventoryFixture(
        sku: 'TP-003',
        name: 'Packing tape',
        quantity: 0,
        priceMinor: 4500,
      ),
    });
    inventory.history['${testIdentity.uid}/NB-001'] = [
      StockMovement(
        id: 'adjust1',
        type: 'adjustment',
        beforeQuantity: 10,
        afterQuantity: 8,
        delta: -2,
        reason: 'Damaged packaging',
        actorUid: testIdentity.uid,
        revision: 2,
        createdAt: DateTime.utc(2026, 10, 23, 10),
      ),
      StockMovement(
        id: 'opening1',
        type: 'opening',
        beforeQuantity: 0,
        afterQuantity: 10,
        delta: 10,
        reason: 'Opening stock',
        actorUid: testIdentity.uid,
        revision: 1,
        createdAt: DateTime.utc(2026, 10, 23, 9),
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, FakeProfiles(), inventory: inventory),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final page in [
      ('/inventory', 'phase2-inventory-test-fixture'),
      ('/inventory/NB-001', 'phase2-product-test-fixture'),
      ('/inventory/add', 'phase2-add-product-test-fixture'),
    ]) {
      container.read(routerProvider).go(page.$1);
      await tester.pumpAndSettle();
      await capture(page.$2);
    }
    await container
        .read(themeControllerProvider.notifier)
        .select(ThemeMode.dark);
    container.read(routerProvider).go('/inventory');
    await tester.pumpAndSettle();
    await capture('phase2-inventory-dark-test-fixture');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    await capture('phase2-inventory-small-text-test-fixture');
    expect(tester.takeException(), isNull);
  });
}
