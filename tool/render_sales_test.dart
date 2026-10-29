// Visual review fixtures only; never included in the Android app.
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
import 'package:hyner/features/sales/domain/sale.dart';

import '../test/support/fakes.dart';
import '../test/support/inventory_fakes.dart';
import '../test/support/sales_fakes.dart';

void main() {
  testWidgets('render Sales screens with isolated review fixtures', (
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
    final notebook = inventoryFixture(
      sku: 'NB-001',
      name: 'Stationery notebook',
      quantity: 8,
      priceMinor: 6500,
    );
    final pen = inventoryFixture(
      sku: 'PN-002',
      name: 'Blue ballpoint pen',
      quantity: 24,
      priceMinor: 1500,
    );
    inventory.products(testIdentity.uid).addAll({
      notebook.sku: notebook,
      pen.sku: pen,
    });
    final sales = FakeSales(inventory);
    sales.sales(testIdentity.uid).addAll({
      'review-bill-001': Sale(
        id: 'review-bill-001',
        createdAt: DateTime.utc(2026, 10, 25, 9, 30),
        draft: SaleDraft(
          currency: 'INR',
          lines: [
            SaleLine.fromProduct(notebook, 2),
            SaleLine.fromProduct(pen, 3),
          ],
        ),
      ),
      'review-bill-002': Sale(
        id: 'review-bill-002',
        createdAt: DateTime.utc(2026, 10, 25, 10, 15),
        draft: SaleDraft(
          currency: 'INR',
          lines: [SaleLine.fromProduct(pen, 4)],
        ),
      ),
    });
    final container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(
            auth,
            FakeProfiles(),
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
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final router = container.read(routerProvider);
    router.go('/sales/history');
    await tester.pumpAndSettle();
    await capture('build9-sales-history-test-fixture');
    router.go('/sales/review-bill-001');
    await tester.pumpAndSettle();
    await capture('build9-bill-test-fixture');
    router.go('/sales');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-sale-product')));
    await tester.pumpAndSettle();
    await capture('build9-product-picker-test-fixture');
    await tester.tap(find.byKey(const Key('pick-NB-001')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sale-quantity-NB-001')), '2');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sale-price-NB-001')), '60.00');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await capture('build9-new-bill-test-fixture');
    await tester.ensureVisible(find.byKey(const Key('save-sale')));
    await tester.pumpAndSettle();
    await capture('build9-bill-total-test-fixture');
    await container
        .read(themeControllerProvider.notifier)
        .select(ThemeMode.dark);
    router.go('/sales/history');
    await tester.pumpAndSettle();
    await capture('build9-sales-history-dark-test-fixture');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    router.go('/sales/review-bill-001');
    await tester.pumpAndSettle();
    await capture('build9-bill-small-text-test-fixture');
  });
}
