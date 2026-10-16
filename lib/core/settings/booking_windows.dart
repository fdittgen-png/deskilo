// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2486 (S3 of #2483) -- the booking and check-in windows of one workspace,
// read from the settings registry. The pure booking functions take these as
// parameters; their defaults are the registry's own (SettingDefaults).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_settings.dart';
import 'setting_defaults.g.dart';
import 'settings.dart';

/// The windows a booking is checked in, reminded and walked up with.
class BookingWindows {
  const BookingWindows({
    this.checkInLeeway = const Duration(minutes: SettingDefaults.bookingCheckInLeewayMinutes),
    this.reminderLead = const Duration(minutes: SettingDefaults.bookingCheckInReminderLeadMinutes),
    this.reminderLookahead = const Duration(days: SettingDefaults.bookingCheckInReminderLookaheadDays),
    this.walkUpWindow = const Duration(minutes: SettingDefaults.bookingWalkUpWindowMinutes),
    this.walkUpFloor = const Duration(minutes: SettingDefaults.bookingWalkUpFloorMinutes),
  });

  /// The registry's own defaults (no settings reachable yet).
  static const defaults = BookingWindows();

  /// How early check-in opens before the start. A minute grid wider than
  /// this widens it to one grid step (`greatest(setting, step)`, as the
  /// server does).
  final Duration checkInLeeway;

  /// How long before a booking starts its reminder is shown.
  final Duration reminderLead;

  /// How far ahead a device schedules reminders (a guardrail, not edited).
  final Duration reminderLookahead;

  /// The stay booked on the spot, and the shortest stay.
  final Duration walkUpWindow;
  final Duration walkUpFloor;

  /// The windows [settings] state. A registry that predates a key (an older
  /// server) keeps that key's default.
  factory BookingWindows.fromSettings(SettingsSet settings) {
    Duration minutes(String key, int fallback) => Duration(
        minutes: settings.definitions.containsKey(key) ? settings.read<int>(key) : fallback);
    return BookingWindows(
      checkInLeeway:
          minutes('booking.check_in_leeway_minutes', SettingDefaults.bookingCheckInLeewayMinutes),
      reminderLead: minutes(
          'booking.check_in_reminder_lead_minutes', SettingDefaults.bookingCheckInReminderLeadMinutes),
      reminderLookahead: Duration(
          days: settings.definitions.containsKey('booking.check_in_reminder_lookahead_days')
              ? settings.read<int>('booking.check_in_reminder_lookahead_days')
              : SettingDefaults.bookingCheckInReminderLookaheadDays),
      walkUpWindow:
          minutes('booking.walk_up_window_minutes', SettingDefaults.bookingWalkUpWindowMinutes),
      walkUpFloor:
          minutes('booking.walk_up_floor_minutes', SettingDefaults.bookingWalkUpFloorMinutes),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BookingWindows &&
      other.checkInLeeway == checkInLeeway &&
      other.reminderLead == reminderLead &&
      other.reminderLookahead == reminderLookahead &&
      other.walkUpWindow == walkUpWindow &&
      other.walkUpFloor == walkUpFloor;

  @override
  int get hashCode =>
      Object.hash(checkInLeeway, reminderLead, reminderLookahead, walkUpWindow, walkUpFloor);
}

/// #2486 -- the active workspace's booking windows. While the settings load,
/// or when they cannot be reached, the registry defaults stand.
final bookingWindowsProvider = Provider<BookingWindows>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return settings == null ? BookingWindows.defaults : BookingWindows.fromSettings(settings);
});
