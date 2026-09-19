// SPDX-License-Identifier: 0BSD
//
// #1375 — one Demo session, and the reset that replaces it.
//
// ADR 0028 put Demo at the repository seam, with the whole session living
// in a [DemoFixture]. That choice decides what a reset is: not a cleanup
// of eleven repositories in the right order, but a NEW fixture and a new
// scope. The old object graph is dropped whole.
//
// **The fence is the object graph, not a flag.** A mutation that was
// already in flight when the reset happened still holds a reference to
// the repositories of the OLD fixture, so it completes into a graph
// nothing reads any more and cannot corrupt the new one. There is no
// window in which a late write lands in the fresh dataset, because a
// late write has nowhere to land. Repeated or concurrent resets are safe
// for the same reason: each one only ever replaces the current state with
// a fixture built from the canonical dataset.
//
// **Demo state does not survive a restart, deliberately.** Persisting it
// would mean a serialisation format for every repository — the broad new
// framework ADR 0028 exists to avoid — and it would hand a returning
// visitor their own half-finished experiment instead of the product. The
// session lasts as long as the app is open, and Reset is always one tap
// away inside it.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'demo_fixture.dart';

part 'demo_session.g.dart';

/// The data one Demo session runs on, and which session it is.
class DemoSession {
  const DemoSession({required this.fixture, required this.generation});

  /// Every repository this session reads and writes.
  final DemoFixture fixture;

  /// 0 for the session a visitor lands in, one more for each reset.
  ///
  /// The scope is keyed on it, so a reset disposes the widget tree that
  /// held the old fixture rather than asking every screen to refresh.
  final int generation;
}

/// The owner of the current session. It lives ABOVE the Demo scope: a
/// provider inside the scope would be disposed by the very reset it was
/// asked to perform.
@Riverpod(keepAlive: true)
class DemoSessionController extends _$DemoSessionController {
  @override
  DemoSession build() =>
      DemoSession(fixture: DemoFixture.build(), generation: 0);

  /// Restores the canonical dataset.
  ///
  /// The new fixture is seeded at the same instant as the first one, so
  /// "today" means the same day it meant when the visitor arrived and the
  /// bookings they were looking at come back where they were.
  void reset() {
    final seededAt = state.fixture.seededAt;
    state = DemoSession(
      fixture: DemoFixture.build(now: seededAt),
      generation: state.generation + 1,
    );
  }
}
