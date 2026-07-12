// SPDX-License-Identifier: MIT
//
// Pins the presence constants (#223, no-magic-numbers rule) and the pure
// online/offline resolver the member directory (#224) consumes.
import 'package:deskilo/core/presence/presence_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresenceRules', () {
    test('heartbeat interval is pinned to 2 minutes', () {
      expect(PresenceRules.heartbeatInterval, const Duration(minutes: 2));
    });

    test('online window is pinned to 5 minutes', () {
      expect(PresenceRules.onlineWindow, const Duration(minutes: 5));
    });

    test('the window survives at least one missed beat', () {
      expect(
        PresenceRules.onlineWindow,
        greaterThan(PresenceRules.heartbeatInterval * 2),
      );
    });
  });

  group('resolvePresence', () {
    final now = DateTime.utc(2026, 7, 11, 12, 0, 0);

    test('seen 4:59 ago is online', () {
      expect(
        resolvePresence(
          lastSeenAt: now.subtract(const Duration(minutes: 4, seconds: 59)),
          now: now,
        ),
        PresenceStatus.online,
      );
    });

    test('seen exactly 5:00 ago is offline (strictly less-than window)',
        () {
      expect(
        resolvePresence(
          lastSeenAt: now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        PresenceStatus.offline,
      );
    });

    test('seen 5:01 ago is offline', () {
      expect(
        resolvePresence(
          lastSeenAt: now.subtract(const Duration(minutes: 5, seconds: 1)),
          now: now,
        ),
        PresenceStatus.offline,
      );
    });

    test('never seen (null) is offline', () {
      expect(
        resolvePresence(lastSeenAt: null, now: now),
        PresenceStatus.offline,
      );
    });

    test('clock skew: a timestamp slightly in the future is online', () {
      expect(
        resolvePresence(
          lastSeenAt: now.add(const Duration(seconds: 30)),
          now: now,
        ),
        PresenceStatus.online,
      );
    });
  });
}
