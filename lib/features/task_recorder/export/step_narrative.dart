// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866/#1876 — the one narrative of a recording's steps.
//
// The Word document prints it and the storyboard (and through it the
// video) shows it, so every output tells the same story: one line per
// recorded step in recording order, with its detail lines. An outcome is
// stated as recorded, a command nobody answered says so, an authored step
// says it was not observed, and a note appears only when notes are
// explicitly included, labelled as the person's own words.
import '../../../l10n/app_localizations.dart';
import '../domain/action_registry.dart';
import '../domain/task_recording.dart';
import 'task_export_labels.dart';

/// What one recorded step says.
class StepNarrative {
  const StepNarrative(this.step, this.title, this.details);

  final RecordedStep step;
  final String title;
  final List<String> details;
}

/// The narrative of every step of [r], in order.
List<StepNarrative> narrate(
  TaskRecording r,
  AppLocalizations l, {
  bool includeNotes = false,
}) {
  final labels = TaskExportLabels(l);
  final unanswered = {for (final s in r.unansweredAttempts) s.seq};
  String? lastSurface;
  final out = <StepNarrative>[];
  for (final s in r.steps) {
    final (title, details) = _step(s, labels, l, includeNotes);
    if (s.surface != null &&
        s.surface != lastSurface &&
        s.kind == StepKind.action) {
      details.insert(0, l.taskExportOnScreen(labels.surface(s.surface)));
    }
    if (s.surface != null) lastSurface = s.surface;
    if (unanswered.contains(s.seq)) details.add(l.taskExportNoResult);
    if (s.origin == StepOrigin.authored) details.add(l.taskExportAuthored);
    out.add(StepNarrative(s, title, List.unmodifiable(details)));
  }
  return out;
}

(String, List<String>) _step(
  RecordedStep s,
  TaskExportLabels labels,
  AppLocalizations l,
  bool includeNotes,
) {
  switch (s.kind) {
    case StepKind.action:
      return (
        labels.action(s),
        [...labels.details(s.payload), ...labels.valueLines(s.values)],
      );
    case StepKind.observation:
      return (
        l.taskExportResult(labels.outcome(s.outcome)),
        labels.details(s.payload),
      );
    case StepKind.annotation:
      final note = s.note;
      if (includeNotes && note != null && note.trim().isNotEmpty) {
        return (l.taskExportNote(note.trim()), <String>[]);
      }
      return (l.taskExportNoteOmitted, <String>[]);
    case StepKind.excluded:
      return (
        l.taskExportExcluded(labels.protectedSurface(s.protectedCategory)),
        <String>[],
      );
    case StepKind.unrecorded:
      return (l.taskExportUnrecorded, <String>[]);
  }
}
