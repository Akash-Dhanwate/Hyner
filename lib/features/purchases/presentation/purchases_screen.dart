import 'package:flutter/material.dart';

import '../../workspace/presentation/module_catalog.dart';
import '../../workspace/presentation/module_placeholder.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      ModulePlaceholder(module: businessModules[2]);
}
