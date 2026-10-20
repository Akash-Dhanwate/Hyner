import 'package:flutter/material.dart';

class WorkspaceModule {
  const WorkspaceModule(
    this.name,
    this.path,
    this.icon,
    this.description,
    this.planned,
  );
  final String name;
  final String path;
  final IconData icon;
  final String description;
  final List<String> planned;
}

const businessModules = [
  WorkspaceModule(
    'Inventory',
    '/inventory',
    Icons.inventory_2_outlined,
    'A home for every item in your business.',
    ['Product catalogue', 'Stock visibility', 'Low-stock notifications'],
  ),
  WorkspaceModule(
    'Sales',
    '/sales',
    Icons.receipt_long_outlined,
    'Keep everyday sales clearly organised.',
    ['Sales records', 'Customer billing', 'Returns'],
  ),
  WorkspaceModule(
    'Purchases',
    '/purchases',
    Icons.shopping_bag_outlined,
    'Keep track of what comes into your business.',
    ['Purchase records', 'Supplier details', 'Purchase returns'],
  ),
  WorkspaceModule(
    'Customers',
    '/customers',
    Icons.people_outline_rounded,
    'A clearer picture of your customer relationships.',
    ['Customer directory', 'Account history', 'Payment records'],
  ),
  WorkspaceModule(
    'Reports',
    '/reports',
    Icons.bar_chart_rounded,
    'Turn your business activity into useful insights.',
    ['Business summaries', 'Profit and loss', 'Sales insights'],
  ),
];

const accountModules = [
  WorkspaceModule(
    'Settings',
    '/settings',
    Icons.tune_rounded,
    'Make Hyner feel right for you.',
    [],
  ),
  WorkspaceModule(
    'Your profile',
    '/profile',
    Icons.person_outline_rounded,
    'Your account information.',
    [],
  ),
];
