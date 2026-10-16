// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - the core used by a host that is not Deskilo: an inspection
// checklist, a fake writer, no application types.

import 'package:deskilo_task_recording/deskilo_task_recording.dart';
import 'package:test/test.dart';

import '../example/inspection_checklist.dart';

class _MemoryWriter implements RecordingWriter {
  _MemoryWriter({this.failAfter});
  final int? failAfter;
  final steps = <RecordedStep>[];
  final segments = <RecordingSegment>[];
  RecordingEndReason? ended;
  Completeness? completeness;

  @override
  Future<void> segment(RecordingSegment segment) async => segments.add(segment);

  @override
  Future<void> step(RecordedStep step) async {
    if (failAfter != null && steps.length >= failAfter!) {
      throw StateError('disk full');
    }
    steps.add(step);
  }

  @override
  Future<void> end(RecordingEndReason reason, Completeness c) async {
    ended = reason;
    completeness = c;
  }

  @override
  Future<void> discard() async => steps.clear();
}

RecordedStep _attempt(int seq, String op) => RecordedStep(
  seq: seq,
  segment: 0,
  elapsedMs: seq * 100,
  kind: StepKind.action,
  surface: Inspection.screen,
  action: Inspection.submit,
  actionVersion: 1,
  op: op,
  state: ObservationState.attempted,
);

RecordedStep _outcome(int seq, String op, String outcome, ObservationState s) =>
    RecordedStep(
      seq: seq,
      segment: 0,
      elapsedMs: seq * 100,
      kind: StepKind.observation,
      surface: Inspection.screen,
      op: op,
      state: s,
      outcome: outcome,
    );

TaskRecording _recording(
  List<RecordedStep> steps, {
  RecordingEndReason? end = RecordingEndReason.stopped,
}) => TaskRecording(
  actionContractVersion: 1,
  platform: RecordingPlatform.unknown,
  steps: steps,
  segments: [const RecordingSegment(index: 0, startMs: 0, endMs: 1000)],
  endReason: end,
);

void main() {
  final catalogue = inspectionCatalogue();

  test('the catalogue itself is sound', () {
    expect(catalogue.problems(inspectionFields.keys.toSet()), isEmpty);
  });

  test('attempt then confirmed outcome exports, decodes and is runnable', () {
    final r = _recording([
      _attempt(1, 'op1'),
      _outcome(2, 'op1', Inspection.reportFiled, ObservationState.confirmed),
    ]);
    expect(r.completeness, Completeness.complete);
    final back = decodeRecordingText(
      encodeRecordingText(r),
      registry: catalogue,
    );
    expect(back.issues.map((i) => i.toString()), isEmpty);
    expect(back.runnable, isTrue);
    expect(back.recording!.steps.length, 2);
    expect(recordingDigest(back.recording!), recordingDigest(r));
  });

  test('a refused outcome decodes; an unanswered attempt is partial', () {
    final refused = _recording([
      _attempt(1, 'op1'),
      _outcome(2, 'op1', Inspection.reportRefused, ObservationState.refused),
    ]);
    expect(
      decodeRecordingText(
        encodeRecordingText(refused),
        registry: catalogue,
      ).runnable,
      isTrue,
    );
    final open = _recording([_attempt(1, 'op1')]);
    expect(open.completeness, Completeness.partial);
    expect(open.unansweredAttempts, hasLength(1));
  });

  test('an action another catalogue named is not runnable', () {
    final text = encodeRecordingText(_recording([_attempt(1, 'op1')]));
    final other = inspectionCatalogue();
    final foreign = ActionRegistry(
      contractVersion: 1,
      surfaces: other.surfaces,
      actions: const [],
      outcomes: const [],
      prerequisites: const [],
      safeFields: inspectionFields,
      acceptsPage: (_) => false,
    );
    final result = decodeRecordingText(text, registry: foreign);
    expect(result.runnable, isFalse);
  });

  test('payloads are minimized before they exist', () {
    final p = SafePayload.minimize(
      {'verdict'},
      {'verdict': 'Ana Smith, serial 4711', 'serial': '4711'},
      fields: inspectionFields,
    );
    expect(p.values, {'verdict': withheldValue});
    expect(
      SafePayload.parse(
        {'verdict'},
        {'verdict': 'Ana Smith'},
        fields: inspectionFields,
      ),
      isNull,
    );
  });

  test('a page the host cannot open is refused in a v3 recording', () {
    final step = RecordedStep(
      seq: 1,
      segment: 0,
      elapsedMs: 0,
      kind: StepKind.action,
      surface: Inspection.screen,
      action: Inspection.check,
      actionVersion: 1,
      page: '/not-registered',
      payload: SafePayload.minimize(
        {'verdict'},
        {'verdict': 'pass'},
        fields: inspectionFields,
      ),
    );
    final text = encodeRecordingText(_recording([step]));
    expect(decodeRecordingText(text, registry: catalogue).runnable, isFalse);
  });

  test('oversized and malformed input is refused without parsing', () {
    expect(
      decodeRecordingText(
        'x' * 2000,
        registry: catalogue,
        limits: const RecordingLimits(maxBytes: 100),
      ).accepted,
      isFalse,
    );
    expect(
      decodeRecordingText('{not json', registry: catalogue).accepted,
      isFalse,
    );
    final deep = '[' * 5000 + ']' * 5000;
    expect(decodeRecordingText(deep, registry: catalogue).accepted, isFalse);
  });

  test('a stalled disk costs completeness, never the caller', () async {
    final w = _MemoryWriter(failAfter: 1);
    await w.step(_attempt(1, 'op1'));
    await expectLater(w.step(_attempt(2, 'op2')), throwsA(isA<StateError>()));
    await w.end(RecordingEndReason.storageFailed, Completeness.partial);
    expect(w.completeness, Completeness.partial);
    expect(w.steps, hasLength(1));
  });
}
