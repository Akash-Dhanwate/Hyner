import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';

class InventoryFeedback extends StatelessWidget {
  const InventoryFeedback({
    super.key,
    required this.error,
    required this.retry,
  });
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      InlineNotice(AppFailure.from(error).displayMessage, isError: true),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: retry, child: const Text('Try again')),
    ],
  );
}
