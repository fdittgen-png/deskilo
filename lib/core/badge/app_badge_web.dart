// SPDX-License-Identifier: 0BSD
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';
import 'app_badge.dart';

AppBadge createAppBadge() => WebAppBadge();

/// The Badging API (#444): live on INSTALLED web apps (Chromium PWAs,
/// Safari 16.4+ home-screen apps); a plain browser tab has no icon to
/// badge and the feature detection below turns this into a no-op.
class WebAppBadge implements AppBadge {
  @override
  Future<void> update(int count) async {
    try {
      final navigator = globalContext.getProperty('navigator'.toJS);
      if (navigator == null || !(navigator as JSObject).has('setAppBadge')) {
        return;
      }
      if (count > 0) {
        navigator.callMethod('setAppBadge'.toJS, count.toJS);
      } else {
        navigator.callMethod('clearAppBadge'.toJS);
      }
    } catch (e, st) {
      debugPrint('web badge update failed: $e\n$st');
      TraceLogger.instance
          .warn('badge', 'web badge update failed', error: e, stackTrace: st);
    }
  }
}
