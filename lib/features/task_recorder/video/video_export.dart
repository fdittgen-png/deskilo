// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the one video export entry point.
//
// generate() freezes the storyboard revision it is given, builds the
// timeline, and runs one RenderJob over the platform encoder; save()
// hands the finished MP4, its WebVTT caption track and its transcript to
// the local typed FileSaver, the MP4 first: when the video itself is not
// saved, nothing is reported as saved. The recording and the storyboard
// are never written. No network, account or business command is
// involved, and an unsupported runtime is reported before any work.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_names.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/task_recording.dart';
import '../storyboard/storyboard.dart';
import 'frame_composer.dart';
import 'platform_video_encoder.dart';
import 'render_job.dart';
import 'video_encoder.dart';
import 'video_timeline.dart';

part 'video_export.g.dart';

/// The file stem of a recording's tutorial: a slug of its title and the
/// content revision, never an id.
String tutorialStem(TaskRecording recording, String revision) {
  final title = recording.title?.trim() ?? '';
  return 'tutorial-${title.isEmpty ? 'task' : safeFileSlug(title)}-$revision';
}

/// Where a saved video went.
class TaskVideoSaved {
  const TaskVideoSaved(this.video, this.captions, this.transcript);

  /// Saved here, by the saver's own account; never [SaveFailed].

  /// The saver's handle for the MP4.
  final SaveOutcome video;

  /// Null when the sidecar could not be saved (the video still was).
  final SaveOutcome captions;
  final SaveOutcome transcript;
}

/// Generates tutorial videos and saves them locally.
class TaskVideoExporter {
  const TaskVideoExporter(
    this._save, {
    this.encoder = const PlatformVideoEncoder(),
  });

  final TypedFileSaver _save;
  final VideoEncoder encoder;

  /// Runs one generation. Never throws: every outcome is a [VideoResult].
  Future<VideoResult> generate(
    TaskRecording recording,
    Storyboard storyboard,
    AppLocalizations l, {
    required ColorScheme colors,
    VideoPreset preset = VideoPreset.landscape,
    void Function(double fraction)? onProgress,
    RenderCancel? cancel,
  }) async {
    final VideoTimeline timeline;
    try {
      timeline = buildTimeline(recording, storyboard, l, preset: preset);
    } on TimelineException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'video timeline refused',
        error: e,
        stackTrace: st,
      );
      return VideoFailed(e.reasonKey);
    }
    return RenderJob(
      timeline: timeline,
      encoder: encoder,
      composer: FrameComposer(
        colors,
        preset,
        provenance: l.taskExportSceneProvenance,
      ),
    ).run(onProgress: onProgress, cancel: cancel);
  }

  /// Saves [video] as `<stem>.mp4`, `.vtt` and `.txt`. Null when the
  /// MP4 itself was not saved.
  Future<TaskVideoSaved?> save(
    VideoProduced video,
    TaskRecording recording,
    String revision,
  ) async {
    final stem = tutorialStem(recording, revision);
    Future<SaveOutcome> one(List<int> bytes, String name) async {
      try {
        return await _save(bytes: Uint8List.fromList(bytes), fileName: name);
      } catch (e, st) {
        TraceLogger.instance.warn(
          'recorder',
          'video save failed',
          error: e,
          stackTrace: st,
        );
        return const SaveFailed();
      }
    }

    final mp4 = await one(video.mp4, '$stem.mp4');
    if (mp4 is SaveFailed) return null;
    return TaskVideoSaved(
      mp4,
      await one(utf8.encode(video.vtt), '$stem.vtt'),
      await one(utf8.encode(video.transcript), '$stem.txt'),
    );
  }
}

/// The video exporter, over the app's local file saver.
@riverpod
TaskVideoExporter taskVideoExporter(Ref ref) =>
    TaskVideoExporter(ref.watch(typedFileSaverProvider));
