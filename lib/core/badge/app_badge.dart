// SPDX-License-Identifier: 0BSD
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../trace/trace_logger.dart';

part 'app_badge.g.dart';

/// App-icon badge seam (#426): the pending-confirmations count on the
/// launcher/home-screen icon — Android launchers, iOS, macOS. Fakes in
/// tests; best-effort in production (unsupported launchers just no-op).
abstract class AppBadge {
  Future<void> update(int count);
}

class AppBadgePlusBadge implements AppBadge {
  @override
  Future<void> update(int count) async {
    try {
      if (!await AppBadgePlus.isSupported()) return;
      await AppBadgePlus.updateBadge(count);
    } catch (e, st) {
      // Best-effort: a launcher without badge support must never
      // disturb the app.
      debugPrint('app badge update failed: $e\n$st');
      TraceLogger.instance
          .warn('badge', 'app badge update failed', error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
AppBadge appBadge(Ref ref) => AppBadgePlusBadge();
