import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/hyner_mark.dart';
import '../../auth/presentation/session_controller.dart';
import 'module_catalog.dart';

class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({
    super.key,
    required this.location,
    required this.child,
  });
  final String location;
  final Widget child;

  int get _selected => switch (location) {
    '/dashboard' => 0,
    '/inventory' => 1,
    '/sales' => 2,
    '/reports' => 3,
    _ => 4,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HynerMark(size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Hyner',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                tooltip: 'Your profile',
                onPressed: () =>
                    openWorkspacePage(GoRouter.of(context), '/profile'),
                icon: AccountAvatar(profile: profile, radius: 17),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: _NavigationList(location: location, closeDrawer: true),
        ),
      ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 224,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: _NavigationList(location: location),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: (index) {
                  if (index == 4) {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (sheetContext) => FractionallySizedBox(
                        heightFactor: .75,
                        child: _NavigationList(location: location, sheet: true),
                      ),
                    );
                  } else {
                    openWorkspacePage(
                      GoRouter.of(context),
                      ['/dashboard', '/inventory', '/sales', '/reports'][index],
                    );
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2_rounded),
                    label: 'Inventory',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Sales',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart_rounded),
                    label: 'Reports',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'More',
                  ),
                ],
              ),
            ),
    );
  }
}

class _NavigationList extends StatelessWidget {
  const _NavigationList({
    required this.location,
    this.closeDrawer = false,
    this.sheet = false,
  });
  final String location;
  final bool closeDrawer;
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    void navigate(String path) {
      final router = GoRouter.of(context);
      if (closeDrawer || sheet) Navigator.of(context).pop();
      openWorkspacePage(router, path);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Workspace', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        for (final module in [
          const WorkspaceModule(
            'Dashboard',
            '/dashboard',
            Icons.space_dashboard_outlined,
            '',
            [],
          ),
          ...businessModules,
        ])
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            selected: module.path == location,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: .5),
            leading: Icon(module.icon, size: 22),
            title: Text(module.name),
            onTap: () => navigate(module.path),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(),
        ),
        for (final module in accountModules)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(module.icon, size: 22),
            title: Text(module.name),
            onTap: () => navigate(module.path),
          ),
        const SizedBox(height: 28),
        Text(
          'Hyner · Business, in order.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
