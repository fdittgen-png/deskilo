// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// The one seam through which the app reads "now".
///
/// Widget code that calls `DateTime.now()` directly is untestable in the
/// only way that matters: it agrees with the calendar on the machine that
/// runs it. Two tests here asserted the literal month name and a
/// period-bound seeded record; they passed for three weeks and both went
/// red at the 2026-08-01 boundary with no commit in between. A time bomb
/// is not a regression, and bumping the string only resets the fuse.
///
/// Read the clock through [clockProvider] in anything a test will pump.
/// [WorkspaceTime] stays the authority on *which* zone an instant is
/// rendered in — this decides *when* it is.
abstract interface class Clock {
  DateTime now();
}

/// The real clock. The app's default; never used in a widget test.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock stopped at one instant, so a test asserting "August 2026"
/// still means it in September.
final class FixedClock implements Clock {
  const FixedClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();
