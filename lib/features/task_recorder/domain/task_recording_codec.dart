// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the one JSON codec and validator for task recordings.
//
// Every reader goes through [decodeRecording]: the store recovering a
// file after a crash, the plain-JSON import, the task package (#1872)
// and the guided-task compiler (#1867). Imported recordings are
// UNTRUSTED. The validator therefore:
//   * refuses unknown keys anywhere, so nothing rides along unseen;
//   * refuses a payload key or value outside the finite vocabulary of
//     safe_payload.dart (only the typed placeholder may stand in);
//   * refuses an outcome that answers no earlier attempt, a sequence
//     that goes backwards, a time that runs backwards, a note outside an
//     annotation, and anything over the limits;
//   * never executes, fetches or resolves anything it reads.
// A step naming an action or outcome this build does not know is kept
// as an "unrecorded" step with no payload, and the recording is marked
// not runnable: a transcript may still be shown, a guide may not run.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'action_registry.dart';
import 'safe_payload.dart';
import 'step_values.dart';
import 'task_recording.dart';
import 'recording_reference.dart';

part 'task_recording_decoder.dart';

/// Why a recording was refused or degraded.
enum RecordingIssueCode {
  tooLarge,
  notJson,
  notAnObject,
  wrongFormat,
  unsupportedSchema,
  unknownKey,
  missingField,
  badValue,
  tooMany,
  tooLong,
  sequence,
  time,
  unsafePayload,
  orphanOutcome,
  unknownAction,
  unknownOutcome,
  inconsistent,
}

/// One finding. A fatal one refuses the recording.
class RecordingIssue {
  const RecordingIssue(this.code, this.path, {this.fatal = true});

  final RecordingIssueCode code;

  /// Where, as a JSON path ("steps[3].payload"). Never the value.
  final String path;
  final bool fatal;

  @override
  String toString() => '${code.name} at $path${fatal ? '' : ' (degraded)'}';
}

/// What reading a recording produced.
class RecordingDecodeResult {
  const RecordingDecodeResult(this.recording, this.issues);

  /// Null when a fatal issue refused it.
  final TaskRecording? recording;
  final List<RecordingIssue> issues;

  bool get accepted => recording != null;

  /// Whether every step is understood by this build. A recording that
  /// is not runnable may be shown as a transcript, never replayed.
  bool get runnable => accepted && issues.isEmpty;
}

/// Encodes [r] in canonical key order. The result is the export.
Map<String, Object?> encodeRecording(TaskRecording r) => {
  'format': taskRecordingFormat,
  'schema_version': schemaVersionOf(r),
  'action_contract_version': r.actionContractVersion,
  'platform': r.platform.wire,
  'kind': r.kind.wire,
  if (r.sourceDigest != null) 'source_digest': r.sourceDigest,
  if (r.title != null) 'title': r.title,
  if (r.capturesValues) 'values_mode': 'captured',
  'prerequisites': [
    for (final p in r.prerequisites)
      {'id': p.id, if (p.value != null) 'value': p.value},
  ],
  'segments': [for (final s in r.segments) encodeSegment(s)],
  'steps': [for (final s in r.steps) encodeStep(s)],
  if (r.endReason != null) 'end_reason': r.endReason!.wire,
  'completeness': r.completeness.wire,
};

Map<String, Object?> encodeSegment(RecordingSegment s) => {
  'index': s.index,
  'start_ms': s.startMs,
  if (s.endMs != null) 'end_ms': s.endMs,
};

Map<String, Object?> encodeStep(RecordedStep s) => {
  'seq': s.seq,
  'segment': s.segment,
  'elapsed_ms': s.elapsedMs,
  'kind': s.kind.wire,
  if (s.surface != null) 'surface': s.surface,
  if (s.action != null) 'action': s.action,
  if (s.actionVersion != null) 'action_version': s.actionVersion,
  if (s.target != null) 'target': s.target,
  if (s.page != null) 'page': s.page,
  if (!s.payload.isEmpty) 'payload': s.payload.toJson(),
  if (!s.values.isEmpty) 'values': s.values.toJson(),
  if (s.op != null) 'op': s.op,
  if (s.state != null) 'state': s.state!.wire,
  if (s.outcome != null) 'outcome': s.outcome,
  if (s.note != null) 'note': s.note,
  if (s.protectedCategory != null) 'protected': s.protectedCategory!.wire,
  if (s.origin != StepOrigin.captured) 'origin': s.origin.wire,
  if (s.sourceSeq != null) 'source_seq': s.sourceSeq,
};

/// The recording as pretty JSON text, the plain export.
String encodeRecordingText(TaskRecording r) =>
    const JsonEncoder.withIndent('  ').convert(encodeRecording(r));

/// A stable digest of a recording's steps, segments and end: what an
/// edited version names as its source. Not a signature: an edited
/// recording is not a tamper-proof audit.
String recordingDigest(TaskRecording r) {
  final canonical = jsonEncode({
    'segments': [for (final s in r.segments) encodeSegment(s)],
    'steps': [for (final s in r.steps) encodeStep(s)],
    'end_reason': r.endReason?.wire,
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}

/// Reads [text] as a recording, refusing it before parsing when it is
/// larger than [limits] allow.
RecordingDecodeResult decodeRecordingText(
  String text, {
  ActionRegistry registry = recorderRegistry,
  RecordingLimits limits = const RecordingLimits(),
}) {
  if (utf8.encode(text).length > limits.maxBytes) {
    return const RecordingDecodeResult(null, [
      RecordingIssue(RecordingIssueCode.tooLarge, r'$'),
    ]);
  }
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return const RecordingDecodeResult(null, [
      RecordingIssue(RecordingIssueCode.notJson, r'$'),
    ]);
  }
  return decodeRecording(json, registry: registry, limits: limits);
}

/// Validates and reads an already parsed recording.
RecordingDecodeResult decodeRecording(
  Object? json, {
  ActionRegistry registry = recorderRegistry,
  RecordingLimits limits = const RecordingLimits(),
}) => _Decoder(registry, limits).root(json);

const _rootKeys = {
  'format',
  'schema_version',
  'action_contract_version',
  'platform',
  'kind',
  'source_digest',
  'title',
  'values_mode',
  'prerequisites',
  'segments',
  'steps',
  'end_reason',
  'completeness',
};

const _stepKeys = {
  'seq',
  'segment',
  'elapsed_ms',
  'kind',
  'surface',
  'action',
  'action_version',
  'target',
  'page',
  'payload',
  'values',
  'op',
  'state',
  'outcome',
  'note',
  'protected',
  'origin',
  'source_seq',
};
