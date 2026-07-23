// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    } catch (e, st) {
      // trace-exempt: pinning is an extra hardening layer, not a
      // requirement — absent channel (tests/desktop) is expected.
      debugPrint('kiosk pin unavailable: $e\n$st');
    }
  }

  static Future<void> unpin() async {
    try {
      await _channel.invokeMethod<bool>('unlock');
    } catch (e, st) {
      // trace-exempt: see pin().
      debugPrint('kiosk unpin unavailable: $e\n$st');
    }
  }
}
