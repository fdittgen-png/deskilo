// SPDX-License-Identifier: 0BSD
import 'dart:io';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import '../trace/trace_logger.dart';
import 'app_badge.dart';

AppBadge createAppBadge() => Platform.isWindows
    ? WindowsTaskbarBadge()
    : Platform.isLinux
        ? NoopAppBadge()
        : AppBadgePlusBadge(); // Android launchers, iOS, macOS dock

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

/// Windows taskbar overlay (#444): numbered committed .ico overlays,
/// 9+ past nine, cleared at zero.
class WindowsTaskbarBadge implements AppBadge {
  @override
  Future<void> update(int count) async {
    try {
      final asset = overlayAssetFor(count);
      if (asset == null) {
        await WindowsTaskbar.resetOverlayIcon();
        return;
      }
      await WindowsTaskbar.setOverlayIcon(
        ThumbnailToolbarAssetIcon(asset),
        tooltip: '$count',
      );
    } catch (e, st) {
      debugPrint('taskbar badge update failed: $e\n$st');
      TraceLogger.instance.warn('badge', 'taskbar badge update failed',
          error: e, stackTrace: st);
    }
  }
}

class NoopAppBadge implements AppBadge {
  @override
  Future<void> update(int count) async {}
}
