// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — one codec reads every recording, and an imported one is
// untrusted: oversized, non-JSON, wrong-format, future-schema,
// out-of-order, backwards-in-time, overlong and unknown-keyed input is
// refused before it becomes a recording; nothing in it is executed or
// resolved; an edited version names its source and may never claim more
// completeness than a stopped recording earns.
import 'dart:convert';

import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

Map<String, Object?> _fixture(String name) =>
    (jsonDecode(fixtureText(name)) as Map).cast<String, Object?>();

List<Map<String, Object?>> _steps(Map<String, Object?> json) =>
    (json['steps']! as List).cast<Map<String, Object?>>();

RecordingIssueCode? _firstCode(Object? json) {
  final r = decodeRecording(json);
  return r.accepted ? null : r.issues.first.code;
}

void main() {
  const base = 'booking_plan_confirmed';

  test('an oversized text is refused before it is parsed', () {
    final text = fixtureText(base);
    final r = decodeRecordingText(text,
        limits: RecordingLimits(maxBytes: text.length - 1));
    expect(r.issues.single.code, RecordingIssueCode.tooLarge);
    expect(decodeRecordingText('{"format": ').issues.single.code,
        RecordingIssueCode.notJson);
    expect(_firstCode([1, 2]), RecordingIssueCode.notAnObject);
  });

  test('the wrong format or a future schema is refused', () {
    expect(_firstCode(_fixture(base)..['format'] = 'other.recording'),
        RecordingIssueCode.wrongFormat);
    expect(_firstCode(_fixture(base)..['schema_version'] = 0),
        RecordingIssueCode.unsupportedSchema);
  });

  test('order, time and limits are enforced', () {
    final swapped = _fixture(base);
    final steps = _steps(swapped);
    steps[2]['seq'] = 1;
    expect(_firstCode(swapped), RecordingIssueCode.sequence);

    final backwards = _fixture(base);
    _steps(backwards)[3]['elapsed_ms'] = 1;
    expect(_firstCode(backwards), RecordingIssueCode.time);

    final tooMany = decodeRecording(_fixture(base),
        limits: const RecordingLimits(maxSteps: 3));
    expect(tooMany.issues.first.code, RecordingIssueCode.tooMany);

    final longTitle = _fixture(base)..['title'] = 'x' * 500;
    expect(_firstCode(longTitle), RecordingIssueCode.tooLong);

    final control = _fixture(base)..['title'] = 'Book\u0007';
    expect(_firstCode(control), RecordingIssueCode.badValue);
  });

  test('a field a kind does not use is refused', () {
    final noteOnAction = _fixture(base);
    _steps(noteOnAction)[0]['note'] = kCanaryMessage;
    expect(_firstCode(noteOnAction), RecordingIssueCode.inconsistent);

    final targetNotDeclared = _fixture(base);
    _steps(targetNotDeclared)[4]['target'] = kCanaryMemberName;
    expect(_firstCode(targetNotDeclared), RecordingIssueCode.badValue);

    final opOnSelect = _fixture(base);
    _steps(opOnSelect)[0]['op'] = 'op7';
    expect(_firstCode(opOnSelect), RecordingIssueCode.inconsistent);
  });

  test('an outcome may answer only its own attempt, once', () {
    final twice = _fixture(base);
    final steps = _steps(twice);
    final outcome = Map<String, Object?>.of(steps[6])..['seq'] = 100;
    outcome['elapsed_ms'] = 99999;
    steps.add(outcome);
    expect(_firstCode(twice), RecordingIssueCode.orphanOutcome);

    final wrongState = _fixture(base);
    _steps(wrongState)[6]['state'] = 'refused';
    expect(_firstCode(wrongState), RecordingIssueCode.inconsistent);
  });

  test('a recording may say less than it earned, never more', () {
    final humble = _fixture(base)..['completeness'] = 'partial';
    expect(decodeRecording(humble).accepted, isTrue);
    final live = _fixture(base)
      ..remove('end_reason')
      ..['completeness'] = 'partial';
    expect(_firstCode(live), RecordingIssueCode.inconsistent);
  });

  test('an edited version names a source digest; a source never does', () {
    final source = decodeRecording(_fixture(base)).recording!;
    final digest = recordingDigest(source);
    expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(recordingDigest(decodeRecording(_fixture(base)).recording!), digest,
        reason: 'the digest is stable across reads');

    final edited = _fixture(base)
      ..['kind'] = 'edited'
      ..['source_digest'] = digest;
    // Removing the details step keeps the source's word on completeness.
    _steps(edited).removeAt(7);
    final r = decodeRecording(edited);
    expect(r.accepted, isTrue);
    expect(r.recording!.kind, RecordingKind.edited);
    expect(r.recording!.sourceDigest, digest);

    expect(_firstCode(_fixture(base)..['source_digest'] = digest),
        RecordingIssueCode.inconsistent);
    expect(_firstCode(_fixture(base)..['kind'] = 'edited'),
        RecordingIssueCode.inconsistent);
  });

  test('an authored step is labelled as authored and survives the codec', () {
    final json = _fixture('booking_cancelled_review');
    final note = _steps(json).last;
    note['origin'] = 'authored';
    final r = decodeRecording(json);
    expect(r.recording!.steps.last.origin, StepOrigin.authored);
    expect(encodeStep(r.recording!.steps.last)['origin'], 'authored');
  });
}
