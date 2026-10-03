// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the timeline, the captions and the render job's orchestration.
//
// Invariant: one timeline (title, every included frame in storyboard
// order for its reviewed duration, summary) feeds the frames, the WebVTT
// track and the transcript alike; caption text cannot inject markup or a
// timing line; frames reach the encoder one at a time (never two in
// flight), at strictly increasing times covering the whole timeline and
// closing one frame step before its end,
// and every cue's settled frame differs from its neighbours (nothing
// missing, duplicated or blank); cancel, encoder failure and an
// unsupported runtime each end with the encoder cancelled and nothing
// produced, and the single job slot is free afterwards; a recording made
// with canaries renders byte-identical frames and captions to the
// committed fixture. The encoder here is a Dart fake: this proves
// orchestration, not a playable file.
import 'package:crypto/crypto.dart';
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/features/task_recorder/video/captions.dart';
import 'package:deskilo/features/task_recorder/video/frame_composer.dart';
import 'package:deskilo/features/task_recorder/video/render_job.dart';
import 'package:deskilo/features/task_recorder/video/video_timeline.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/recording_fixtures.dart';
import 'fake_video_encoder.dart';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

Storyboard _approved(TaskRecording r, AppLocalizations l) {
  var sb = buildStoryboard(r, l);
  for (var i = 0; i < sb.frames.length; i++) {
    if (sb.frames[i].source == IllustrationSource.recreatedScene) {
      sb = sb.setApproved(i, true);
    }
  }
  return sb;
}

const _fast = VideoLimits(fps: 10, fadeMs: 200);

RenderJob _job(VideoTimeline t, FakeVideoEncoder e) => RenderJob(
  timeline: t,
  encoder: e,
  composer: FrameComposer(
    DeskiloTheme.light(animations: false).colorScheme,
    t.preset,
    provenance: 'Illustration',
  ),
  limits: _fast,
);

VideoTimeline _timeline(
  BookingJourney j, {
  String code = 'en',
  VideoPreset preset = VideoPreset.portrait,
}) {
  final r = _fixture(j);
  return buildTimeline(r, _approved(r, _l(code)), _l(code), preset: preset);
}

