// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the generator hook: the workbench reads the registered outputs
// through one provider (the registry #1866 fills),
// a generator answers availability by capability, and cancellation is
// cooperative and observable.
import 'dart:typed_data';

import 'package:deskilo/features/task_recorder/export/output_registry.dart';
import 'package:deskilo/features/task_recorder/package/task_output.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

class _Echo implements TaskOutputGenerator {
  @override
  String get id => 'echo';
  @override
  TaskOutputKind get kind => TaskOutputKind.storyboard;
  @override
  String get fileExtension => 'txt';
  @override
  Future<TaskOutputAvailability> availability() async =>
      const TaskOutputAvailable();
  @override
  Future<TaskOutputResult> generate(
    TaskOutputRequest request, {
    void Function(double fraction)? onProgress,
    TaskOutputCancel? cancel,
  }) async {
    if (cancel?.isCancelled ?? false) return const TaskOutputCancelled();
    onProgress?.call(1);
    return TaskOutputProduced(
      Uint8List.fromList('${request.recording.steps.length}'.codeUnits),
      'echo.txt',
    );
  }
}

void main() {
  test('the registry is the default; a test can register one', () async {
    final empty = ProviderContainer();
    addTearDown(empty.dispose);
    expect(
      empty.read(taskOutputGeneratorsProvider).map((g) => g.id),
      taskOutputGeneratorList().map((g) => g.id),
    );

    final c = ProviderContainer(
      overrides: [
        taskOutputGeneratorsProvider.overrideWithValue([_Echo()]),
      ],
    );
    addTearDown(c.dispose);
    final generator = c.read(taskOutputGeneratorsProvider).single;
    expect(await generator.availability(), isA<TaskOutputAvailable>());
    final recording = (await recordFixture(BookingJourney.cancelledReview))
        .recording;
    final request = TaskOutputRequest(recording: recording, languageCode: 'en');
    final produced = await generator.generate(request) as TaskOutputProduced;
    expect(String.fromCharCodes(produced.bytes), '${recording.steps.length}');
    final cancel = TaskOutputCancel()..cancel();
    expect(
      await generator.generate(request, cancel: cancel),
      isA<TaskOutputCancelled>(),
    );
  });
}
