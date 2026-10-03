// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — one video generation, from a frozen timeline to a result.
//
// The job draws each cue once, then streams frames to the encoder one at
// a time, awaiting each (backpressure): a still is re-sent once a second
// so every player sees regular keyframes and the right duration, and a
// short cross-fade joins two cues. Cancellation is cooperative and
// checked between frames; a cancelled or failed job awaits the
// encoder's own cancel (which deletes its partial file) before it
// reports, and only one job runs at a time — a caller giving up is not a
// cancellation, so the slot is held until the worker has really stopped.
// A result is "produced" only with finalized, non-empty bytes within the
// output bound; nothing partial is ever reported as a video.
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../core/trace/trace_logger.dart';
import 'captions.dart';
import 'frame_composer.dart';
import 'video_encoder.dart';
import 'video_timeline.dart';

/// A cooperative cancellation flag.
class RenderCancel {
  /// [also] is another flag to honour, such as the workbench's own.
  RenderCancel([this.also]);

  final bool Function()? also;
  bool _cancelled = false;
  bool get isCancelled => _cancelled || (also?.call() ?? false);
  void cancel() => _cancelled = true;
}

/// What a job ended with.
sealed class VideoResult {
  const VideoResult();
}

/// A finalized MP4 with its caption track and transcript.
class VideoProduced extends VideoResult {
  const VideoProduced(this.mp4, this.vtt, this.transcript);

  final Uint8List mp4;
  final String vtt;
  final String transcript;
}

/// This runtime cannot encode; [reasonKey] says why.
class VideoUnsupported extends VideoResult {
  const VideoUnsupported(this.reasonKey);
  final String reasonKey;
}

/// The encode failed; nothing was produced.
class VideoFailed extends VideoResult {
  const VideoFailed(this.reasonKey);
  final String reasonKey;
}

/// Cancelled by the person; nothing was produced.
class VideoCancelled extends VideoResult {
  const VideoCancelled();
}

/// One generation of [timeline] through [encoder].
class RenderJob {
  RenderJob({
    required this.timeline,
    required this.encoder,
    required this.composer,
    this.limits = const VideoLimits(),
  });

  final VideoTimeline timeline;
  final VideoEncoder encoder;
  final FrameComposer composer;
  final VideoLimits limits;

  static bool _busy = false;

  /// Whether a job is running (its encoder not yet released).
  static bool get busy => _busy;

  /// The frame times of one cue, relative to its start: a still every
  /// second, and the fade frames at the start of every cue but the first.
  static List<(int, double)> cueFrames(
    TimelineCue cue,
    VideoLimits limits, {
    required bool fadeIn,
  }) {
    final out = <(int, double)>[];
    final step = 1000 ~/ limits.fps;
    var t = 0;
    if (fadeIn) {
      for (; t < limits.fadeMs && t < cue.durationMs; t += step) {
        out.add((t, (t + step) / limits.fadeMs));
      }
    }
    for (; t < cue.durationMs; t += 1000) {
      out.add((t, 1));
    }
    return out;
  }

  Future<VideoResult> run({
    void Function(double fraction)? onProgress,
    RenderCancel? cancel,
  }) async {
    if (_busy) return const VideoFailed('taskExportVideoBusy');
    final spec = VideoSpec(
      width: timeline.preset.width,
      height: timeline.preset.height,
    );
    _busy = true;
    EncoderSession? session;
    ui.Picture? previous;
    try {
      final capability = await encoder.probe(spec);
      if (!capability.supported) {
        return VideoUnsupported(
          capability.reasonKey ?? 'taskExportVideoUnsupported',
        );
      }
      final live = await encoder.start(spec);
      session = live;
      final total = timeline.durationMs;
      var lastPts = -1;
      for (final (i, cue) in timeline.cues.indexed) {
        final current = composer.picture(cue);
        try {
          for (final (offset, alpha) in cueFrames(cue, limits, fadeIn: i > 0)) {
            if (cancel?.isCancelled ?? false) {
              await live.cancel();
              session = null;
              return const VideoCancelled();
            }
            final rgba = await composer.rgba(
              current,
              previous: previous,
              alpha: alpha,
            );
            await live.addFrame(rgba, cue.startMs + offset);
            lastPts = cue.startMs + offset;
            onProgress?.call((cue.startMs + offset) / total);
          }
        } finally {
          previous?.dispose();
          previous = current;
        }
      }
      // The last still twice more, one frame step apart, just before the
      // end: a muxer that gives the last sample the previous sample's
      // duration (Android's MediaMuxer) then ends exactly on the
      // timeline instead of up to a second late.
      final step = 1000 ~/ limits.fps;
      final last = previous;
      if (last != null) {
        final still = await composer.rgba(last);
        for (final at in [total - 2 * step, total - step]) {
          if (at <= lastPts || (cancel?.isCancelled ?? false)) continue;
          await live.addFrame(still, at);
          lastPts = at;
        }
      }
      if (cancel?.isCancelled ?? false) {
        await live.cancel();
        session = null;
        return const VideoCancelled();
      }
      final mp4 = await live.finish(total);
      session = null;
      if (mp4.isEmpty || mp4.length > limits.maxOutputBytes) {
        return const VideoFailed('taskExportVideoFailed');
      }
      onProgress?.call(1);
      return VideoProduced(mp4, buildVtt(timeline), buildTranscript(timeline));
    } on VideoEncoderException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'video encode failed',
        error: e,
        stackTrace: st,
      );
      return VideoFailed(e.reasonKey);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'video encode failed',
        error: e,
        stackTrace: st,
      );
      return const VideoFailed('taskExportVideoFailed');
    } finally {
      previous?.dispose();
      final open = session;
      if (open != null) {
        try {
          await open.cancel();
        } catch (e, st) {
          TraceLogger.instance.warn(
            'recorder',
            'video encoder cancel failed',
            error: e,
            stackTrace: st,
          );
        }
      }
      _busy = false;
    }
  }
}
