import 'dart:async';

import 'package:go_router/go_router.dart';

/// Retains visited sections for Android Back; Home resets to the workspace root.
void openWorkspacePage(GoRouter router, String path) {
  if (router.state.uri.path == path) return;
  if (path == '/dashboard') {
    router.go(path);
  } else {
    unawaited(router.push<void>(path));
  }
}
