// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the recorder observes and never governs: start, pause,
// resume, stop, discard and restart keep one causal timeline per epoch;
// a late outcome never reaches the next recording; a scope change ends
// the recording before anything from the new scope enters; a failing,
// full or stalled store makes the recording partial and leaves the
// command it observes exactly as it was; limits end it truthfully.
import 'dart:async';

import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/recording_sink.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

/// A sink whose writes can fail or stall on demand.
class FlakySink implements RecordingSink, RecordingWriter {
  int failAfter = 1 << 30;
  Completer<void>? stall;
  bool refuseBegin = false;
  final writes = <String>[];
  bool discarded = false;

  @override
  Future<RecordingWriter> begin(RecordingHeader header) async {
    if (refuseBegin) throw StateError('no space');
    writes.add('begin');
    return this;
  }

  Future<void> _write(String what) async {
    if (stall != null) await stall!.future;
    if (writes.length >= failAfter) throw StateError('disk full $kCanaryPassword');
    writes.add(what);
  }

  @override
  Future<void> segment(RecordingSegment segment) => _write('segment');
  @override
  Future<void> step(RecordedStep step) => _write('step');
  @override
  Future<void> end(RecordingEndReason reason, Completeness completeness) =>
      _write('end');
  @override
  Future<void> discard() async => discarded = true;
}

