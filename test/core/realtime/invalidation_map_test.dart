// SPDX-License-Identifier: 0BSD
//
// #577 — the ONE table → providers map both freshness paths share.
// These tests pin the contract that used to drift when realtime and
// manual invalidation each kept a private copy.
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every realtime table has a live mapping — a published table '
      'nobody invalidates for is dead weight on the socket', () {
    for (final table in realtimeTables) {
      expect(invalidationFor(table).providers, isNotEmpty,
          reason: '$table is bound on the channel but invalidates '
              'nothing — either map it or stop subscribing to it');
    }
  });

  test('the resync sweep loses nothing: iterating mappedTables reaches '
      'every provider any single table reaches', () {
    final viaResync = {
      for (final table in mappedTables)
        ...invalidationFor(table).providers,
    };
    for (final table in realtimeTables) {
      for (final provider in invalidationFor(table).providers) {
        expect(viaResync, contains(provider),
            reason: 'a resync would miss $provider (reached via $table)');
      }
    }
  });

  test('a local booking mutation refreshes the account position too — '
      'the #512 drift the shared map exists to prevent', () {
    final reached = {
      for (final table in bookingMutationTables)
        ...invalidationFor(table).providers,
    };
    expect(reached, contains(myAccountProvider));
    expect(reached, contains(myStatementProvider));
    expect(reached, contains(myLedgerProvider));
    expect(reached, contains(reservationsForDayProvider));
    expect(reached, contains(myUpcomingReservationsProvider));
  });

  // #572 gave `members` the bust because a membership change widens what
  // RLS lets this user read. #1084 is the other half of the same rule and
  // the more obvious one: a table whose ROWS the plan cache stores must
  // bust it, or the editing device is the only one that sees the change
  // for the next ten minutes.
  //
  // The tables deliberately NOT on this list are the high-frequency ones
  // — reservations above all. Those never enter the plan cache, so
  // busting on them would be pure thrash.
  const bustingTables = {
    'members',
    'levels',
    'offices',
    'desks',
    'seats',
    'plan_images',
    'accessories',
    'seat_accessories',
  };

  test('every table the plan cache holds busts it (#572, #1084)', () {
    for (final table in bustingTables) {
      expect(invalidationFor(table).bustsPlanCache, isTrue,
          reason: '$table is cached in the plan bundle — a change to it '
              'must not stay invisible for the TTL');
    }
    for (final table in realtimeTables.where((t) => !bustingTables.contains(t))) {
      expect(invalidationFor(table).bustsPlanCache, isFalse,
          reason: '$table must not thrash the plan disk cache');
    }
  });

  test('an unmapped table invalidates nothing instead of crashing', () {
    expect(invalidationFor('no_such_table').providers, isEmpty);
  });

  test('reconnect backoff: 2s, 4s, 8s, 16s, then 30s forever', () {
    expect(
      [for (var a = 0; a < 6; a++) reconnectDelay(a).inSeconds],
      [2, 4, 8, 16, 30, 30],
    );
  });

  test('the resume observer fires on RESUMED only — backgrounding must '
      'not trigger refetch storms', () {
    var calls = 0;
    final observer = ResumeResyncObserver(() => calls++);
    observer
      ..didChangeAppLifecycleState(AppLifecycleState.paused)
      ..didChangeAppLifecycleState(AppLifecycleState.inactive)
      ..didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(calls, 0);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(calls, 1);
  });
}
