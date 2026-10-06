// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — one recording, one document template.
//
// The document is built from the frozen TaskRecording only: the same
// immutable value the review shows, so a later edit cannot change an
// export already started. Each recorded step becomes exactly one
// numbered item, in recording order, bookmarked `step_<seq>`; nothing is
// merged, invented or dropped. What the recorder observed and what a
// person wrote are kept apart: an authored step says it was not
// observed, a command with no answer says so, and an outcome is stated
// as the recording typed it — a refused or unknown result is never
// rewritten as a success.
//
// A note is the one place a person's own words can appear. It is left
// out unless the export explicitly includes notes, and when included it
// is labelled as that person's words.
import '../../../l10n/app_localizations.dart';
import '../domain/action_registry.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import 'docx/docx_writer.dart';
import '../storyboard/storyboard.dart';
import '../storyboard/storyboard_pictures.dart';
import 'step_narrative.dart';
import 'task_export_labels.dart';

/// Choices made when an export starts.
class TaskDocumentOptions {
  const TaskDocumentOptions({this.includeNotes = false});

  /// Whether a person's own notes are copied into the document.
  final bool includeNotes;
}

/// Why a recording cannot become a document.
enum TaskExportRefusal {
  /// No step at all: nothing to describe.
  empty,

  /// More steps, or a longer title or note, than recordings may hold.
  tooLarge,

  /// The file is not a recording this build accepts.
  rejected,

  /// The storyboard was derived from another version of the recording.
  stale,
}

/// A refused export. The recording it was asked for is untouched.
class TaskExportException implements Exception {
  const TaskExportException(this.refusal);

  final TaskExportRefusal refusal;

  @override
  String toString() => 'TaskExportException(${refusal.name})';
}

/// The BCP 47 tag Word expects for a supported app language.
String documentLanguageTag(String localeName) => switch (localeName) {
  'en' => 'en-US',
  'fr' => 'fr-FR',
  'de' => 'de-DE',
  'es' => 'es-ES',
  'it' => 'it-IT',
  _ => localeName.replaceAll('_', '-'),
};

/// The short content revision a document names: the start of the
/// recording's digest, so a document can be matched to its source.
String recordingRevision(TaskRecording r) =>
    recordingDigest(r).substring(0, 12);

/// Refuses [r] when it is empty or over [limits].
void checkExportable(TaskRecording r, RecordingLimits limits) {
  if (r.steps.isEmpty) {
    throw const TaskExportException(TaskExportRefusal.empty);
  }
  if (r.steps.length > limits.maxSteps ||
      (r.title?.length ?? 0) > limits.maxTitleLength ||
      r.steps.any((s) => (s.note?.length ?? 0) > limits.maxNoteLength)) {
    throw const TaskExportException(TaskExportRefusal.tooLarge);
  }
}

