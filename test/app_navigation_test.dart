import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';

import 'support/fakes.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool restored = false,
    bool configured = true,
    Size size = const Size(390, 844),
    double textScale = 1,
    ThemeMode mode = ThemeMode.system,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = FakeAuth(user: restored ? testIdentity : null);
    final profiles = FakeProfiles();
    final appearance = MemoryAppearance()..mode = mode;
    final dependencies = configured
        ? connectedTestDependencies(auth, profiles, appearance: appearance)
        : testDependencies(auth, profiles, configured: false);
    final container = ProviderContainer(
      overrides: [dependenciesProvider.overrideWithValue(dependencies)],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HynerApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'welcome navigates to Google Sign-In and test authentication opens dashboard',
    (tester) async {
      final container = await mount(tester);
      expect(find.text('Your business.\nA little clearer.'), findsOneWidget);
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Hyner'), findsOneWidget);
      await tester.tap(find.byKey(const Key('google-sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Alice.'), findsOneWidget);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      expect(container.read(routerProvider).canPop(), isFalse);
    },
  );

  testWidgets(
    'every protected screen renders and profile contains database values',
    (tester) async {
      final container = await mount(tester, restored: true);
      final router = container.read(routerProvider);
      for (final entry in [
        ('/inventory', 'A little more is on the way'),
        ('/sales', 'A little more is on the way'),
        ('/purchases', 'A little more is on the way'),
        ('/customers', 'A little more is on the way'),
        ('/reports', 'A little more is on the way'),
        ('/settings', 'Settings'),
        ('/profile', 'Profile'),
        ('/dashboard', 'Hello, Alice.'),
      ]) {
        router.go(entry.$1);
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsWidgets, reason: entry.$1);
        expect(tester.takeException(), isNull, reason: entry.$1);
      }
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Alice Test'), findsWidgets);
      expect(find.text('alice@example.test'), findsWidgets);
      final context = tester.element(find.text('Profile'));
      expect(
        find.text(
          MaterialLocalizations.of(context)
              .formatFullDate(DateTime(2025, 1, 15)),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('More navigation opens Purchases and Customers', (tester) async {
    await mount(tester, restored: true);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Purchases').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Keep track of what comes into your business.'),
      findsOneWidget,
    );
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    expect(
      find.text('A clearer picture of your customer relationships.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'system Back retraces sections instead of exiting the workspace',
    (tester) async {
      final container = await mount(tester, restored: true);
      final router = container.read(routerProvider);
      await tester.tap(find.text('Inventory').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales').last);
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(
        find.text('A home for every item in your business.'),
        findsOneWidget,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Hello, Alice.'), findsOneWidget);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      expect(router.canPop(), isFalse);
      expect(await router.routerDelegate.popRoute(), isFalse);
    },
  );

  testWidgets('system Back closes the drawer before leaving its section', (
    tester,
  ) async {
    final container = await mount(tester, restored: true);
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsNothing);
    expect(container.read(routerProvider).state.uri.path, '/inventory');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Hello, Alice.'), findsOneWidget);
  });

  testWidgets('Back dismisses More and retraces a section opened from it', (
    tester,
  ) async {
    final container = await mount(tester, restored: true);
    final router = container.read(routerProvider);
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsNothing);
    expect(router.state.uri.path, '/inventory');
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/customers');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/inventory');
  });

  testWidgets('dashboard links and profile preserve the previous page', (
    tester,
  ) async {
    final container = await mount(tester, restored: true);
    final router = container.read(routerProvider);
    await tester.tap(find.widgetWithText(ListTile, 'Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your profile'));
    await tester.pumpAndSettle();
    expect(find.text('alice@example.test'), findsWidgets);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/inventory');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Hello, Alice.'), findsOneWidget);
  });

  testWidgets('drawer Settings and its profile link preserve history', (
    tester,
  ) async {
    final container = await mount(tester, restored: true);
    final router = container.read(routerProvider);
    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final settings = find.widgetWithText(ListTile, 'Settings');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/settings');
    final profile = find.widgetWithText(ListTile, 'Your profile');
    await tester.ensureVisible(profile);
    await tester.tap(profile);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/settings');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/sales');
  });

  testWidgets(
    'selecting the current destination does not add duplicate pages',
    (tester) async {
      final container = await mount(tester, restored: true);
      await tester.tap(find.text('Inventory').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory').last);
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Hello, Alice.'), findsOneWidget);
      await tester.tap(find.byTooltip('Your profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Your profile'));
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Hello, Alice.'), findsOneWidget);
      expect(container.read(routerProvider).canPop(), isFalse);
    },
  );

  testWidgets('Home and Back to dashboard reset to the workspace root', (
    tester,
  ) async {
    final container = await mount(tester, restored: true);
    final router = container.read(routerProvider);
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Alice.'), findsOneWidget);
    expect(router.canPop(), isFalse);
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Back to dashboard'));
    await tester.tap(find.text('Back to dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Alice.'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('wide-screen navigation also returns to the previous section', (
    tester,
  ) async {
    final container = await mount(
      tester,
      restored: true,
      size: const Size(900, 900),
    );
    final router = container.read(routerProvider);
    await tester.tap(find.widgetWithText(ListTile, 'Inventory').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Sales').first);
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/inventory');
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back from Google Sign-In returns to Welcome', (
    tester,
  ) async {
    final container = await mount(tester);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Hyner'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(container.read(sessionProvider).isAuthenticated, isFalse);
  });

  testWidgets(
    'logout removes access and direct protected navigation is rejected',
    (tester) async {
      final container = await mount(tester, restored: true);
      final router = container.read(routerProvider);
      await tester.tap(find.text('Inventory').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Your profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('sign-out')));
      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(await router.routerDelegate.popRoute(), isFalse);
      expect(
        find.text('alice@example.test', skipOffstage: false),
        findsNothing,
      );
      router.go('/inventory');
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Product catalogue'), findsNothing);
    },
  );

  testWidgets(
    'missing Firebase configuration disables sign-in without a fake user',
    (tester) async {
      final container = await mount(tester, configured: false);
      container.read(routerProvider).go('/sign-in');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('google-sign-in')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('has not been connected'), findsOneWidget);
      expect(container.read(sessionProvider).profile, isNull);
    },
  );

  testWidgets('network login failures display an error and allow retry', (
    tester,
  ) async {
    final container = await mount(tester);
    final auth = container.read(dependenciesProvider).auth as FakeAuth;
    auth.signInFailure = const AppFailure(
      FailureKind.network,
      'Check your internet connection.',
    );
    container.read(routerProvider).go('/sign-in');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Check your internet connection.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('google-sign-in')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'a Google canceled response stays visible on a small screen and permits retry',
    (tester) async {
      final container = await mount(
        tester,
        size: const Size(320, 568),
        textScale: 1.6,
      );
      final auth = container.read(dependenciesProvider).auth as FakeAuth;
      auth.signInFailure = AppFailure.from(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'private-person@example.test',
        ),
      );
      container.read(routerProvider).go('/sign-in');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('google-sign-in')),
        200,
      );
      await tester.tap(find.byKey(const Key('google-sign-in')));
      await tester.pumpAndSettle();
      final feedback = find.textContaining('Reference: google/canceled');
      await tester.scrollUntilVisible(feedback, 200);
      expect(feedback, findsOneWidget);
      expect(find.textContaining('private-person'), findsNothing);
      expect(container.read(sessionProvider).isAuthenticated, isFalse);
      expect(tester.takeException(), isNull);
      auth.signInFailure = null;
      await tester.scrollUntilVisible(
        find.byKey(const Key('google-sign-in')),
        -200,
      );
      await tester.tap(find.byKey(const Key('google-sign-in')));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      expect(find.text('Hello, Alice.'), findsOneWidget);
    },
  );

  testWidgets(
    'a Firestore profile failure shows its reference without opening the workspace',
    (tester) async {
      final container = await mount(tester);
      final profiles =
          container.read(dependenciesProvider).profiles as FakeProfiles;
      profiles.failure = AppFailure.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      container.read(routerProvider).go('/sign-in');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('google-sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Let’s reconnect your account'), findsOneWidget);
      expect(
        find.textContaining('Reference: cloud_firestore/permission-denied'),
        findsOneWidget,
      );
      expect(container.read(sessionProvider).isAuthenticated, isFalse);
      expect(find.text('Hello, Alice.'), findsNothing);
    },
  );

  testWidgets('appearance saves and a failed write is visible', (tester) async {
    final container = await mount(tester, restored: true);
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themeControllerProvider), ThemeMode.dark);
    final appearance =
        container.read(dependenciesProvider).appearance as MemoryAppearance;
    expect(appearance.mode, ThemeMode.dark);
    appearance.failWrites = true;
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(container.read(themeControllerProvider), ThemeMode.dark);
  });

  testWidgets(
    'provider cleanup failure is visible after leaving the workspace',
    (tester) async {
      final container = await mount(tester, restored: true);
      (container.read(dependenciesProvider).auth as FakeAuth).cleanupFails =
          true;
      await container.read(sessionProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(find.textContaining('cleanup did not finish'), findsOneWidget);
      expect(container.read(sessionProvider).profile, isNull);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('small-screen large-text layout in ${mode.name} theme', (
      tester,
    ) async {
      final container = await mount(
        tester,
        restored: true,
        size: const Size(320, 568),
        textScale: 1.6,
        mode: mode,
      );
      await container.read(themeControllerProvider.notifier).select(mode);
      for (final path in [
        '/dashboard',
        '/inventory',
        '/sales',
        '/purchases',
        '/customers',
        '/reports',
        '/settings',
        '/profile',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$path ${mode.name}');
      }
    });
  }

  testWidgets('welcome and sign-in support small screens with large text', (
    tester,
  ) async {
    final container = await mount(
      tester,
      size: const Size(320, 568),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    container.read(routerProvider).go('/sign-in');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
