import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/workspace/presentation/workspace_shell.dart';

String? sessionRedirect(SessionState session, String path) {
  final public = path == '/welcome' || path == '/sign-in';
  return switch (session.status) {
    SessionStatus.loading => path == '/splash' ? null : '/splash',
    SessionStatus.signedOut ||
    SessionStatus.signingIn => public ? null : '/welcome',
    SessionStatus.synchronizing || SessionStatus.profileError =>
      path == '/account-setup' ? null : '/account-setup',
    SessionStatus.signedIn =>
      !session.isAuthenticated
          ? '/welcome'
          : public ||
                path == '/splash' ||
                path == '/account-setup' ||
                path == '/'
          ? '/dashboard'
          : null,
  };
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (previous, next) => refresh.refresh());
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) =>
        sessionRedirect(ref.read(sessionProvider), state.uri.path),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/account-setup',
        builder: (context, state) => const AccountSetupScreen(),
      ),
      _page('/dashboard', const DashboardScreen()),
      _page('/inventory', const InventoryScreen()),
      _page('/sales', const SalesScreen()),
      _page('/purchases', const PurchasesScreen()),
      _page('/customers', const CustomersScreen()),
      _page('/reports', const ReportsScreen()),
      _page('/settings', const SettingsScreen()),
      _page('/profile', const ProfileScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This page could not be found',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Go to workspace'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

GoRoute _page(String path, Widget child) => GoRoute(
  path: path,
  pageBuilder: (context, state) => CustomTransitionPage<void>(
    key: state.pageKey,
    // Keep the drawer and its page on the same Navigator so system Back
    // dismisses an open drawer before popping the page underneath it.
    child: WorkspaceShell(location: state.uri.path, child: child),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);
