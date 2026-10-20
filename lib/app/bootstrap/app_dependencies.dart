import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/profile/domain/profile_repository.dart';
import '../config/app_config.dart';
import '../theme/appearance_repository.dart';

class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.profiles,
    required this.appearance,
    required this.config,
    this.initialTheme = ThemeMode.system,
    this.startupNotice,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final AppearanceRepository appearance;
  final AppConfig config;
  final ThemeMode initialTheme;
  final String? startupNotice;
}

final dependenciesProvider = Provider<AppDependencies>(
  (ref) => throw StateError(
    'Application dependencies must be initialized before launch.',
  ),
);

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(dependenciesProvider).initialTheme;

  Future<void> select(ThemeMode mode) async {
    await ref.read(dependenciesProvider).appearance.write(mode);
    state = mode;
  }
}
