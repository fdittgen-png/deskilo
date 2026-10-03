// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — one bounded timeline from one reviewed storyboard revision.
//
// The preview, the encoder and the caption file all read this value, so
// they cannot disagree: a title card, one cue per INCLUDED frame in the
// storyboard's order for the frame's reviewed duration, and a summary
// card that says how the recording ended and how many steps a reviewer
// left out. Times are PRESENTATION times; the recording's own relative
// times are never stretched or shortened into them, and nothing here
// claims a result the recording does not state.
import '../../../l10n/app_localizations.dart';
import '../domain/task_recording.dart';
import '../export/task_export_labels.dart';
import '../storyboard/storyboard.dart';

/// The two built-in frame shapes.
enum VideoPreset {
  landscape(1280, 720),
  portrait(720, 1280);

  const VideoPreset(this.width, this.height);
  final int width;
  final int height;
}

/// Bounds of one video.
class VideoLimits {
  const VideoLimits({
    this.maxDurationMs = 10 * 60 * 1000,
    this.maxCues = 200,
    this.titleMs = 3000,
    this.summaryMs = 4000,
    this.fadeMs = 300,
    this.fps = 10,
    this.maxOutputBytes = 64 * 1024 * 1024,
  });

  final int maxDurationMs;
  final int maxCues;
  final int titleMs;
  final int summaryMs;

  /// The cross-fade between cues: brief, never a flash.
  final int fadeMs;

  /// Frames per second of the fades; a still is re-sent once a second.
  final int fps;
  final int maxOutputBytes;
}

/// What a cue shows.
enum CueKind { title, step, summary }

/// One stretch of the video.
class TimelineCue {
  const TimelineCue({
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.heading,
    required this.lines,
    required this.caption,
    this.frame,
  });

  final CueKind kind;
  final int startMs;
  final int endMs;

  /// Burned in at the top of the frame.
  final String heading;

  /// Burned in on a text slide.
  final List<String> lines;

  /// The caption track's text for this cue.
  final String caption;

  /// The storyboard frame of a step cue.
  final StoryboardFrame? frame;

  int get durationMs => endMs - startMs;
}

/// Why a timeline could not be built.
class TimelineException implements Exception {
  const TimelineException(this.reasonKey);

  /// An ARB key in the task_export fragment.
  final String reasonKey;

  @override
  String toString() => 'TimelineException($reasonKey)';
}

/// The timeline: frozen, bounded, in presentation time.
class VideoTimeline {
  VideoTimeline({
    required this.preset,
    required this.storyboardRevision,
    required this.sourceRevision,
    required List<TimelineCue> cues,
  }) : cues = List.unmodifiable(cues);

  final VideoPreset preset;
  final int storyboardRevision;
  final String sourceRevision;
  final List<TimelineCue> cues;

  int get durationMs => cues.isEmpty ? 0 : cues.last.endMs;
}

/// The timeline of [sb] for [recording], in the language of [l].
VideoTimeline buildTimeline(
  TaskRecording recording,
  Storyboard sb,
  AppLocalizations l, {
  VideoPreset preset = VideoPreset.landscape,
  VideoLimits limits = const VideoLimits(),
}) {
  final included = sb.included.toList();
  if (included.isEmpty) {
    throw const TimelineException('taskExportVideoEmpty');
  }
  if (included.length + 2 > limits.maxCues) {
    throw const TimelineException('taskExportVideoTooLong');
  }
  final title = (recording.title?.trim().isNotEmpty ?? false)
      ? recording.title!.trim()
      : l.taskExportDocFallbackTitle;
  final cues = <TimelineCue>[];
  var t = 0;
  void add(
    CueKind kind,
    int ms,
    String heading,
    List<String> lines,
    String caption, [
    StoryboardFrame? frame,
  ]) {
    cues.add(
      TimelineCue(
        kind: kind,
        startMs: t,
        endMs: t + ms,
        heading: heading,
        lines: lines,
        caption: caption,
        frame: frame,
      ),
    );
    t += ms;
  }

  add(CueKind.title, limits.titleMs, title, [l.taskExportVideoIntro], title);
  for (final (i, f) in included.indexed) {
    final heading = l.taskExportVideoStepHeading(i + 1, f.title);
    add(CueKind.step, f.durationMs, heading, f.details, f.caption, f);
  }
  final labels = TaskExportLabels(l);
  final omitted = sb.frames.length - included.length;
  final summary = [
    labels.completeness(recording.completeness),
    if (omitted > 0) l.taskExportVideoLeftOut(omitted),
    l.taskExportLimitValues,
  ];
  add(
    CueKind.summary,
    limits.summaryMs,
    l.taskExportVideoSummary,
    summary,
    summary.first,
  );
  if (t > limits.maxDurationMs) {
    throw const TimelineException('taskExportVideoTooLong');
  }
  return VideoTimeline(
    preset: preset,
    storyboardRevision: sb.revision,
    sourceRevision: sb.sourceRevision,
    cues: cues,
  );
}
