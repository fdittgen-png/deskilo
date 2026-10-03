// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — privacy before write, proved end to end: synthetic private
// values fed in at the capture boundary (declared fields, undeclared
// fields, targets, surfaces, unknown actions, errors thrown by the
// store) are absent from the live snapshot, the bytes on disk, the
// recovered recording, the plain-JSON export and the trace log. The
// package (#1872), the document (#1866), the video (#1879) and the
// support bundle extend this chain from the same canaries.
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  void expectClean(String where, String text) {
    for (final c in [...privateCanaries, ...canaryFragments]) {
      expect(text.contains(c), isFalse, reason: '$where carries "$c"');
    }
  }

  for (final journey in BookingJourney.values) {
    test('${journey.file}: event -> store -> recovery -> export -> logs',
        () async {
      TraceLogger.instance = TraceLogger();
      final backend = MemoryRecorderLogBackend();
      final store = RecorderStore(backend: backend, namespace: canaryNamespace);
      final clock = StepClock();
      final c = fixtureController(store, clock);
      final recording = await recordJourney(c, clock, journey);

      // Stray events a careless call site might send on the way.
      await c.start(scope: canaryScope);
      c.record(RecorderActions.selectResource,
          target: kCanaryReservationId, payload: canaryPayload());
      c.record('members.open_$kCanaryMemberName', payload: canaryPayload());
      c.unrecorded(surface: kCanaryUrl);
      c.outcome(null, RecorderOutcomes.bookingConfirmed,
          payload: canaryPayload());
      await c.stop();

      expectClean('the snapshot', encodeRecordingText(recording));
      final bytes = backend.logs.values.map((b) => b.toString()).join();
      expectClean('the stored bytes', bytes);
      for (final stored in await store.list()) {
        expect(stored.status, StoredStatus.ended);
        expectClean('the recovered recording',
            encodeRecordingText(stored.recording!));
      }
      expectClean('the export', encodeRecordingText(recording));
      expectClean(
          'the trace log',
          TraceLogger.instance.entries
              .map((e) => '${e.area} ${e.message} ${e.error}')
              .join('\n'));
      await c.dispose();
    });
  }

  test('the canaries would be caught: the check is not vacuous', () {
    // The same scan over a text that does carry one must fail.
    const leaked = '{"note":"$kCanaryMessage"}';
    expect(privateCanaries.any(leaked.contains), isTrue);
  });
}
