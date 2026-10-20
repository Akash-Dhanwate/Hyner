import 'package:flutter/material.dart';

import '../../workspace/presentation/module_catalog.dart';
import '../../workspace/presentation/module_placeholder.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      ModulePlaceholder(module: businessModules[0]);
}
