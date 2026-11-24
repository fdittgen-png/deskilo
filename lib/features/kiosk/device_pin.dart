// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/services.dart';

import '../../core/trace/trace_logger.dart';

/// Best-effort Android screen pinning for kiosk mode: while pinned, the
/// system blocks leaving the app (home/recents/notifications) — the pad
/// really can do nothing else. Escaping needs the system's unpin gesture
/// plus the device credential, or a restart. On platforms without the
/// channel (tests, desktop, iOS) this is a traced no-op; the route lock
/// and immersive mode still apply.
abstract final class KioskDevicePin {
  static const _channel = MethodChannel('deskilo/kiosk');

  static Future<void> pin() async {
    try {
      await _channel.invokeMethod<bool>('lock');
    } on Object catch (e, st) {
      // Pinning is an extra hardening layer, not a requirement: an absent
      // channel (tests, desktop) is expected, so it is noted, not an error.
      TraceLogger.instance.log(TraceLevel.debug, 'kiosk', 'pin unavailable', error: e, stackTrace: st);
    }
  }

  static Future<void> unpin() async {
    try {
      await _channel.invokeMethod<bool>('unlock');
    } on Object catch (e, st) {
      // See pin().
      TraceLogger.instance.log(TraceLevel.debug, 'kiosk', 'unpin unavailable', error: e, stackTrace: st);
    }
  }
}
