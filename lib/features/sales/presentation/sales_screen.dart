import 'package:flutter/material.dart';

import '../../workspace/presentation/module_catalog.dart';
import '../../workspace/presentation/module_placeholder.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      ModulePlaceholder(module: businessModules[1]);
}
