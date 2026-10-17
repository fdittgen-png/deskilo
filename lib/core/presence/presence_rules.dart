// SPDX-License-Identifier: AGPL-3.0-or-later
import '../settings/setting_defaults.g.dart';

/// Presence tuning (#223), pinned by test (no magic numbers rule).
///
/// The heartbeat stamps `profiles.last_seen_at` every
/// [heartbeatInterval] while the app is foregrounded and signed in;
/// anyone stamped less than [onlineWindow] ago counts as online. The
/// window is deliberately more than twice the interval so one missed
/// beat (flaky network, doze) does not flicker a member offline.
abstract final class PresenceRules {
  static const Duration heartbeatInterval = Duration(minutes: 2);
  /// The registry's default of `presence.online_window_minutes` (#2486); a
  /// workspace's own value is passed to [resolvePresence].
  static const Duration onlineWindow =
      Duration(minutes: SettingDefaults.presenceOnlineWindowMinutes);
}

/// Derived presence of a member — there is no server-side state beyond
/// the `last_seen_at` timestamp (#223; no third-party presence service).
enum PresenceStatus { online, offline }

/// Pure resolver consumed by the member directory (#224): a profile is
/// online when its heartbeat is younger than [PresenceRules.onlineWindow].
///
/// Never-seen profiles (null) are offline. A `lastSeenAt` slightly in
/// the future (client/server clock skew) counts as online — its age is
/// below the window.
PresenceStatus resolvePresence({
  required DateTime? lastSeenAt,
  required DateTime now,
  Duration onlineWindow = PresenceRules.onlineWindow,
}) {
  if (lastSeenAt == null) return PresenceStatus.offline;
  return now.difference(lastSeenAt) < onlineWindow
      ? PresenceStatus.online
      : PresenceStatus.offline;
}
