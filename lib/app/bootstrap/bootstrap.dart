import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/profile/data/firestore_profile_repository.dart';
import '../config/app_config.dart';
import '../theme/appearance_repository.dart';
import 'app_dependencies.dart';

Future<AppDependencies> bootstrap() async {
  final appearance = LocalAppearanceRepository();
  var initialTheme = ThemeMode.system;
  String? notice;
  try {
    initialTheme = await appearance.read();
  } catch (_) {
    notice = 'Your saved appearance could not be loaded. The device theme is being used.';
  }
  final config = AppConfig.fromEnvironment();
  if (config.isConfigured) {
    try {
      await Firebase.initializeApp(options: config.firebaseOptions)
          .timeout(const Duration(seconds: 20));
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(persistenceEnabled: false);
      return AppDependencies(
        auth: FirebaseAuthRepository(
          FirebaseAuth.instance,
          config.googleServerClientId,
        ),
        profiles: FirestoreProfileRepository(firestore),
        appearance: appearance,
        config: config,
        initialTheme: initialTheme,
        startupNotice: notice,
      );
    } catch (_) {
      // Present a setup failure. Never substitute a user or a local session.
      return AppDependencies(
        auth: UnconfiguredAuthRepository(),
        profiles: UnconfiguredProfileRepository(),
        appearance: appearance,
        config: AppConfig(
          environment: config.environment,
          issue: 'Account services could not start. Close and reopen Hyner. If this continues, contact support.',
        ),
        initialTheme: initialTheme,
        startupNotice: notice,
      );
    }
  }
  return AppDependencies(
    auth: UnconfiguredAuthRepository(),
    profiles: UnconfiguredProfileRepository(),
    appearance: appearance,
    config: config,
    initialTheme: initialTheme,
    startupNotice: notice,
  );
}
