// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3407 -- the findings a recording read can produce. They live apart from
// the codec so the validator's halves can report them without importing it.

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
