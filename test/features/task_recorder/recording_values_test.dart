// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a recording keeps the values of what was entered or chosen ONLY
// when the person started it to capture them. Off (the default), no value
// reaches the model, the store or the export — the existing canary guarantee
// is untouched. On, the values travel in the typed channel, the file is
// schema 2 and says so, the store recovers them after a crash, an older
// reader refuses it by design, and a file cannot carry values it does not
// declare.
import 'dart:convert';

import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/step_values.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

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

  StepValues date(String iso) => StepValues.of({'date': TextValue(iso)});

  test('off by default: values are dropped, the file has form references and carries '
      'none', () async {
    await c.start(scope: canaryScope);
    expect(c.capturesValues, isFalse);
    c.record(
      RecorderActions.selectDate,
      payload: {'date_relation': 'today'},
      values: date('2026-10-06'),
    );
    final r = (await c.stop())!;
    expect(r.capturesValues, isFalse);
    expect(r.steps.single.values.isEmpty, isTrue);
    final text = encodeRecordingText(r);
    expect(text.contains('values'), isFalse);
    expect(text.contains('2026-10-06'), isFalse);
    expect(jsonDecode(text)['schema_version'], 3);
    // The stored log never held it either.
    expect(backend.logs.values.join().contains('2026-10-06'), isFalse);
  });

  test(
    'on: the values are kept, the file has references and values and says so',
    () async {
      await c.start(scope: canaryScope, captureValues: true);
      expect(c.capturesValues, isTrue);
      c.record(
        RecorderActions.selectDate,
        payload: {'date_relation': 'today'},
        values: date('2026-10-06'),
      );
      final r = (await c.stop())!;
      expect(r.capturesValues, isTrue);
      final json = jsonDecode(encodeRecordingText(r)) as Map;
      expect(json['schema_version'], 3);
      expect(json['values_mode'], 'captured');
      expect(((json['steps'] as List).single as Map)['values'], {
        'date': '2026-10-06',
      });
      // And it reads back identically.
      final back = decodeRecordingText(encodeRecordingText(r));
      expect(back.accepted, isTrue);
      expect(back.recording!.steps.single.values, date('2026-10-06'));
      expect(back.recording!.capturesValues, isTrue);
    },
  );

  test('a field committed again with the SAME value is one step; with another '
      'value it is a new one', () async {
    await c.start(scope: canaryScope, captureValues: true);
    StepValues v(String s) => StepValues.of({'value': TextValue(s)});
    c.record(RecorderActions.uiCommitField, target: 'unkeyed', values: v('a'));
    c.record(RecorderActions.uiCommitField, target: 'unkeyed', values: v('a'));
    c.record(RecorderActions.uiCommitField, target: 'unkeyed', values: v('b'));
    final values = [for (final s in c.snapshot!.steps) s.values];
    expect(values, [v('a'), v('b')]);
  });

  test(
    'a crash does not lose them: the store recovers values and the mode',
    () async {
      await c.start(scope: canaryScope, captureValues: true);
      c.record(
        RecorderActions.selectDate,
        payload: {'date_relation': 'today'},
        values: date('2026-10-06'),
      );
      await pumpEventQueue();
      final stored = (await store.list()).single;
      expect(stored.recording, isNotNull);
      expect(stored.recording!.capturesValues, isTrue);
      expect(stored.recording!.steps.single.values, date('2026-10-06'));
    },
  );

  test('the readable transcript carries the values, redacted ones only as '
      'their length', () async {
    await c.start(scope: canaryScope, captureValues: true);
    c.record(
      RecorderActions.selectDate,
      payload: {'date_relation': 'today'},
      values: date('2026-10-06'),
    );
    c.record(
      RecorderActions.uiCommitField,
      target: 'unkeyed',
      values: StepValues.of({'value': const RedactedValue(7)}),
    );
    final r = (await c.stop())!;
    final text = recordingTranscript(null, r);
    expect(text, contains('date: 2026-10-06'));
    expect(text, contains('value: not kept (7 characters)'));
  });

  group('a file cannot carry more than the recorder would keep', () {
    Map<String, Object?> file({
      int schema = 2,
      String? mode = 'captured',
      Object? values,
    }) => {
      'format': 'deskilo.task-recording',
      'schema_version': schema,
      'action_contract_version': 1,
      'platform': 'android',
      'kind': 'source',
      'values_mode': ?mode,
      'prerequisites': const [],
      'segments': [
        {'index': 0, 'start_ms': 0, 'end_ms': 10},
      ],
      'steps': [
        {
          'seq': 1,
          'segment': 0,
          'elapsed_ms': 1,
          'kind': 'action',
          'surface': RecorderSurfaces.reserve,
          'action': RecorderActions.selectDate,
          'action_version': 1,
          'payload': {'date_relation': 'today'},
          'values': ?values,
        },
      ],
      'end_reason': 'stopped',
      'completeness': 'complete',
    };

    test('values in a recording that does not declare them are refused', () {
      final r = decodeRecording(
        file(mode: null, values: {'date': '2026-10-06'}),
      );
      expect(r.accepted, isFalse);
      expect(
        r.issues.map((i) => i.code),
        contains(RecordingIssueCode.inconsistent),
      );
    });

    test('the mode in a schema-1 file is refused', () {
      expect(decodeRecording(file(schema: 1)).accepted, isFalse);
    });

    test('a value of another shape is refused as unsafe', () {
      for (final bad in [
        {
          'date': ['x'],
        },
        {'Bad Key': 'x'},
        {
          'date': {'nested': 1},
        },
        {'date': 'x' * 241},
      ]) {
        final r = decodeRecording(file(values: bad));
        expect(r.accepted, isFalse, reason: '$bad');
        expect(
          r.issues.map((i) => i.code),
          contains(RecordingIssueCode.unsafePayload),
        );
      }
    });

    test('a well-formed schema-2 file is accepted', () {
      expect(
        decodeRecording(file(values: {'date': '2026-10-06'})).accepted,
        isTrue,
      );
    });
  });
}
