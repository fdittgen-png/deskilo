// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — a REAL encode on a device: the shared booking fixture's
// storyboard → timeline → frames → the platform encoder → MP4 bytes.
//
//   flutter test integration_test/task_video_encoder_test.dart -d macos
//   flutter test integration_test/task_video_encoder_test.dart -d <android>
//
// The file is read back with an MP4 box walk written here, independent
// of the encoder: `ftyp` first, one `trak` whose sample description is
// `avc1`, a movie duration matching the timeline, as many samples as
// frames were sent, and no canary anywhere in the bytes. Decoded-pixel
// order is proved by the Darwin readback harness
// (packages/deskilo_video_encoder/tool/readback/main.swift).
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/features/task_recorder/video/frame_composer.dart';
import 'package:deskilo/features/task_recorder/video/platform_video_encoder.dart';
import 'package:deskilo/features/task_recorder/video/render_job.dart';
import 'package:deskilo/features/task_recorder/video/video_encoder.dart';
import 'package:deskilo/features/task_recorder/video/video_timeline.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The fixture, inlined: a device test cannot read the repository.
const _fixture = '''
{"format":"deskilo.task-recording","schema_version":1,
"action_contract_version":1,"platform":"android","kind":"source",
"title":"Book a desk","prerequisites":[{"id":"signed_in"}],
"segments":[{"index":0,"start_ms":0,"end_ms":3000}],
"steps":[
{"seq":1,"segment":0,"elapsed_ms":400,"kind":"action","surface":"reservations.reserve","action":"reservations.open_reserve","action_version":1},
{"seq":2,"segment":0,"elapsed_ms":800,"kind":"action","surface":"reservations.reserve","action":"reservations.select_date","action_version":1,"payload":{"date_relation":"tomorrow"}},
{"seq":3,"segment":0,"elapsed_ms":1600,"kind":"action","surface":"reservations.booking_sheet","action":"reservations.confirm_booking","action_version":1,"payload":{"for_whom":"self"},"op":"op1","state":"attempted"},
{"seq":4,"segment":0,"elapsed_ms":2500,"kind":"observation","surface":"reservations.booking_sheet","op":"op1","state":"refused","outcome":"booking.refused","payload":{"refusal":"conflict"}}],
"end_reason":"stopped","completeness":"complete"}''';

/// Box type → payload, for the boxes of one level.
Map<String, List<Uint8List>> _boxes(Uint8List data) {
  final out = <String, List<Uint8List>>{};
  final view = ByteData.sublistView(data);
  var at = 0;
  while (at + 8 <= data.length) {
    var size = view.getUint32(at);
    final type = ascii.decode(data.sublist(at + 4, at + 8));
    var header = 8;
    if (size == 1) {
      size = view.getUint64(at + 8);
      header = 16;
    }
    if (size < header || at + size > data.length) break;
    (out[type] ??= []).add(Uint8List.sublistView(data, at + header, at + size));
    at += size;
  }
  return out;
}

class _CountingEncoder implements VideoEncoder {
  _CountingEncoder(this.inner);
  final VideoEncoder inner;
  int frames = 0;

  @override
  Future<EncoderCapability> probe(VideoSpec spec) => inner.probe(spec);

  @override
  Future<EncoderSession> start(VideoSpec spec) async =>
      _CountingSession(this, await inner.start(spec));
}

class _CountingSession implements EncoderSession {
  _CountingSession(this.owner, this.inner);
  final _CountingEncoder owner;
  final EncoderSession inner;

  @override
  Future<void> addFrame(Uint8List rgba, int ptsMs) async {
    await inner.addFrame(rgba, ptsMs);
    owner.frames++;
  }

  @override
  Future<Uint8List> finish(int endMs) => inner.finish(endMs);

  @override
  Future<void> cancel() => inner.cancel();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final preset in VideoPreset.values) {
    testWidgets('a ${preset.name} tutorial encodes to a readable MP4', (
      tester,
    ) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final recording = decodeRecordingText(_fixture).recording!;
      var sb = buildStoryboard(recording, l);
      for (var i = 0; i < sb.frames.length; i++) {
        if (sb.frames[i].source == IllustrationSource.recreatedScene) {
          sb = sb.setApproved(i, true);
        }
      }
      final timeline = buildTimeline(recording, sb, l, preset: preset);
      final encoder = _CountingEncoder(const PlatformVideoEncoder());
      final result = await RenderJob(
        timeline: timeline,
        encoder: encoder,
        composer: FrameComposer(
          DeskiloTheme.light(animations: false).colorScheme,
          preset,
          provenance: l.taskExportSceneProvenance,
        ),
      ).run();
      expect(result, isA<VideoProduced>(), reason: '$result');
      final mp4 = (result as VideoProduced).mp4;

      final top = _boxes(mp4);
      expect(ascii.decode(mp4.sublist(4, 8)), 'ftyp');
      final moov = _boxes(top['moov']!.single);
      final traks = moov['trak']!;
      expect(traks, hasLength(1), reason: 'one video track, no audio');
      final mvhd = ByteData.sublistView(moov['mvhd']!.single);
      final v1 = mvhd.getUint8(0) == 1;
      final timescale = mvhd.getUint32(v1 ? 20 : 12);
      final duration = v1 ? mvhd.getUint64(24) : mvhd.getUint32(16);
      expect(
        (duration * 1000 / timescale - timeline.durationMs).abs(),
        lessThan(250),
        reason: 'movie duration',
      );
      final stbl = _boxes(
        _boxes(
          _boxes(_boxes(traks.single)['mdia']!.single)['minf']!.single,
        )['stbl']!.single,
      );
      final stsd = stbl['stsd']!.single;
      expect(ascii.decode(stsd.sublist(12, 16)), 'avc1');
      final stsz = ByteData.sublistView(stbl['stsz']!.single);
      expect(stsz.getUint32(8), encoder.frames, reason: 'sample count');
      final text = latin1.decode(mp4).toLowerCase();
      for (final c in ['canary', 'zelda', 'withheld']) {
        expect(text.contains(c), isFalse);
      }
    });
  }

  testWidgets('cancel releases the encoder and a new job can start', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    final recording = decodeRecordingText(_fixture).recording!;
    final timeline = buildTimeline(recording, buildStoryboard(recording, l), l);
    final cancel = RenderCancel();
    final job = RenderJob(
      timeline: timeline,
      encoder: const PlatformVideoEncoder(),
      composer: FrameComposer(
        DeskiloTheme.light(animations: false).colorScheme,
        timeline.preset,
        provenance: 'p',
      ),
    );
    final result = await job.run(
      cancel: cancel,
      onProgress: (p) {
        if (p > 0.4) cancel.cancel();
      },
    );
    expect(result, isA<VideoCancelled>());
    expect(RenderJob.busy, isFalse);
  });
}
