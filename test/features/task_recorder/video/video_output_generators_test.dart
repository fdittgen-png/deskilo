// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the video and its captions as registered workbench outputs.
//
// Invariant: the registry offers one video generator (`mp4`) and one
// caption generator (`vtt`), whose extensions map to video/mp4 and
// text/vtt; the MP4 is available exactly when the encoder's probe says
// so; both read the reviewed storyboard (or a fresh one) and refuse a
// stale one; the MP4 maps cancel, unsupported and failure onto the
// contract's results without producing bytes; the VTT is the caption
// track of the same timeline. The encoder is the Dart fake.
import 'dart:convert';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/export/output_registry.dart';
import 'package:deskilo/features/task_recorder/package/task_output.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/features/task_recorder/video/captions.dart';
import 'package:deskilo/features/task_recorder/video/video_output_generators.dart';
import 'package:deskilo/features/task_recorder/video/video_timeline.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/recording_fixtures.dart';
import 'fake_video_encoder.dart';

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('the registry offers mp4 and vtt with their MIME types', () {
    final byKind = {for (final g in taskOutputGeneratorList()) g.kind: g};
    expect(byKind[TaskOutputKind.video]!.id, 'mp4');
    expect(byKind[TaskOutputKind.captions]!.id, 'vtt');
    expect(
      mimeTypeFor('x.${byKind[TaskOutputKind.video]!.fileExtension}'),
      'video/mp4',
    );
    expect(
      mimeTypeFor('x.${byKind[TaskOutputKind.captions]!.fileExtension}'),
      'text/vtt',
    );
  });

  test('the MP4 is available exactly where the encoder answers', () async {
    expect(
      await Mp4OutputGenerator(encoder: FakeVideoEncoder()).availability(),
      isA<TaskOutputAvailable>(),
    );
    expect(
      await Mp4OutputGenerator(encoder: FakeVideoEncoder(supported: false))
          .availability(),
      isA<TaskOutputUnsupported>().having(
        (u) => u.reason,
        'reason',
        TaskOutputReason.unsupportedPlatform,
      ),
    );
  });

  test('the VTT is the caption track of the same timeline', () async {
    final r = _fixture(BookingJourney.listRefused);
    final sb = buildStoryboard(r, l);
    final result = await const VttOutputGenerator().generate(
      TaskOutputRequest(recording: r, languageCode: 'en', storyboard: sb),
    );
    final produced = result as TaskOutputProduced;
    expect(produced.suggestedName, endsWith('.vtt'));
    expect(utf8.decode(produced.bytes), buildVtt(buildTimeline(r, sb, l)));
  });

  test('a stale storyboard is refused by both', () async {
    final stale = buildStoryboard(_fixture(BookingJourney.planConfirmed), l);
    final request = TaskOutputRequest(
      recording: _fixture(BookingJourney.listRefused),
      languageCode: 'en',
      storyboard: stale,
    );
    for (final g in [
      const VttOutputGenerator(),
      Mp4OutputGenerator(encoder: FakeVideoEncoder()),
    ]) {
      expect(
        await g.generate(request),
        isA<TaskOutputNotProduced>().having(
          (n) => n.reason,
          'reason',
          TaskOutputReason.stale,
        ),
      );
    }
  });

  testWidgets('the MP4 is produced, cancelled or failed honestly', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.unknownOutcome);
    final request = TaskOutputRequest(recording: r, languageCode: 'de');
    final ok = FakeVideoEncoder();
    final produced = await tester.runAsync(
      () => Mp4OutputGenerator(
        encoder: ok,
        preset: VideoPreset.portrait,
      ).generate(request),
    );
    expect(produced, isA<TaskOutputProduced>());
    expect((produced! as TaskOutputProduced).suggestedName, endsWith('.mp4'));
    expect(ok.finished, isTrue);

    final cancel = TaskOutputCancel()..cancel();
    final stopped = FakeVideoEncoder();
    expect(
      await tester.runAsync(
        () =>
            Mp4OutputGenerator(encoder: stopped)
                .generate(request, cancel: cancel),
      ),
      isA<TaskOutputCancelled>(),
    );
    expect(stopped.finished, isFalse);

    expect(
      await tester.runAsync(
        () =>
            Mp4OutputGenerator(encoder: FakeVideoEncoder(failAtFrame: 1))
                .generate(request),
      ),
      isA<TaskOutputFailed>(),
    );
    expect(
      await tester.runAsync(
        () =>
            Mp4OutputGenerator(encoder: FakeVideoEncoder(supported: false))
                .generate(request),
      ),
      isA<TaskOutputNotProduced>().having(
        (n) => n.reason,
        'reason',
        TaskOutputReason.unsupportedPlatform,
      ),
    );
  });
}
