import 'package:flutter/material.dart';

import '../../../core/widgets/hyner_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HynerMark(size: 84),
            const SizedBox(height: 24),
            Text(
              'Hyner',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
            ),
            const SizedBox(height: 36),
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Restoring your session',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
