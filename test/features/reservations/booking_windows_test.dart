// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2486 (S3 of #2483): the booking and check-in windows are registry
// settings. Defaults reproduce today's behaviour; a changed value changes
// the behaviour, exactly at the edge; the minute grid still widens the
// allowance (greatest(setting, step)) on the real grids only.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/presence/presence_rules.dart';
import 'package:deskilo/core/settings/booking_windows.dart';
import 'package:deskilo/core/settings/directory_windows.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/members/domain/directory_status.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:deskilo/features/reservations/domain/check_in_reminders.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/walk_up_window.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

/// The registry the app ships, with [overrides] as a workspace's values.
SettingsSet _settings([Map<String, Object> overrides = const {}]) {
  final rows = jsonDecode(File('assets/instance/settings_registry.json').readAsStringSync()) as List;
  final defs = [for (final r in rows) SettingDefinition.fromJson(r)];
  final base = SettingsSet.defaults(defs);
  return SettingsSet(base.definitions, {...base.effective, ...overrides});
}

Reservation _booking(DateTime start, {int minutes = 60}) => Reservation(
      id: 'r1',
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      memberId: 'member-1',
      startsAt: start,
      endsAt: start.add(Duration(minutes: minutes)),
      status: ReservationStatus.reserved,
    );

void main() {
  final start = DateTime.utc(2026, 7, 7, 10);
  Duration leeway(Map<String, Object> o) => BookingWindows.fromSettings(_settings(o)).checkInLeeway;

  group('defaults reproduce today', () {
    test('the registry defaults are the old literals', () {
      final w = BookingWindows.fromSettings(_settings());
      expect(w, BookingWindows.defaults);
      expect(w.checkInLeeway, const Duration(minutes: 15));
      expect(w.reminderLead, const Duration(minutes: 15));
      expect(w.reminderLookahead, const Duration(days: 7));
      expect(w.walkUpWindow, const Duration(hours: 4));
      expect(w.walkUpFloor, const Duration(minutes: 15));
      expect(BookingIntentLedger.cap, 20);
      expect(BillingRules.maxAdvanceDays, 28);
      expect(PresenceRules.onlineWindow, const Duration(minutes: 5));
      expect(DirectoryReservationRules.upcomingWindow, const Duration(days: 14));
      expect(BookingGranularity.defaultStepMinutes, 15);
      expect(DirectoryWindows.fromSettings(_settings()).onlineWindow, PresenceRules.onlineWindow);
    });

    test('a registry that predates the keys keeps the defaults', () {
      final old = SettingsSet.defaults(const []);
      expect(BookingWindows.fromSettings(old), BookingWindows.defaults);
      expect(DirectoryWindows.fromSettings(old).upcomingWindow, DirectoryReservationRules.upcomingWindow);
    });
  });

  group('check-in leeway', () {
    final r = _booking(start);
    bool open(DateTime now, Duration l, [BookingGranularity? g]) =>
        r.checkInWindowOpen(now, granularity: g, leeway: l);

    test('the default opens 15 minutes before, to the minute', () {
      expect(open(start.subtract(const Duration(minutes: 15)), leeway({})), isTrue);
      expect(open(start.subtract(const Duration(minutes: 16)), leeway({})), isFalse);
    });

    test('leeway 5 refuses at 6 minutes and opens at exactly 5', () {
      final l = leeway({'booking.check_in_leeway_minutes': 5});
      expect(l, const Duration(minutes: 5));
      expect(open(start.subtract(const Duration(minutes: 6)), l, BookingGranularity.minutes5), isFalse);
      expect(open(start.subtract(const Duration(minutes: 5)), l, BookingGranularity.minutes5), isTrue);
      expect(open(start.subtract(const Duration(minutes: 6)), l), isFalse);
    });

    test('a 15-minute grid keeps 6 minutes inside the allowance', () {
      const l = Duration(minutes: 5);
      final now = start.subtract(const Duration(minutes: 6));
      expect(open(now, l, BookingGranularity.minutes15), isTrue);
      expect(open(start.subtract(const Duration(minutes: 16)), l, BookingGranularity.minutes15), isFalse);
      expect(r.checkInOpensAt(granularity: BookingGranularity.minutes15, leeway: l),
          start.subtract(const Duration(minutes: 15)));
      expect(r.checkInOpensAt(granularity: BookingGranularity.minutes5, leeway: l),
          start.subtract(const Duration(minutes: 5)));
    });

    test('flexible and hours do not widen: the server enforces no grid there', () {
      const l = Duration(minutes: 5);
      final now = start.subtract(const Duration(minutes: 6));
      expect(open(now, l, BookingGranularity.flexible), isFalse);
      expect(r.checkInOpensAt(granularity: BookingGranularity.flexible, leeway: l),
          start.subtract(const Duration(minutes: 5)));
    });

    test('a longer setting wins over a short grid', () {
      const l = Duration(minutes: 30);
      expect(open(start.subtract(const Duration(minutes: 30)), l, BookingGranularity.minutes15), isTrue);
      expect(open(start.subtract(const Duration(minutes: 31)), l, BookingGranularity.minutes15), isFalse);
    });

    test('two workspaces read two values (no global state)', () {
      final a = leeway({'booking.check_in_leeway_minutes': 5});
      final b = leeway({});
      expect([a, b], [const Duration(minutes: 5), const Duration(minutes: 15)]);
    });
  });

  group('reminders', () {
    final now = DateTime.utc(2026, 7, 7, 8);
    List<ReminderRequest> derive(BookingWindows w, DateTime at) => upcomingCheckInReminders(
          reservations: [_booking(at)],
          myMemberId: 'member-1',
          now: now,
          targetNames: const {'seat-1': 'A1'},
          titleOf: (t, s) => 't',
          bodyOf: (t, s) => 'b',
          lookahead: w.reminderLookahead,
          before: w.reminderLead,
        );

    test('the lead time follows the setting', () {
      final at = now.add(const Duration(hours: 3));
      final w = BookingWindows.fromSettings(_settings({'booking.check_in_reminder_lead_minutes': 30}));
      expect(derive(w, at).single.remindAt, at.subtract(const Duration(minutes: 30)));
      expect(derive(BookingWindows.defaults, at).single.remindAt, at.subtract(const Duration(minutes: 15)));
    });

    test('the lookahead is the guardrail', () {
      expect(derive(BookingWindows.defaults, now.add(const Duration(days: 7, minutes: 1))), isEmpty);
      expect(derive(BookingWindows.defaults, now.add(const Duration(days: 7))), hasLength(1));
    });
  });

  group('walk-up window', () {
    final now = DateTime(2026, 7, 7, 9);
    test('the stay and the floor follow the setting', () {
      final def = walkUpWindow(BookingGranularity.minutes15, now);
      expect(def.end.difference(def.start), const Duration(hours: 4));
      final w = BookingWindows.fromSettings(_settings({'booking.walk_up_window_minutes': 90}));
      final short = walkUpWindow(BookingGranularity.minutes15, now, windows: w);
      expect(short.end.difference(short.start), const Duration(minutes: 90));
    });
  });

  group('directory and presence', () {
    final now = DateTime.utc(2026, 7, 7, 12);
    test('online window: 5 minutes by default, the setting otherwise', () {
      final seen = now.subtract(const Duration(minutes: 6));
      expect(resolvePresence(lastSeenAt: seen, now: now), PresenceStatus.offline);
      final w = DirectoryWindows.fromSettings(_settings({'presence.online_window_minutes': 10}));
      expect(resolvePresence(lastSeenAt: seen, now: now, onlineWindow: w.onlineWindow), PresenceStatus.online);
    });

    test('upcoming window: day 14 shows, day 15 does not; the setting moves the edge', () {
      ReservationInfo? info(Duration w, int days) => resolveReservationInfo(
            memberId: 'member-1',
            reservations: [_booking(now.add(Duration(days: days)))],
            now: now,
            upcomingWindow: w,
          );
      expect(info(DirectoryReservationRules.upcomingWindow, 14), isA<UpcomingReservation>());
      expect(info(DirectoryReservationRules.upcomingWindow, 15), isNull);
      final w = DirectoryWindows.fromSettings(_settings({'directory.upcoming_window_days': 30}));
      expect(info(w.upcomingWindow, 15), isA<UpcomingReservation>());
    });
  });

  test('the generated defaults equal the registry rows', () {
    final s = _settings();
    expect(s.read<int>('booking.check_in_leeway_minutes'), SettingDefaults.bookingCheckInLeewayMinutes);
    expect(s.read<int>('billing.max_advance_days'), SettingDefaults.billingMaxAdvanceDays);
  });
}
