// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — an edited copy of a recording, with honest provenance.
//
// The source recording on the device is never changed. An edited copy
// names the source by its digest, keeps each kept step's original
// sequence number as `source_seq`, and keeps the source's completeness:
// leaving steps out never makes a partial recording complete. Leaving
// out a command's attempt leaves out its outcome too, so the copy never
// holds an outcome that answers nothing.

import 'task_recording.dart';
import 'task_recording_codec.dart';

/// The steps that go when [seq] is left out: the step, and the outcome
/// of the attempt it is.
Set<int> dependentsOf(TaskRecording source, int seq) {
  final step = source.steps.where((s) => s.seq == seq).firstOrNull;
  if (step == null) return const {};
  return {
    seq,
    if (step.isAttempt)
      for (final s in source.steps)
        if (s.seq != seq && s.op == step.op) s.seq,
  };
}

/// [source] without the steps in [leftOut] (and their dependents).
/// Returns [source] itself when nothing is left out.
TaskRecording editedCopy(
  TaskRecording source,
  Set<int> leftOut, {
  String? title,
}) {
  final drop = {for (final seq in leftOut) ...dependentsOf(source, seq)};
  if (drop.isEmpty && title == null) return source;
  final kept = <RecordedStep>[];
  for (final step in source.steps) {
    if (drop.contains(step.seq)) continue;
    kept.add(
      step.renumbered(
        kept.length + 1,
        keepSourceSeq: step.sourceSeq ?? step.seq,
      ),
    );
  }
  return TaskRecording(
    actionContractVersion: source.actionContractVersion,
    platform: source.platform,
    kind: RecordingKind.edited,
    sourceDigest: source.kind == RecordingKind.edited
        ? source.sourceDigest
        : recordingDigest(source),
    title: title ?? source.title,
    prerequisites: source.prerequisites,
    segments: source.segments,
    steps: kept,
    endReason: source.endReason,
    completeness: source.completeness,
  );
}
