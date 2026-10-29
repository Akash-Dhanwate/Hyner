import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/local_notification_service.dart';
import 'app/bootstrap/app_dependencies.dart';
import 'app/bootstrap/bootstrap.dart';
import 'app/hyner_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalNotificationService.instance.initialize();
  final dependencies = await bootstrap();
  runApp(
    ProviderScope(
      overrides: [dependenciesProvider.overrideWithValue(dependencies)],
      child: const HynerApp(),
    ),
  );
}
