// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2486 (S3 of #2483) -- the two windows the member directory reads: how
// long a heartbeat keeps someone online and how far ahead it shows the next
// booking. Registry values (`presence.online_window_minutes`,
// `directory.upcoming_window_days`); the defaults are the registry's own.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_settings.dart';
import 'setting_defaults.g.dart';
import 'settings.dart';

class DirectoryWindows {
  const DirectoryWindows({
    this.onlineWindow = const Duration(minutes: SettingDefaults.presenceOnlineWindowMinutes),
    this.upcomingWindow = const Duration(days: SettingDefaults.directoryUpcomingWindowDays),
  });

  static const defaults = DirectoryWindows();

  final Duration onlineWindow;
  final Duration upcomingWindow;

  /// A registry that predates a key (an older server) keeps its default.
  factory DirectoryWindows.fromSettings(SettingsSet settings) {
    const online = 'presence.online_window_minutes';
    const upcoming = 'directory.upcoming_window_days';
    return DirectoryWindows(
      onlineWindow: Duration(
          minutes: settings.definitions.containsKey(online)
              ? settings.read<int>(online)
              : SettingDefaults.presenceOnlineWindowMinutes),
      upcomingWindow: Duration(
          days: settings.definitions.containsKey(upcoming)
              ? settings.read<int>(upcoming)
              : SettingDefaults.directoryUpcomingWindowDays),
    );
  }
}

/// #2486 -- the active workspace's directory windows; the registry defaults
/// stand while the settings load or when they cannot be reached.
final directoryWindowsProvider = Provider<DirectoryWindows>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return settings == null ? DirectoryWindows.defaults : DirectoryWindows.fromSettings(settings);
});
