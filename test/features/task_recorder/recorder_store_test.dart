// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the private store keeps each account's recordings apart,
// recovers what a crash left (a truncated last line is dropped, a bad
// checkpoint rolls back, a log without an end is "interrupted" and
// never "complete"), refuses a log from another version, purges past
// its retention, and reads everything back through the same validator
// an import uses.
import 'dart:io';

import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_log_backends.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/recording_fixtures.dart';

const _id = '0123456789abcdef0123456789abcdef';

void main() {
  Future<String> recordedLog(BookingJourney journey) async =>
      (await recordFixture(journey)).backend.logs.values.single.toString();

  test('a finished recording reads back as it was recorded', () async {
    final fixture = await recordFixture(BookingJourney.planConfirmed);
    final store = RecorderStore(
        backend: fixture.backend, namespace: canaryNamespace);
    final stored = (await store.read(_id))!;
    expect(stored.status, StoredStatus.ended);
    expect(stored.truncatedTail, isFalse);
    expect(stored.recording!.steps, fixture.recording.steps);
    expect(stored.recording!.completeness, Completeness.complete);
  });

  test('a truncated last line is dropped; the log reads as interrupted',
      () async {
    final log = await recordedLog(BookingJourney.planConfirmed);
    final lines = log.split('\n')..removeLast();
    // Cut the log in the middle of the sixth step, as a crash would.
    final cut = lines.indexWhere((l) => l.contains('"seq":6'));
    final truncated =
        '${lines.take(cut).join('\n')}\n${lines[cut].substring(0, 30)}';
    final stored = recoverRecordingLog(_id, truncated);
    expect(stored.status, StoredStatus.interrupted);
    expect(stored.truncatedTail, isTrue);
    expect(stored.recording!.steps.length, 5);
    expect(stored.recording!.completeness, Completeness.interrupted);
    expect(stored.recording!.endReason, isNull);
    // The open segment is closed at the last thing it saw.
    expect(stored.recording!.segments.last.endMs,
        stored.recording!.steps.last.elapsedMs);
  });

  test('a checkpoint that disagrees rolls back to the last good one', () {
    final store = RecorderStore(
        backend: MemoryRecorderLogBackend(),
        namespace: canaryNamespace,
        checkpointEvery: 2);
    expect(store.checkpointEvery, 2);
    const head = '{"t":"h","v":1,"id":"$_id","created":0,"scope":"x",'
        '"contract":1,"platform":"web","prerequisites":[]}';
    String step(int seq) => '{"t":"s","step":{"seq":$seq,"segment":0,'
        '"elapsed_ms":${seq * 10},"kind":"action",'
        '"surface":"reservations.reserve",'
        '"action":"reservations.open_reserve","action_version":1}}';
    final log = [
      head,
      '{"t":"g","seg":{"index":0,"start_ms":0}}',
      step(1),
      step(2),
      '{"t":"c","n":2,"last":2}',
      step(3),
      step(5), // a step went missing between 3 and 5
      '{"t":"c","n":4,"last":4}',
      '{"t":"e","reason":"stopped","completeness":"complete"}',
      '',
    ].join('\n');
    final stored = recoverRecordingLog(_id, log);
    expect(stored.truncatedTail, isTrue);
    expect(stored.recording!.steps.map((s) => s.seq), [1, 2]);
    expect(stored.status, StoredStatus.interrupted);
  });

  test('another version, another id or garbage is unreadable, not guessed',
      () async {
    final log = await recordedLog(BookingJourney.listRefused);
    expect(recoverRecordingLog(_id, log.replaceFirst('"v":1', '"v":2')).status,
        StoredStatus.unreadable);
    expect(recoverRecordingLog('f' * 32, log).status, StoredStatus.unreadable);
    expect(recoverRecordingLog(_id, 'not json\n').status,
        StoredStatus.unreadable);
    expect(recoverRecordingLog(_id, '').status, StoredStatus.unreadable);
    // A step edited on disk to carry a value is refused like an import.
    final tampered = log.replaceFirst(
        '"date_relation":"tomorrow"', '"date_relation":"$kCanaryMemberName"');
    final stored = recoverRecordingLog(_id, tampered);
    expect(stored.status, StoredStatus.unreadable);
    expect(stored.recording, isNull);
  });

  test('a missing recording is null; an interrupted one can be finalized',
      () async {
    final backend = MemoryRecorderLogBackend();
    final store = RecorderStore(backend: backend, namespace: canaryNamespace);
    expect(await store.read(_id), isNull);
    final clock = StepClock();
    final c = fixtureController(store, clock);
    await c.start(scope: canaryScope);
    clock.tick();
    c.record(RecorderActions.openReserve);
    await Future<void>.delayed(Duration.zero);
    // The app dies here: no stop.
    expect((await store.read(_id))!.status, StoredStatus.interrupted);
    await store.finalizeInterrupted(_id);
    final closed = (await store.read(_id))!;
    expect(closed.status, StoredStatus.ended);
    expect(closed.recording!.endReason, RecordingEndReason.interrupted);
    expect(closed.recording!.completeness, Completeness.interrupted);
  });

  test('each account sees only its own recordings', () async {
    final backend = MemoryRecorderLogBackend();
    final mine = RecorderStore(backend: backend, namespace: canaryNamespace);
    final theirs = RecorderStore(
        backend: backend,
        namespace: RecorderScope.accountNamespace(
            backendUrl: kCanaryUrl, userId: 'somebody-else'));
    final c = fixtureController(mine, StepClock());
    await c.start(scope: canaryScope);
    await c.stop();
    expect(await mine.list(), hasLength(1));
    expect(await theirs.list(), isEmpty);
    expect(() => mine.read('../../etc/passwd'), throwsArgumentError);
  });

  test('recordings past their retention are purged', () async {
    final backend = MemoryRecorderLogBackend();
    final old = RecorderStore(
        backend: backend,
        namespace: canaryNamespace,
        clock: FixedClock(DateTime.utc(2026, 8, 1)));
    final c = fixtureController(old, StepClock());
    await c.start(scope: canaryScope);
    await c.stop();
    final later = RecorderStore(
        backend: backend,
        namespace: canaryNamespace,
        clock: FixedClock(DateTime.utc(2026, 8, 20)));
    expect(await later.purgeExpired(), 0);
    final muchLater = RecorderStore(
        backend: backend,
        namespace: canaryNamespace,
        clock: FixedClock(DateTime.utc(2026, 9, 2)));
    expect(await muchLater.purgeExpired(), 1);
    expect(await muchLater.list(), isEmpty);
  });

  test('a writer past the store bound throws, and the controller stops',
      () async {
    final store = RecorderStore(
        backend: MemoryRecorderLogBackend(),
        namespace: canaryNamespace,
        limits: const RecordingLimits(maxBytes: 300));
    final clock = StepClock();
    // The controller's own byte limit is generous; the store's is not.
    final c = fixtureController(store, clock,
        limits: const RecordingLimits(maxBytes: 1 << 20));
    await c.start(scope: canaryScope);
    for (var i = 0; i < 10; i++) {
      clock.tick(1000);
      c.record(RecorderActions.openReserve);
    }
    final r = (await c.stop())!;
    expect(r.endReason, RecordingEndReason.storageFailed);
    expect(r.completeness, Completeness.partial);
  });

  group('real backends', () {
    test('files: append, list, read, delete, and no path from a key',
        () async {
      final dir = Directory.systemTemp.createTempSync('recorder');
      addTearDown(() => dir.deleteSync(recursive: true));
      final backend = FileRecorderLogBackend(directory: dir);
      final store = RecorderStore(backend: backend, namespace: canaryNamespace);
      final clock = StepClock();
      final c = fixtureController(store, clock);
      final r = await recordJourney(c, clock, BookingJourney.listRefused);
      final stored = (await store.list()).single;
      expect(stored.recording!.steps, r.steps);
      final bytes = dir.listSync().whereType<File>().single.readAsStringSync();
      for (final canary in [...privateCanaries, ...canaryFragments]) {
        expect(bytes.contains(canary), isFalse, reason: canary);
      }
      expect(() => backend.append('../escape', 'x'), throwsArgumentError);
      await store.delete(stored.id);
      expect(dir.listSync(), isEmpty);
    });

    test('browser storage: the same log, in shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final backend = PrefsRecorderLogBackend();
      final store = RecorderStore(backend: backend, namespace: canaryNamespace);
      final clock = StepClock();
      final c = fixtureController(store, clock);
      final r = await recordJourney(c, clock, BookingJourney.cancelledReview);
      expect((await store.list()).single.recording!.steps, r.steps);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getKeys().map(prefs.getString).join();
      for (final canary in [...privateCanaries, ...canaryFragments]) {
        expect(raw.contains(canary), isFalse, reason: canary);
      }
      await store.delete(_id);
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
