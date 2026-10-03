// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the tutorial video and its caption track as workbench outputs
// (#1872).
//
// Pure over the request: the recording, its language, the reviewed
// storyboard (or a fresh one, whose steps are all text slides because
// nothing is approved yet) and the theme. A storyboard reviewed for
// another revision is refused as stale. The MP4 is available only where
// the platform encoder answers its probe; the caption track needs no
// encoder and is always available. The workbench's cancel is honoured
// between frames; nothing partial is ever produced.
import 'dart:convert';
import 'dart:ui';

import '../../../app/theme.dart';
import '../../../core/trace/trace_logger.dart';
import '../export/docx_output_generator.dart';
import '../export/task_document.dart';
import '../package/task_output.dart';
import '../storyboard/storyboard.dart';
import '../storyboard/storyboard_builder.dart';
import 'captions.dart';
import 'frame_composer.dart';
import 'platform_video_encoder.dart';
import 'render_job.dart';
import 'video_encoder.dart';
import 'video_export.dart';
import 'video_timeline.dart';

/// The reviewed storyboard of [request], a fresh one, or null when the
/// one given belongs to another revision.
Storyboard? _storyboard(TaskOutputRequest request) {
  final given = request.storyboard;
  if (given == null) {
    return buildStoryboard(
      request.recording,
      outputLocalizations(request.languageCode),
    );
  }
  return given.sourceRevision == recordingRevision(request.recording)
      ? given
      : null;
}

TaskOutputReason _reason(String key) => switch (key) {
  'taskExportVideoEmpty' => TaskOutputReason.empty,
  'taskExportVideoTooLong' => TaskOutputReason.tooLong,
  'taskExportVideoBusy' => TaskOutputReason.busy,
  'taskExportVideoUnsupported' => TaskOutputReason.unsupportedPlatform,
  _ => TaskOutputReason.failed,
};

/// The timeline of [request], or the reason there is none.
(VideoTimeline?, TaskOutputReason?) _timeline(
  TaskOutputRequest request,
  VideoPreset preset,
) {
  try {
    final storyboard = _storyboard(request);
    if (storyboard == null) return (null, TaskOutputReason.stale);
    return (
      buildTimeline(
        request.recording,
        storyboard,
        outputLocalizations(request.languageCode),
        preset: preset,
      ),
      null,
    );
  } on TaskExportException catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'video output refused',
      error: e,
      stackTrace: st,
    );
    return (null, TaskOutputReason.refused);
  } on TimelineException catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'video output refused',
      error: e,
      stackTrace: st,
    );
    return (null, _reason(e.reasonKey));
  }
}

/// The tutorial video as an H.264 MP4.
class Mp4OutputGenerator implements TaskOutputGenerator {
  const Mp4OutputGenerator({
    this.encoder = const PlatformVideoEncoder(),
    this.preset = VideoPreset.landscape,
  });

  final VideoEncoder encoder;
  final VideoPreset preset;

  @override
  String get id => 'mp4';

  @override
  TaskOutputKind get kind => TaskOutputKind.video;

  @override
  String get fileExtension => 'mp4';

  @override
  Future<TaskOutputAvailability> availability() async {
    final capability = await encoder.probe(
      VideoSpec(width: preset.width, height: preset.height),
    );
    return capability.supported
        ? const TaskOutputAvailable()
        : const TaskOutputUnsupported(TaskOutputReason.unsupportedPlatform);
  }

  @override
  Future<TaskOutputResult> generate(
    TaskOutputRequest request, {
    void Function(double fraction)? onProgress,
    TaskOutputCancel? cancel,
  }) async {
    final (timeline, refused) = _timeline(request, preset);
    if (timeline == null) return TaskOutputNotProduced(refused!);
    final l = outputLocalizations(request.languageCode);
    final colors =
        (request.brightness == Brightness.dark
                ? DeskiloTheme.dark(animations: false)
                : DeskiloTheme.light(animations: false))
            .colorScheme;
    final result =
        await RenderJob(
          timeline: timeline,
          encoder: encoder,
          composer: FrameComposer(
            colors,
            preset,
            provenance: l.taskExportSceneProvenance,
          ),
        ).run(
          onProgress: onProgress,
          cancel: RenderCancel(() => cancel?.isCancelled ?? false),
        );
    return switch (result) {
      VideoProduced(:final mp4) => TaskOutputProduced(
        mp4,
        '${tutorialStem(request.recording, timeline.sourceRevision)}.mp4',
      ),
      VideoCancelled() => const TaskOutputCancelled(),
      VideoUnsupported(:final reasonKey) => TaskOutputNotProduced(
        _reason(reasonKey),
      ),
      VideoFailed(:final reasonKey) => switch (_reason(reasonKey)) {
        TaskOutputReason.failed => const TaskOutputFailed(
          TaskOutputReason.failed,
        ),
        final reason => TaskOutputNotProduced(reason),
      },
    };
  }
}

/// The WebVTT caption track of the same timeline the video is made of.
class VttOutputGenerator implements TaskOutputGenerator {
  const VttOutputGenerator({this.preset = VideoPreset.landscape});

  final VideoPreset preset;

  @override
  String get id => 'vtt';

  @override
  TaskOutputKind get kind => TaskOutputKind.captions;

  @override
  String get fileExtension => 'vtt';

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
    final (timeline, refused) = _timeline(request, preset);
    if (timeline == null) return TaskOutputNotProduced(refused!);
    onProgress?.call(1);
    return TaskOutputProduced(
      utf8.encode(buildVtt(timeline)),
      '${tutorialStem(request.recording, timeline.sourceRevision)}.vtt',
    );
  }
}