void main() {
  group('timeline and captions', () {
    test('title, every included frame in order, summary', () {
      final r = _fixture(BookingJourney.planConfirmed);
      final l = _l('en');
      var sb = buildStoryboard(r, l).setOmitted(2, true).move(0, 1);
      final t = buildTimeline(r, sb, l);
      expect(t.cues.first.kind, CueKind.title);
      expect(t.cues.last.kind, CueKind.summary);
      final steps = t.cues.where((c) => c.kind == CueKind.step);
      expect(steps.map((c) => c.frame!.stepSeq), [
        for (final f in sb.included) f.stepSeq,
      ]);
      expect(t.cues.last.lines, contains(l.taskExportVideoLeftOut(1)));
      for (var i = 1; i < t.cues.length; i++) {
        expect(t.cues[i].startMs, t.cues[i - 1].endMs);
      }
      expect(t.storyboardRevision, sb.revision);
      sb = sb.setOmitted(0, true);
      for (var i = 0; i < sb.frames.length; i++) {
        sb = sb.setOmitted(i, true);
      }
      expect(() => buildTimeline(r, sb, l), throwsA(isA<TimelineException>()));
      expect(
        () => buildTimeline(
          r,
          buildStoryboard(r, l),
          l,
          limits: const VideoLimits(maxDurationMs: 5000),
        ),
        throwsA(isA<TimelineException>()),
      );
    });

    test('WebVTT follows the timeline and escapes caption text', () {
      final r = _fixture(BookingJourney.listRefused);
      final l = _l('fr');
      final sb = buildStoryboard(r, l).setCaption(1, '<b>x</b> --> & "y"');
      final t = buildTimeline(r, sb, l);
      final vtt = buildVtt(t);
      expect(vtt, startsWith('WEBVTT\n\n'));
      final timing = RegExp(
        r'^(\d\d):(\d\d):(\d\d)\.(\d{3}) --> (\d\d):(\d\d):(\d\d)\.(\d{3})$',
        multiLine: true,
      ).allMatches(vtt).toList();
      expect(timing, hasLength(t.cues.length));
      int ms(RegExpMatch m, int o) =>
          int.parse(m[o]!) * 3600000 +
          int.parse(m[o + 1]!) * 60000 +
          int.parse(m[o + 2]!) * 1000 +
          int.parse(m[o + 3]!);
      for (final (i, m) in timing.indexed) {
        expect(ms(m, 1), t.cues[i].startMs);
        expect(ms(m, 5), t.cues[i].endMs);
      }
      final textLines = vtt
          .split('\n')
          .where((s) => !s.contains(' --> ') && !RegExp(r'^\d+$').hasMatch(s));
      expect(
        textLines.where((s) => s.contains('<') || s.contains('-->')),
        isEmpty,
      );
      expect(vtt, contains('&lt;b&gt;x&lt;/b&gt; --&gt; &amp; "y"'));
      expect(buildTranscript(t), contains(t.cues[1].heading));
    });
  });

  group('render job', () {
    testWidgets('frames stream in order, one at a time, over the whole time', (
      tester,
    ) async {
      final t = _timeline(BookingJourney.planConfirmed);
      final e = FakeVideoEncoder(slow: true);
      final result = await tester.runAsync(() => _job(t, e).run());
      expect(result, isA<VideoProduced>());
      expect(e.maxInFlight, 1);
      expect(e.spec!.width, 720);
      expect(e.frames.first.ptsMs, 0);
      for (var i = 1; i < e.frames.length; i++) {
        expect(e.frames[i].ptsMs, greaterThan(e.frames[i - 1].ptsMs));
        expect(
          e.frames[i].ptsMs - e.frames[i - 1].ptsMs,
          lessThanOrEqualTo(1000),
        );
      }
      expect(e.frames.last.ptsMs, lessThan(t.durationMs));
      // Two closing frames one step apart, so a muxer that repeats the
      // previous sample's duration still ends on the timeline.
      expect(e.frames.reversed.take(2).map((f) => f.ptsMs).toList(), [
        t.durationMs - 100,
        t.durationMs - 200,
      ]);
      expect(e.endMs, t.durationMs);
      expect(e.frames.every((f) => f.rgba.length == 720 * 1280 * 4), isTrue);
      // The settled frame of every cue is distinct from its neighbours.
      final settled = [
        for (final c in t.cues)
          sha256
              .convert(e.frames.lastWhere((f) => f.ptsMs < c.endMs).rgba)
              .toString(),
      ];
      for (var i = 1; i < settled.length; i++) {
        expect(settled[i], isNot(settled[i - 1]), reason: 'cue $i');
      }
      expect((result! as VideoProduced).vtt, buildVtt(t));
      expect(RenderJob.busy, isFalse);
    });

    testWidgets('cancel mid-way releases the encoder and produces nothing', (
      tester,
    ) async {
      final t = _timeline(BookingJourney.listRefused);
      final e = FakeVideoEncoder();
      final cancel = RenderCancel();
      final result = await tester.runAsync(
        () => _job(t, e).run(
          cancel: cancel,
          onProgress: (p) {
            if (p > 0.3) cancel.cancel();
          },
        ),
      );
      expect(result, isA<VideoCancelled>());
      expect(e.cancelled, isTrue);
      expect(e.finished, isFalse);
      expect(RenderJob.busy, isFalse);
    });

    testWidgets('an encoder failure and an unsupported runtime are honest', (
      tester,
    ) async {
      final t = _timeline(BookingJourney.unknownOutcome);
      final failing = FakeVideoEncoder(failAtFrame: 3);
      final failed = await tester.runAsync(() => _job(t, failing).run());
      expect(
        failed,
        isA<VideoFailed>().having(
          (f) => f.reasonKey,
          'key',
          'taskExportVideoFailed',
        ),
      );
      expect(failing.cancelled, isTrue);
      expect(failing.finished, isFalse);

      final none = FakeVideoEncoder(supported: false);
      final unsupported = await tester.runAsync(() => _job(t, none).run());
      expect(unsupported, isA<VideoUnsupported>());
      expect(none.frames, isEmpty);
      expect(RenderJob.busy, isFalse);
    });

    testWidgets('only one job runs at a time', (tester) async {
      final t = _timeline(BookingJourney.cancelledReview);
      final e = FakeVideoEncoder(slow: true);
      final results = await tester.runAsync(
        () =>
            Future.wait([_job(t, e).run(), _job(t, FakeVideoEncoder()).run()]),
      );
      expect(results![0], isA<VideoProduced>());
      expect(
        results[1],
        isA<VideoFailed>().having(
          (f) => f.reasonKey,
          'key',
          'taskExportVideoBusy',
        ),
      );
    });

    testWidgets('canaries at capture change no frame and no caption', (
      tester,
    ) async {
      for (final j in [
        BookingJourney.planConfirmed,
        BookingJourney.listRefused,
      ]) {
        final recorded = await tester.runAsync(() => recordFixture(j));
        final live = recorded!.recording;
        final l = _l('it');
        final a = buildTimeline(live, _approved(live, l), l);
        final b = _timeline(j, code: 'it', preset: VideoPreset.landscape);
        final ea = FakeVideoEncoder();
        final eb = FakeVideoEncoder();
        final ra = await tester.runAsync(() => _job(a, ea).run());
        await tester.runAsync(() => _job(b, eb).run());
        expect(ea.frames.length, eb.frames.length);
        for (var i = 0; i < ea.frames.length; i++) {
          expect(ea.frames[i].rgba, eb.frames[i].rgba, reason: 'frame $i');
        }
        final produced = ra! as VideoProduced;
        for (final c in [...privateCanaries, ...canaryFragments]) {
          expect(produced.vtt.toLowerCase(), isNot(contains(c.toLowerCase())));
          expect(
            produced.transcript.toLowerCase(),
            isNot(contains(c.toLowerCase())),
          );
        }
      }
    });
  });
}
