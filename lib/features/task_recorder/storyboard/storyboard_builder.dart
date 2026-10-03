// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the first storyboard revision of a recording.
//
// One frame per recorded step, in order, with the same narrative lines
// the Word document prints (step_narrative.dart), so the document
// and the video tell the same story. A step on a known surface gets a
// recreated scene (safe_scene.dart) up to the illustration bound; a
// protected surface gets an exclusion card; everything else, a text
// slide. Nothing is approved yet: approval is a person's act.
import '../../../l10n/app_localizations.dart';
import '../domain/action_registry.dart';
import '../domain/task_recording.dart';
import '../export/step_narrative.dart';
import '../export/task_document.dart';
import '../export/task_export_labels.dart';
import 'safe_scene.dart';
import 'storyboard.dart';

/// Revision 1 of [r]'s storyboard, in the language of [l].
Storyboard buildStoryboard(
  TaskRecording r,
  AppLocalizations l, {
  StoryboardLimits limits = const StoryboardLimits(),
  bool includeNotes = false,
}) {
  checkExportable(r, const RecordingLimits());
  final labels = TaskExportLabels(l);
  final scenes = buildScenes(r, SceneLabels(l));
  final story = narrate(r, l, includeNotes: includeNotes);
  final unanswered = {for (final s in r.unansweredAttempts) s.seq};
  final attemptOf = {
    for (final s in r.steps)
      if (s.isAttempt && s.op != null) s.op!: s.seq,
  };
  var illustrated = 0;
  final frames = <StoryboardFrame>[];
  for (var i = 0; i < r.steps.length; i++) {
    final s = r.steps[i];
    final StepNarrative(:title, :details) = story[i];
    var scene = scenes[i];
    if (scene != null && illustrated >= limits.maxIllustrated) scene = null;
    if (scene != null) illustrated++;
    final source = s.kind == StepKind.excluded
        ? IllustrationSource.exclusionCard
        : scene != null
        ? IllustrationSource.recreatedScene
        : IllustrationSource.textSlide;
    final status = switch (s) {
      RecordedStep(kind: StepKind.excluded) => FrameStatus.excluded,
      RecordedStep(kind: StepKind.unrecorded) => FrameStatus.gap,
      _ when unanswered.contains(s.seq) => FrameStatus.gap,
      RecordedStep(origin: StepOrigin.authored) => FrameStatus.authored,
      _ => FrameStatus.observed,
    };
    frames.add(
      StoryboardFrame(
        stepSeq: s.seq,
        title: title,
        details: details,
        caption: title,
        altText: scene != null
            ? l.taskExportSceneAlt(labels.surface(s.surface), title)
            : title,
        source: source,
        status: status,
        durationMs: (limits.defaultDurationMs + 600 * details.length).clamp(
          limits.minDurationMs,
          limits.maxDurationMs,
        ),
        scene: scene,
        highlight: scene?.highlight,
        attemptSeq: s.kind == StepKind.observation ? attemptOf[s.op] : null,
      ),
    );
  }
  return Storyboard(
    revision: 1,
    sourceRevision: recordingRevision(r),
    languageCode: l.localeName,
    frames: frames,
    limits: limits,
  );
}
