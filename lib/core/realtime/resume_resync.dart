// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3098 (PERF-1) — when coming back to the app re-reads everything. A
// focus change (`inactive → resumed`, every alt-tab on web) is not an
// absence; only time spent out of sight past the workspace's
// `presence.resync_after_away_minutes` is. A lost live connection is
// detected by the channel supervisor, which resyncs on its own.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/active_settings.dart';
import '../settings/setting_defaults.g.dart';

const _key = 'presence.resync_after_away_minutes';

/// How long the app must have been out of sight before a resume resyncs.
/// The registry default stands while the settings load, or when a server
/// predates the key.
final resumeResyncAfterProvider = Provider<Duration>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return Duration(
    minutes: settings != null && settings.definitions.containsKey(_key)
        ? settings.read<int>(_key)
        : SettingDefaults.presenceResyncAfterAwayMinutes,
  );
});

/// Watches app lifecycle for the invalidator: while the app was out of
/// sight the realtime socket may have been paused by the OS with no error
/// ever surfacing, so coming back after [threshold] triggers a full
/// resync (#577). Kiosks that sleep overnight wake up fresh instead of
/// showing yesterday's plan. `inactive` (focus lost, a system sheet over
/// the app) never counts as away.
class ResumeResyncObserver with WidgetsBindingObserver {
  ResumeResyncObserver({
    required this.onResume,
    required this.now,
    required this.threshold,
  });

  final void Function() onResume;
  final DateTime Function() now;
  final Duration Function() threshold;

  DateTime? _awaySince;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _awaySince ??= now();
      case AppLifecycleState.resumed:
        final since = _awaySince;
        _awaySince = null;
        if (since != null && now().difference(since) >= threshold()) {
          onResume();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }
}
