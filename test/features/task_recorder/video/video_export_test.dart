// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — generating and saving a tutorial video through the app's seams.
//
// Invariant: the exporter saves the MP4 first and its WebVTT and
// transcript beside it under one stem named by title and revision; when
// the MP4 is not saved nothing is reported as saved; a storyboard with
// every step left out is refused before any encoding. The panel shows the
// encoder's own frames as a preview strip, offers Generate, shows
// progress with a reachable Cancel while running, and ends with the saved
// file name, the cancellation, or the unsupported-device sentence — never
// a success it did not have. The encoder is a Dart fake: orchestration only.
import 'dart:async';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/export/task_document.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/features/task_recorder/video/render_job.dart';
import 'package:deskilo/features/task_recorder/video/video_encoder.dart';
import 'package:deskilo/features/task_recorder/video/video_export.dart';
import 'package:deskilo/features/task_recorder/video/video_panel.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/real_async.dart';
import '../fixtures/recording_fixtures.dart';
import 'fake_video_encoder.dart';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

/// An encoder whose frames wait for [gate].
class _GatedEncoder extends FakeVideoEncoder {
  final gate = Completer<void>();
  @override
  Future<EncoderSession> start(VideoSpec spec) async =>
      _Gated(this, await super.start(spec));
}

class _Gated implements EncoderSession {
  _Gated(this.owner, this.inner);
  final _GatedEncoder owner;
  final EncoderSession inner;
  @override
  Future<void> addFrame(Uint8List rgba, int ptsMs) async {
    await owner.gate.future;
    await inner.addFrame(rgba, ptsMs);
  }

  @override
  Future<Uint8List> finish(int endMs) => inner.finish(endMs);
  @override
  Future<void> cancel() => inner.cancel();
}

Widget _panel(TaskRecording r, Storyboard sb, TaskVideoExporter exporter) =>
    ProviderScope(
      overrides: [taskVideoExporterProvider.overrideWithValue(exporter)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoGenerationPanel(recording: r, storyboard: sb),
          ),
        ),
      ),
    );

void main() {
  testWidgets('saves the MP4 first, then captions and transcript', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.listRefused);
    final saved = <String>[];
    final exporter = TaskVideoExporter(({
      required bytes,
      required fileName,
    }) async {
      saved.add(fileName);
      return SavedFile('/downloads/$fileName');
    }, encoder: FakeVideoEncoder());
    final colors = ThemeData.light().colorScheme;
    final result = await tester.runAsync(
      () => exporter.generate(
        r,
        buildStoryboard(r, _l('en')),
        _l('en'),
        colors: colors,
      ),
    );
    final where = await tester.runAsync(
      () => exporter.save(result! as VideoProduced, r, recordingRevision(r)),
    );
    final stem = 'tutorial-book-a-desk-${recordingRevision(r)}';
    expect(saved, ['$stem.mp4', '$stem.vtt', '$stem.txt']);
    expect(
      where!.video,
      isA<SavedFile>().having((f) => f.path, 'path', '/downloads/$stem.mp4'),
    );

    final refusing = TaskVideoExporter(
      ({required bytes, required fileName}) async => const SaveFailed(),
      encoder: FakeVideoEncoder(),
    );
    expect(
      await tester.runAsync(
        () => refusing.save(result as VideoProduced, r, 'x'),
      ),
      isNull,
    );

    var sb = buildStoryboard(r, _l('en'));
    for (var i = 0; i < sb.frames.length; i++) {
      sb = sb.setOmitted(i, true);
    }
    final empty = await tester.runAsync(
      () => exporter.generate(r, sb, _l('en'), colors: colors),
    );
    expect(
      empty,
      isA<VideoFailed>().having(
        (f) => f.reasonKey,
        'key',
        'taskExportVideoEmpty',
      ),
    );
  });

  testWidgets('the panel previews, generates and names the saved file', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.planConfirmed);
    final l = _l('en');
    String? savedName;
    final exporter = TaskVideoExporter(({
      required bytes,
      required fileName,
    }) async {
      savedName ??= fileName;
      return SavedFile(fileName);
    }, encoder: FakeVideoEncoder());
    await tester.pumpWidget(_panel(r, buildStoryboard(r, l), exporter));
    await tester.runAsync(
      () => untilReal(() async {
        await tester.pump();
        return find.byType(RawImage).evaluate().isNotEmpty;
      }, what: 'the preview strip'),
    );
    await tester.tap(find.text(l.taskExportVideoGenerate));
    await tester.runAsync(
      () => untilReal(() async {
        await tester.pump();
        return savedName != null &&
            find.text(l.taskExportVideoSaved(savedName!)).evaluate().isNotEmpty;
      }, what: 'the video generation'),
    );
    expect(savedName, endsWith('.mp4'));
  });

  testWidgets('Cancel stops the job and says nothing was saved', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.listRefused);
    final encoder = _GatedEncoder();
    var saves = 0;
    final exporter = TaskVideoExporter(({
      required bytes,
      required fileName,
    }) async {
      saves++;
      return SavedFile(fileName);
    }, encoder: encoder);
    await tester.pumpWidget(_panel(r, buildStoryboard(r, _l('en')), exporter));
    final en = _l('en');
    await tester.tap(find.text(en.taskExportVideoGenerate));
    await tester.pump();
    expect(find.text(en.taskExportVideoCancel), findsOneWidget);
    await tester.tap(find.text(en.taskExportVideoCancel));
    encoder.gate.complete();
    await tester.runAsync(
      () => untilReal(() async {
        await tester.pump();
        return find.text(en.taskExportVideoCancelled).evaluate().isNotEmpty;
      }, what: 'the cancellation'),
    );
    expect(saves, 0);
    expect(encoder.cancelled, isTrue);
    expect(RenderJob.busy, isFalse);
  });

  testWidgets('an unsupported device is told so before any work', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.cancelledReview);
    final en = _l('en');
    final encoder = FakeVideoEncoder(supported: false);
    final exporter = TaskVideoExporter(
      ({required bytes, required fileName}) async => SavedFile(fileName),
      encoder: encoder,
    );
    await tester.pumpWidget(_panel(r, buildStoryboard(r, en), exporter));
    await tester.tap(find.text(en.taskExportVideoGenerate));
    await tester.runAsync(
      () => untilReal(() async {
        await tester.pump();
        return find.text(en.taskExportVideoUnsupported).evaluate().isNotEmpty;
      }, what: 'the capability answer'),
    );
    expect(encoder.frames, isEmpty);
  });
}
