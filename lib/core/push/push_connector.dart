// SPDX-License-Identifier: 0BSD
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unifiedpush/unifiedpush.dart';

import '../trace/trace_logger.dart';

/// Thin seam over the UnifiedPush static API so [PushService] is testable
/// and non-Android platforms degrade to local notifications only (#72).
abstract class PushConnector {
  /// Wires the callbacks. Returns false when push is unavailable on this
  /// platform/device — the caller must then skip [register].
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  });

  /// True when a distributor (ntfy, NextPush, …) is ready to be used.
  Future<bool> hasDistributor();

  Future<void> register();
}

class UnifiedPushConnector implements PushConnector {
  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      await UnifiedPush.initialize(
        onNewEndpoint: (endpoint, instance) => onNewEndpoint(endpoint.url),
        onUnregistered: (instance) => onUnregistered(),
        onMessage: (message, instance) => onMessage(message.content),
      );
      return true;
    } catch (e, st) {
      // Push is best-effort (#86 boot doctrine): never let a missing
      // platform plugin disturb the app.
      debugPrint('UnifiedPush init failed: $e\n$st');
      TraceLogger.instance.warn('push', 'UnifiedPush init failed',
          error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> hasDistributor() async {
    try {
      return await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    } catch (e, st) {
      debugPrint('UnifiedPush distributor lookup failed: $e\n$st');
      // Benign on devices without any distributor installed — the app
      // simply stays local-notifications-only.
      TraceLogger.instance.warn('push', 'UnifiedPush distributor lookup failed',
          error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<void> register() async {
    try {
      await UnifiedPush.register();
    } catch (e, st) {
      debugPrint('UnifiedPush register failed: $e\n$st');
      TraceLogger.instance.error('push', 'UnifiedPush register failed',
          error: e, stackTrace: st);
    }
  }
}
