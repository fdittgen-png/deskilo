// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the committed JSON fixtures ARE what the real controller
// records for the four booking journeys, byte for byte, and each reads
// back through the canonical validator to the same recording. Stream
// consumers (#1866, #1867, #1872, #1876) test against these
// files; when the producer changes, this fails until they are
// regenerated with UPDATE_RECORDER_FIXTURES=1.
import 'dart:io';

import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  final update = Platform.environment['UPDATE_RECORDER_FIXTURES'] == '1';

  for (final journey in BookingJourney.values) {
    test('${journey.file} is what the controller records', () async {
      final (:recording, backend: _) = await recordFixture(journey);
      final text = '${encodeRecordingText(recording)}\n';
      final file = File('${fixturesDir.path}/${journey.file}.json');
      if (update) file.writeAsStringSync(text);
      expect(text, file.readAsStringSync(),
          reason: 'regenerate with UPDATE_RECORDER_FIXTURES=1');

      final decoded = decodeRecordingText(text);
      expect(decoded.issues, isEmpty);
      expect(decoded.runnable, isTrue);
      expect(encodeRecordingText(decoded.recording!),
          encodeRecordingText(recording));
    });
  }

  test('the journeys say what happened, in order', () async {
    final plan = (await recordFixture(BookingJourney.planConfirmed)).recording;
    expect(plan.steps.map((s) => s.action ?? s.outcome).toList(), [
      RecorderActions.openReserve,
      RecorderActions.selectDate,
      RecorderActions.selectPeriod,
      RecorderActions.selectResource,
      RecorderActions.changeBookingField, // two commits, one step
      RecorderActions.confirmBooking,
      RecorderOutcomes.bookingConfirmed,
      RecorderActions.viewDetails,
      RecorderActions.back,
    ]);
    expect(plan.completeness, Completeness.complete);
    final attempt = plan.steps[5];
    final result = plan.steps[6];
    expect(attempt.state, ObservationState.attempted);
    expect(result.op, attempt.op);
    expect(result.state, ObservationState.confirmed);

    final refused = (await recordFixture(BookingJourney.listRefused)).recording;
    expect(refused.steps.last.state, ObservationState.refused);
    expect(refused.steps.last.payload.values, {'refusal': 'conflict'});
    expect(refused.steps.any((s) => s.payload.values['view_mode'] == 'list'),
        isTrue);

    final cancelled =
        (await recordFixture(BookingJourney.cancelledReview)).recording;
    expect(cancelled.steps.where((s) => s.op != null), isEmpty);
    expect(cancelled.steps.last.kind, StepKind.annotation);

    final unknown =
        (await recordFixture(BookingJourney.unknownOutcome)).recording;
    expect(unknown.steps.last.state, ObservationState.outcomeUnknown);
  });

  test('no fixture carries a canary', () {
    for (final journey in BookingJourney.values) {
      final text = fixtureText(journey.file);
      for (final c in [...privateCanaries, ...canaryFragments]) {
        expect(text.contains(c), isFalse, reason: '${journey.file}: $c');
      }
    }
  });

  group('hostile fixtures', () {
    const refused = {
      'reject_unknown_key': RecordingIssueCode.unknownKey,
      'reject_unsafe_payload': RecordingIssueCode.unsafePayload,
      'reject_orphan_outcome': RecordingIssueCode.orphanOutcome,
      'reject_future_schema': RecordingIssueCode.unsupportedSchema,
      'reject_claims_complete': RecordingIssueCode.inconsistent,
    };
    for (final MapEntry(key: name, value: code) in refused.entries) {
      test('$name is refused with $code', () {
        final decoded = decodeRecordingText(fixtureText(name));
        expect(decoded.accepted, isFalse);
        expect(decoded.issues.map((i) => i.code), contains(code));
      });
    }

    test('an unknown action is kept as an unrecorded, unrunnable step', () {
      final decoded = decodeRecordingText(fixtureText('degrade_unknown_action'));
      expect(decoded.accepted, isTrue);
      expect(decoded.runnable, isFalse);
      final kinds = decoded.recording!.steps.map((s) => s.kind).toList();
      expect(kinds, [StepKind.action, StepKind.unrecorded, StepKind.unrecorded]);
      expect(decoded.recording!.steps[1].payload.isEmpty, isTrue);
    });
  });
}