void main() {
  late StepClock clock;
  late MemoryRecorderLogBackend backend;
  late RecorderStore store;
  late RecorderController c;

  setUp(() {
    clock = StepClock();
    backend = MemoryRecorderLogBackend();
    store = RecorderStore(backend: backend, namespace: canaryNamespace);
    c = fixtureController(store, clock);
  });

  tearDown(() => c.dispose());

  /// What an ordinary booking command does; the recorder must not
  /// change how many times it runs or what it returns.
  var commandRuns = 0;
  String runCommand() {
    commandRuns++;
    return 'booked';
  }

  test('nothing is recorded before an explicit start', () async {
    c.record(RecorderActions.openReserve);
    expect(c.attempt(RecorderActions.confirmBooking), isNull);
    expect(c.snapshot, isNull);
    expect(backend.logs, isEmpty);
  });

  test('a synchronous command yields attempt THEN outcome, once', () async {
    await c.start(scope: canaryScope);
    commandRuns = 0;
    final token = c.attempt(RecorderActions.confirmBooking,
        payload: {'for_whom': 'self'});
    final result = runCommand();
    c.outcome(token, RecorderOutcomes.bookingConfirmed);
    c.outcome(token, RecorderOutcomes.bookingRefused); // a duplicate answer
    expect(result, 'booked');
    expect(commandRuns, 1);
    final steps = c.snapshot!.steps;
    expect(steps.map((s) => s.state), [
      ObservationState.attempted,
      ObservationState.confirmed,
    ]);
    expect(steps[1].op, steps[0].op);
  });

  test('a thrown command is recorded as outcome unknown and still throws',
      () async {
    await c.start(scope: canaryScope);
    final token = c.attempt(RecorderActions.confirmBooking);
    Object? caught;
    try {
      throw StateError('server said no');
    } catch (e) {
      caught = e;
      c.outcome(token, RecorderOutcomes.bookingUnknown);
    }
    expect(caught, isA<StateError>());
    expect(c.snapshot!.steps.last.state, ObservationState.outcomeUnknown);
  });

  test('pause leaves a visible gap; resume opens a new segment', () async {
    await c.start(scope: canaryScope);
    clock.tick();
    c.record(RecorderActions.openReserve);
    c.pause();
    clock.tick();
    c.record(RecorderActions.selectDate, payload: {'date_relation': 'today'});
    c.resume();
    clock.tick();
    c.record(RecorderActions.selectPeriod, payload: {'period': 'morning'});
    final r = (await c.stop())!;
    expect(r.steps.map((s) => s.action), [
      RecorderActions.openReserve,
      RecorderActions.selectPeriod,
    ]);
    expect(r.segments.length, 2);
    expect(r.segments[0].endMs, 400);
    expect(r.segments[1].startMs, 800);
    expect(r.steps.last.segment, 1);
    expect(r.completeness, Completeness.complete);
    final stored = (await store.list()).single;
    expect(stored.status, StoredStatus.ended);
    expect(stored.recording!.segments, r.segments);
  });

  test('a late outcome after stop and restart never enters the new one',
      () async {
    await c.start(scope: canaryScope);
    final token = c.attempt(RecorderActions.confirmBooking);
    final first = (await c.stop())!;
    expect(first.completeness, Completeness.partial,
        reason: 'an unanswered attempt is not a complete task');

    await c.start(scope: canaryScope);
    expect(c.epoch, greaterThan(token!.epoch));
    c.outcome(token, RecorderOutcomes.bookingConfirmed); // arrives late
    final second = (await c.stop())!;
    expect(second.steps, isEmpty);
  });

  test('discard throws the recording away, on disk too; late results drop',
      () async {
    await c.start(scope: canaryScope);
    final token = c.attempt(RecorderActions.confirmBooking);
    await c.discard();
    c.outcome(token, RecorderOutcomes.bookingConfirmed);
    expect(c.state, RecorderState.idle);
    expect(c.snapshot, isNull);
    expect(await store.list(), isEmpty);
  });

  test('a scope change ends the recording before the new scope enters',
      () async {
    await c.start(scope: canaryScope);
    c.record(RecorderActions.openReserve);
    // Same user id, another installation: another scope.
    final elsewhere = RecorderScope.of(
        backendUrl: 'https://other.invalid', userId: kCanaryUserId);
    expect(elsewhere, isNot(canaryScope));
    c.scopeChanged(canaryScope); // the same scope changes nothing
    expect(c.state, RecorderState.recording);
    c.scopeChanged(elsewhere);
    c.record(RecorderActions.selectDate, payload: {'date_relation': 'today'});
    final r = (await c.stop())!;
    expect(r.endReason, RecordingEndReason.scopeChanged);
    expect(r.completeness, Completeness.partial);
    expect(r.steps.length, 1);

    // Signing out is a scope change too.
    await c.start(scope: canaryScope);
    c.scopeChanged(null);
    expect(c.status.endReason, RecordingEndReason.scopeChanged);
  });

  test('rapid taps and rebuilds are one step; field commits coalesce',
      () async {
    await c.start(scope: canaryScope);
    for (var i = 0; i < 5; i++) {
      c.record(RecorderActions.openReserve);
      clock.tick(10);
    }
    for (var i = 0; i < 20; i++) {
      clock.tick(1000);
      c.record(RecorderActions.changeBookingField, target: 'time');
    }
    c.record(RecorderActions.changeBookingField, target: 'repeat');
    // Two command attempts are two attempts, however fast.
    c.attempt(RecorderActions.confirmBooking);
    c.attempt(RecorderActions.confirmBooking);
    final steps = c.snapshot!.steps;
    expect(steps.length, 5);
    expect(steps.where((s) => s.isAttempt).map((s) => s.op), ['op1', 'op2']);
  });

  test('the recorder\'s own controls are never recorded', () async {
    await c.start(scope: canaryScope);
    c.record(RecorderActions.recorderControl);
    c.unrecorded(surface: RecorderSurfaces.recorderControls);
    expect(c.snapshot!.steps, isEmpty);
  });

  test('protected and unknown surfaces leave markers, not contents',
      () async {
    await c.start(scope: canaryScope);
    c.excluded(ProtectedSurface.payment);
    c.excluded(ProtectedSurface.payment);
    c.record('payments.enter_card', payload: {'card': kCanaryIban});
    c.unrecorded(surface: 'somewhere.$kCanaryUrl');
    final steps = c.snapshot!.steps;
    expect(steps.map((s) => s.kind),
        [StepKind.excluded, StepKind.unrecorded]);
    expect(steps.first.protectedCategory, ProtectedSurface.payment);
    expect(steps.last.surface, isNull);
  });

  test('a note is the person\'s own, bounded and labelled', () async {
    await c.start(scope: canaryScope, title: '  Book\u0000 a desk  ');
    c.annotate('x' * 2000);
    c.annotate('   ');
    final r = c.snapshot!;
    expect(r.title, 'Book  a desk');
    expect(r.steps.single.kind, StepKind.annotation);
    expect(r.steps.single.note!.length, const RecordingLimits().maxNoteLength);
  });

  group('limits end the recording, truthfully', () {
    test('steps', () async {
      c = fixtureController(store, clock,
          limits: const RecordingLimits(maxSteps: 3));
      await c.start(scope: canaryScope);
      for (var i = 0; i < 5; i++) {
        clock.tick(1000);
        c.record(RecorderActions.openReserve);
      }
      expect(c.status.endReason, RecordingEndReason.limitReached);
      expect(c.snapshot!.steps.length, 3);
      expect(c.snapshot!.completeness, Completeness.partial);
    });

    test('duration', () async {
      c = fixtureController(store, clock,
          limits: const RecordingLimits(maxDuration: Duration(seconds: 1)));
      await c.start(scope: canaryScope);
      clock.tick(1500);
      c.record(RecorderActions.openReserve);
      expect(c.status.endReason, RecordingEndReason.limitReached);
      expect(c.snapshot!.steps, isEmpty);
    });

    test('bytes', () async {
      c = fixtureController(store, clock,
          limits: const RecordingLimits(maxBytes: 400));
      await c.start(scope: canaryScope);
      for (var i = 0; i < 10; i++) {
        clock.tick(1000);
        c.record(RecorderActions.openReserve);
      }
      expect(c.status.endReason, RecordingEndReason.limitReached);
      expect(c.snapshot!.steps.length, lessThan(10));
    });

    test('segments', () async {
      c = fixtureController(store, clock,
          limits: const RecordingLimits(maxSegments: 2));
      await c.start(scope: canaryScope);
      c
        ..pause()
        ..resume()
        ..pause()
        ..resume();
      expect(c.status.endReason, RecordingEndReason.limitReached);
    });
  });

  group('a failing store never touches the task', () {
    test('a full disk ends the recording as partial; commands run once',
        () async {
      TraceLogger.instance = TraceLogger();
      final sink = FlakySink()..failAfter = 3;
      c = fixtureController(sink, clock);
      await c.start(scope: canaryScope);
      commandRuns = 0;
      for (var i = 0; i < 6; i++) {
        clock.tick(1000);
        final token = c.attempt(RecorderActions.confirmBooking);
        expect(runCommand(), 'booked');
        c.outcome(token, RecorderOutcomes.bookingConfirmed);
        await Future<void>.delayed(Duration.zero);
      }
      expect(commandRuns, 6);
      expect(c.status.endReason, RecordingEndReason.storageFailed);
      expect((await c.stop())!.completeness, Completeness.partial);
      // The trace says it failed, and says nothing the error carried.
      final log = TraceLogger.instance.entries
          .map((e) => '${e.message} ${e.error}')
          .join('\n');
      expect(log, contains('recording stopped'));
      expect(log, isNot(contains(kCanaryPassword)));
    });

    test('a stalled disk is a bounded queue, then a stop', () async {
      final sink = FlakySink()..stall = Completer<void>();
      c = fixtureController(sink, clock,
          limits: const RecordingLimits(maxQueuedWrites: 8));
      await c.start(scope: canaryScope);
      for (var i = 0; i < 50; i++) {
        clock.tick(1000);
        c.record(RecorderActions.openReserve);
      }
      expect(c.status.endReason, RecordingEndReason.storageFailed);
      expect(c.snapshot!.steps.length, lessThan(10));
      sink.stall!.complete();
    });

    test('a store that will not open refuses the start, quietly', () async {
      final sink = FlakySink()..refuseBegin = true;
      c = fixtureController(sink, clock);
      expect(await c.start(scope: canaryScope), isFalse);
      expect(c.state, RecorderState.idle);
      expect(c.attempt(RecorderActions.confirmBooking), isNull);
    });

    test('a stop whose end line fails is partial, not complete', () async {
      final sink = FlakySink();
      c = fixtureController(sink, clock);
      await c.start(scope: canaryScope);
      c.record(RecorderActions.openReserve);
      await Future<void>.delayed(Duration.zero);
      sink.failAfter = sink.writes.length + 1; // the segment close passes
      final r = (await c.stop())!;
      expect(r.endReason, RecordingEndReason.storageFailed);
      expect(r.completeness, Completeness.partial);
    });
  });

  test('a second start while live is refused; an ended one restarts clean',
      () async {
    expect(await c.start(scope: canaryScope), isTrue);
    expect(await c.start(scope: canaryScope), isFalse);
    c.record(RecorderActions.openReserve);
    await c.stop();
    expect(await c.start(scope: canaryScope), isTrue);
    expect(c.snapshot!.steps, isEmpty);
    expect(c.snapshot!.segments.single.startMs, 0);
  });

  test('changes announce each state for the indicator', () async {
    final seen = <RecorderState>[];
    final sub = c.changes.listen((s) => seen.add(s.state));
    await c.start(scope: canaryScope);
    c
      ..pause()
      ..resume();
    await c.stop();
    await sub.cancel();
    expect(seen.toSet(), {
      RecorderState.recording,
      RecorderState.paused,
      RecorderState.ended,
    });
  });
}
