// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 (i18n I13) -- the business day as a reactive value per time zone: it
// schedules its next local midnight (a calendar boundary, so a clock change
// moves nothing), recomputes when the app comes back to the front, and
// disposes its schedule with it. Readers watch it; no screen keeps a timer
// of its own.
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../lifecycle/app_foreground.dart';
import 'business_day.dart';
import 'clock.dart';

export 'business_day.dart';

part 'business_day_providers.g.dart';

/// Runs a callback once at an instant; answers how to cancel it.
abstract interface class DayBoundaryScheduler {
  void Function() at(DateTime instant, void Function() fire);
}

/// The real scheduler: one [Timer] until the instant, as [clock] counts.
final class _TimerDayBoundaryScheduler implements DayBoundaryScheduler {
  const _TimerDayBoundaryScheduler(this.clock);

  final Clock clock;

  @override
  void Function() at(DateTime instant, void Function() fire) {
    final wait = instant.difference(clock.now());
    final timer = Timer(wait.isNegative ? Duration.zero : wait, fire);
    return timer.cancel;
  }
}

@Riverpod(keepAlive: true)
DayBoundaryScheduler dayBoundaryScheduler(Ref ref) =>
    _TimerDayBoundaryScheduler(ref.watch(clockProvider));

/// The business day in [timezone], kept current: it recomputes at the zone's
/// next midnight and whenever the app comes back to the front.
@riverpod
BusinessToday businessToday(Ref ref, String? timezone) {
  ref.watch(appForegroundProvider);
  final today = businessTodayAt(ref.watch(clockProvider).now(), timezone);
  if (today case KnownBusinessDay(:final nextBoundary)) {
    ref.onDispose(ref
        .watch(dayBoundarySchedulerProvider)
        .at(nextBoundary, ref.invalidateSelf));
  }
  return today;
}
