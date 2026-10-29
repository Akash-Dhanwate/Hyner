import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class LocalNotificationService with WidgetsBindingObserver {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  static const _channel = MethodChannel('hyner/notifications');
  static const _lowStockPrefix = 0x40000000;

  final _pending = <int, _QueuedNotification>{};
  AppLifecycleState? _lifecycleState;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on PlatformException {
      // The app stays usable if Android settings cannot be opened.
    } on MissingPluginException {
      // Notifications are available only on the native Android app.
    }
  }

  Future<void> activity({required String title, required String body}) async {
    final id = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;
    await _enqueue(_QueuedNotification(id: id, title: title, body: body));
  }

  Future<void> lowStock({
    required String sku,
    required String productName,
    required int quantity,
    required int reorderLevel,
  }) async {
    final hash = sku.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x00ffffff,
    );
    final id = _lowStockPrefix | hash;
    await _enqueue(
      _QueuedNotification(
        id: id,
        title: 'Low stock: $productName',
        body: '$quantity left · Reorder level $reorderLevel',
      ),
    );
  }

  Future<void> clearLowStock(String sku) async {
    final hash = sku.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x00ffffff,
    );
    final id = _lowStockPrefix | hash;
    _pending.remove(id);
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on PlatformException {
      // Clearing a stale alert is best effort.
    } on MissingPluginException {
      // Notifications are available only on the native Android app.
    }
  }

  Future<void> _enqueue(_QueuedNotification notification) async {
    _pending[notification.id] = notification;
    final state = _lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) {
      await _flush();
    }
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final queued = _pending.values.toList();
    _pending.clear();
    for (final notification in queued) {
      try {
        await _channel.invokeMethod<void>('show', {
          'id': notification.id,
          'title': notification.title,
          'body': notification.body,
        });
      } on PlatformException {
        // A disabled permission or channel should not interrupt the app.
      } on MissingPluginException {
        // Notifications are available only on the native Android app.
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flush());
    }
  }
}

class _QueuedNotification {
  const _QueuedNotification({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;
}
