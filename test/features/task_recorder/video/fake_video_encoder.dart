// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — a Dart encoder that records what it was given. It proves the
// ORCHESTRATION only (order, timing, backpressure, cancel, cleanup); a
// playable file is proved by the native encoders' own readback.
import 'dart:async';
import 'dart:typed_data';

import 'package:deskilo/features/task_recorder/video/video_encoder.dart';

class FakeFrame {
  FakeFrame(this.rgba, this.ptsMs);
  final Uint8List rgba;
  final int ptsMs;
}

class FakeVideoEncoder implements VideoEncoder {
  FakeVideoEncoder({
    this.supported = true,
    this.failAtFrame,
    this.slow = false,
  });

  final bool supported;

  /// addFrame throws at this frame index.
  final int? failAtFrame;

  /// Each addFrame waits a real microtask turn before accepting.
  final bool slow;

  final frames = <FakeFrame>[];
  VideoSpec? spec;
  int? endMs;
  bool cancelled = false;
  bool finished = false;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<EncoderCapability> probe(VideoSpec spec) async => supported
      ? const EncoderCapability.supported()
      : const EncoderCapability.unsupported('taskExportVideoUnsupported');

  @override
  Future<EncoderSession> start(VideoSpec spec) async {
    this.spec = spec;
    return _Session(this);
  }
}

class _Session implements EncoderSession {
  _Session(this.e);
  final FakeVideoEncoder e;

  @override
  Future<void> addFrame(Uint8List rgba, int ptsMs) async {
    e.inFlight++;
    if (e.inFlight > e.maxInFlight) e.maxInFlight = e.inFlight;
    try {
      if (e.slow) await Future<void>.delayed(Duration.zero);
      if (e.frames.length == e.failAtFrame) {
        throw const VideoEncoderException('taskExportVideoFailed');
      }
      e.frames.add(FakeFrame(rgba, ptsMs));
    } finally {
      e.inFlight--;
    }
  }

  @override
  Future<Uint8List> finish(int endMs) async {
    e.endMs = endMs;
    e.finished = true;
    return Uint8List.fromList([0, 0, 0, 24, ...'ftypisom'.codeUnits]);
  }

  @override
  Future<void> cancel() async => e.cancelled = true;
}
