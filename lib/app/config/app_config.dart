import 'package:firebase_core/firebase_core.dart';

enum AppEnvironment { development, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    this.firebaseOptions,
    this.googleServerClientId = '',
    this.issue,
  });

  final AppEnvironment environment;
  final FirebaseOptions? firebaseOptions;
  final String googleServerClientId;
  final String? issue;
  bool get isConfigured =>
      firebaseOptions != null &&
      googleServerClientId.isNotEmpty &&
      issue == null;

  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment(
      'HYNER_ENV',
      defaultValue: 'development',
    );
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const clientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    final environment = env == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;
    if (env != 'production' && env != 'development') {
      return AppConfig(
        environment: environment,
        issue: 'The application environment is invalid.',
      );
    }
    if ([
      apiKey,
      appId,
      senderId,
      projectId,
      clientId,
    ].any((value) => value.trim().isEmpty)) {
      return AppConfig(
        environment: environment,
        issue: 'This installation has not been connected to Hyner’s account service.',
      );
    }
    if (!clientId.endsWith('.apps.googleusercontent.com') ||
        !appId.startsWith('1:')) {
      return AppConfig(
        environment: environment,
        issue:
            'This installation has an invalid account-service configuration.',
      );
    }
    return AppConfig(
      environment: environment,
      firebaseOptions: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
      googleServerClientId: clientId,
    );
  }
}