/// The document for [r] in the language of [l].
DocxDocument buildTaskDocument(
  TaskRecording r,
  AppLocalizations l, {
  TaskDocumentOptions options = const TaskDocumentOptions(),
  RecordingLimits limits = const RecordingLimits(),
  StoryboardPictures? illustrations,
}) {
  checkExportable(r, limits);
  final board = illustrations?.storyboard;
  if (board != null && board.sourceRevision != recordingRevision(r)) {
    throw const TaskExportException(TaskExportRefusal.stale);
  }
  final labels = TaskExportLabels(l);
  final title = (r.title?.trim().isNotEmpty ?? false)
      ? r.title!.trim()
      : l.taskExportDocFallbackTitle;
  final blocks = <DocxBlock>[
    DocxParagraph.text(DocxStyle.title, title),
    DocxParagraph.text(DocxStyle.normal, l.taskExportIntro),
    DocxParagraph.text(DocxStyle.heading1, l.taskExportSectionAbout),
    ..._about(
      r,
      l,
      labels,
    ).map((t) => DocxParagraph.text(DocxStyle.listBullet, t)),
  ];
  if (r.prerequisites.isNotEmpty) {
    blocks.add(
      DocxParagraph.text(DocxStyle.heading1, l.taskExportSectionBefore),
    );
    for (final p in r.prerequisites) {
      blocks.add(
        DocxParagraph.text(DocxStyle.listBullet, labels.prerequisite(p)),
      );
    }
  }
  blocks.add(DocxParagraph.text(DocxStyle.heading1, l.taskExportSectionSteps));
  final story = {
    for (final n in narrate(r, l, includeNotes: options.includeNotes))
      n.step.seq: n,
  };
  // With a storyboard, its order and choices; without, the recording's.
  final frames = board?.frames ?? const <StoryboardFrame>[];
  final order = board == null
      ? [for (final s in r.steps) s.seq]
      : [for (final f in frames) f.stepSeq];
  final frameOf = {for (final f in frames) f.stepSeq: f};
  var pictured = false;
  for (final seq in order) {
    final n = story[seq]!;
    final frame = frameOf[seq];
    final omitted = frame?.omitted ?? false;
    final main = omitted ? l.taskExportStoryboardLeftOut : n.title;
    final details = omitted ? const <String>[] : [...n.details];
    final picture = illustrations?.pictures[seq];
    final showPicture =
        !omitted && picture != null && (frame?.approved ?? false);
    if (!omitted && frame?.source == IllustrationSource.recreatedScene) {
      if (illustrations!.failed.contains(seq)) {
        details.add(l.taskExportStoryboardRenderFailed);
      } else if (!showPicture) {
        details.add(l.taskExportIllustrationNotApproved);
      }
    }
    blocks.add(
      DocxParagraph(
        DocxStyle.listNumber,
        [DocxRun(main)],
        bookmark: 'step_$seq',
        keepWithNext: details.isNotEmpty || showPicture,
      ),
    );
    for (var i = 0; i < details.length; i++) {
      blocks.add(
        DocxParagraph.text(
          DocxStyle.stepDetail,
          details[i],
          keepWithNext: i < details.length - 1 || showPicture,
        ),
      );
    }
    if (showPicture) {
      pictured = true;
      blocks
        ..add(DocxImage(picture, frame!.altText))
        ..add(
          DocxParagraph.text(DocxStyle.caption, l.taskExportSceneProvenance),
        );
    }
  }
  blocks.add(DocxParagraph.text(DocxStyle.heading1, l.taskExportSectionLimits));
  for (final t in _limitations(r, l, pictured: pictured)) {
    blocks.add(DocxParagraph.text(DocxStyle.listBullet, t));
  }
  final footer = _footer(l);
  return DocxDocument(
    title: title,
    languageTag: documentLanguageTag(l.localeName),
    blocks: blocks,
    footer: footer,
  );
}

List<String> _about(
  TaskRecording r,
  AppLocalizations l,
  TaskExportLabels labels,
) {
  final end = r.segments.isEmpty
      ? (r.steps.isEmpty ? 0 : r.steps.last.elapsedMs)
      : (r.segments.last.endMs ?? r.steps.last.elapsedMs);
  final seconds = end ~/ 1000;
  final platform = TaskExportLabels.platformName(r.platform);
  return [
    r.kind == RecordingKind.edited
        ? l.taskExportKindEdited
        : l.taskExportKindSource,
    labels.completeness(r.completeness),
    ?labels.endReason(r.endReason),
    if (platform != null) l.taskExportPlatform(platform),
    l.taskExportDuration(seconds ~/ 60, seconds % 60),
    l.taskExportPauses(r.segments.isEmpty ? 0 : r.segments.length - 1),
    l.taskExportVersion(schemaVersionOf(r), r.actionContractVersion),
    l.taskExportRevision(recordingRevision(r)),
  ];
}

List<String> _limitations(
  TaskRecording r,
  AppLocalizations l, {
  required bool pictured,
}) => [
  l.taskExportLimitValues,
  pictured ? l.taskExportLimitRecreated : l.taskExportLimitNoIllustrations,
  if (r.steps.any((s) => s.kind == StepKind.unrecorded))
    l.taskExportLimitNotRunnable,
  if (r.completeness != Completeness.complete) l.taskExportLimitIncomplete,
  if (r.steps.any((s) => s.origin == StepOrigin.authored))
    l.taskExportLimitEdited,
];

/// The footer sentence split around its two page fields.
DocxFooter _footer(AppLocalizations l) {
  const page = '\u0001PAGE\u0001';
  const pages = '\u0001PAGES\u0001';
  final text = l.taskExportFooter(page, pages);
  final a = text.indexOf(page);
  final b = text.indexOf(pages);
  if (a < 0 || b < a) return const DocxFooter('', ' / ', '');
  return DocxFooter(
    text.substring(0, a),
    text.substring(a + page.length, b),
    text.substring(b + pages.length),
  );
}
