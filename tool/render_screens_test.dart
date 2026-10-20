// UI review utility. Test repositories are used only by flutter test.
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

import '../test/support/fakes.dart';

void main() {
  testWidgets('render review images with isolated test fixtures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final auth = FakeAuth();
    final container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, FakeProfiles()),
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
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/google-g.png'),
        key.currentContext!,
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

    await capture('welcome');
    container.read(routerProvider).go('/sign-in');
    await tester.pumpAndSettle();
    await capture('sign-in');
    await auth.signInWithGoogle();
    await tester.pumpAndSettle();
    for (final path in ['/dashboard', '/inventory', '/profile', '/settings']) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      await capture('${path.substring(1)}-test-fixture');
    }
    await container
        .read(themeControllerProvider.notifier)
        .select(ThemeMode.dark);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();
    await capture('dashboard-dark-test-fixture');
    expect(tester.takeException(), isNull);
  });
}
