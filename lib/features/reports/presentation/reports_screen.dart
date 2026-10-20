import 'package:flutter/material.dart';

import '../../workspace/presentation/module_catalog.dart';
import '../../workspace/presentation/module_placeholder.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      ModulePlaceholder(module: businessModules[4]);
}
