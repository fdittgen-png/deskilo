// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_badge_io.dart' if (dart.library.js_interop) 'app_badge_web.dart';

part 'app_badge.g.dart';

/// App-icon badge seam (#426/#444): the pending-confirmations count on
/// the launcher/home-screen/dock/taskbar icon — Android launchers, iOS,
/// macOS dock, Windows taskbar overlay, and installed web apps (Badging
/// API). Fakes in tests; best-effort everywhere (an unsupported surface
/// just no-ops).
abstract class AppBadge {
  Future<void> update(int count);
}

/// Which committed overlay asset a count maps to on Windows (#444);
/// null = clear the overlay. Pure so it is testable everywhere.
String? overlayAssetFor(int count) {
  if (count <= 0) return null;
  final name = count > 9 ? '9plus' : '$count';
  return 'assets/badges/badge_$name.ico';
}

@Riverpod(keepAlive: true)
AppBadge appBadge(Ref ref) => createAppBadge();
