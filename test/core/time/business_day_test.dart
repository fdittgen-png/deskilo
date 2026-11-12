// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 -- "today" about a business fact is the business's day. The instants
// are UTC, so the device's zone (the test machine's) never decides a date.
import 'package:deskilo/core/time/business_day_providers.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Clock implements Clock {
  _Clock(this.instant);
  DateTime instant;
  @override
  DateTime now() => instant;
}

final class _Scheduler implements DayBoundaryScheduler {
  final scheduled = <(DateTime, void Function())>[];
  int cancelled = 0;
  @override
  void Function() at(DateTime instant, void Function() fire) {
    final entry = (instant, fire);
    scheduled.add(entry);
    return () {
      cancelled++;
      scheduled.remove(entry);
    };
  }
}

void main() {
  // 23:30 UTC on 11 November: already the 12th in Zurich, still the 11th in
  // Los Angeles.
  final lateEvening = DateTime.utc(2026, 11, 11, 23, 30);

  test('two businesses at one instant each have their own day', () {
    final zurich = businessTodayAt(lateEvening, 'Europe/Zurich');
    final la = businessTodayAt(lateEvening, 'America/Los_Angeles');
    expect(zurich.date, DateTime(2026, 11, 12));
    expect(la.date, DateTime(2026, 11, 11));
    expect((zurich as KnownBusinessDay).nextBoundary,
        DateTime.utc(2026, 11, 12, 23));
    expect((la as KnownBusinessDay).nextBoundary,
        DateTime.utc(2026, 11, 12, 8));
  });

  test('a day with a clock change ends at its own midnight, not 24 h later',
      () {
    // Zurich springs forward on 28 March 2027: that day has 23 hours.
    final saturday = businessTodayAt(
            DateTime.utc(2027, 3, 27, 12), 'Europe/Zurich')
        as KnownBusinessDay;
    expect(saturday.nextBoundary, DateTime.utc(2027, 3, 27, 23));
    final sunday = businessTodayAt(saturday.nextBoundary, 'Europe/Zurich')
        as KnownBusinessDay;
    expect(sunday.date, DateTime(2027, 3, 28));
    expect(sunday.nextBoundary, DateTime.utc(2027, 3, 28, 22));
  });

  test('a missing or unknown zone is an unknown day, never the device\'s',
      () {
    expect(businessTodayAt(lateEvening, null), isA<UnknownBusinessDay>());
    expect(businessTodayAt(lateEvening, ''), isA<UnknownBusinessDay>());
    expect(businessTodayAt(lateEvening, 'Mars/Olympus'),
        isA<UnknownBusinessDay>());
    expect(businessTodayAt(lateEvening, 'Mars/Olympus').date, isNull);
  });

  test('the day moves at the business\'s midnight with no data change', () {
    final clock = _Clock(DateTime.utc(2026, 11, 11, 22, 59, 59));
    final scheduler = _Scheduler();
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      dayBoundarySchedulerProvider.overrideWithValue(scheduler),
    ]);
    addTearDown(container.dispose);
    final seen = <DateTime?>[];
    container.listen(businessTodayProvider('Europe/Zurich'),
        (_, next) => seen.add(next.date),
        fireImmediately: true);

    expect(seen, [DateTime(2026, 11, 11)]);
    expect(scheduler.scheduled.single.$1, DateTime.utc(2026, 11, 11, 23));

    clock.instant = DateTime.utc(2026, 11, 11, 23);
    scheduler.scheduled.single.$2();
    container.read(businessTodayProvider('Europe/Zurich'));

    expect(seen, [DateTime(2026, 11, 11), DateTime(2026, 11, 12)]);
    expect(scheduler.cancelled, 1, reason: 'the old schedule is disposed');
    expect(scheduler.scheduled.single.$1, DateTime.utc(2026, 11, 12, 23));
  });

  test('an unknown zone schedules nothing', () {
    final scheduler = _Scheduler();
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(_Clock(lateEvening)),
      dayBoundarySchedulerProvider.overrideWithValue(scheduler),
    ]);
    addTearDown(container.dispose);
    expect(container.read(businessTodayProvider(null)),
        isA<UnknownBusinessDay>());
    expect(scheduler.scheduled, isEmpty);
  });
}
